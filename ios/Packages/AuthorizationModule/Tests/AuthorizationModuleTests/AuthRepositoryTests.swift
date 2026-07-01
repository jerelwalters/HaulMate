//
//  Created by Jerel Walters on 7/1/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import AuthorizationModule

@MainActor
final class AuthRepositoryTests: XCTestCase {
    func testInitialStatusStartsLoading() {
        let repository = AuthRepository(authService: CapturingAuthService())

        XCTAssertEqual(repository.authStatus, .loading)
    }

    func testRestoreWithoutStoredUserShowsUnauthenticatedStatus() async {
        let repository = AuthRepository(
            authService: CapturingAuthService(restoredUser: nil)
        )

        await repository.restore()

        XCTAssertEqual(repository.authStatus, .unauthenticated)
    }

    func testRestoreWithStoredUserShowsAuthenticatedStatus() async {
        let user = SessionUser(id: UUID(), displayName: "Driver")
        let repository = AuthRepository(
            authService: CapturingAuthService(restoredUser: user)
        )

        await repository.restore()

        XCTAssertEqual(repository.authStatus, .authenticated(user))
    }

    func testRestoreFailureExposesRetryableFailure() async {
        let repository = AuthRepository(
            authService: CapturingAuthService(restoreShouldFail: true)
        )

        await repository.restore()

        XCTAssertEqual(repository.authStatus, .failed(.restoreSessionFailed))
    }

    func testForcedRetryAfterRestoreFailureShowsAuthenticatedStatus() async {
        let user = SessionUser(id: UUID(), displayName: "Driver")
        let repository = AuthRepository(
            authService: RetryRestoreAuthService(user: user)
        )

        await repository.restore()

        XCTAssertEqual(repository.authStatus, .failed(.restoreSessionFailed))

        await repository.restore(force: true)

        XCTAssertEqual(repository.authStatus, .authenticated(user))
    }

    func testCompleteAuthenticationShowsAuthenticatedStatus() {
        let user = SessionUser(id: UUID(), displayName: "Driver")
        let repository = AuthRepository(authService: CapturingAuthService())

        repository.completeAuthentication(with: user)

        XCTAssertEqual(repository.authStatus, .authenticated(user))
    }

    func testSignInAuthenticatesWithCredentials() async {
        let user = SessionUser(id: UUID(), displayName: "Driver")
        let service = CapturingAuthService(signInUser: user)
        let repository = AuthRepository(authService: service)

        let result = await repository.signIn(
            request: SignInRequest(
                email: "driver@example.com",
                password: "password123"
            )
        )

        let capturedRequest = await service.capturedSignInRequest()

        XCTAssertEqual(result, .success(user))
        XCTAssertEqual(repository.authStatus, .authenticated(user))
        XCTAssertEqual(
            capturedRequest,
            SignInRequest(
                email: "driver@example.com",
                password: "password123"
            )
        )
    }

    func testSignInReturnsTypedFailureWithoutVendorError() async {
        let repository = AuthRepository(
            authService: CapturingAuthService(signInShouldFail: true)
        )

        let result = await repository.signIn(
            request: SignInRequest(
                email: "driver@example.com",
                password: "password123"
            )
        )

        XCTAssertEqual(result, .failure(.signInFailed))
        XCTAssertEqual(repository.authStatus, .unauthenticated)
    }

    func testSignUpAuthenticatesWithBusinessProfile() async {
        let user = SessionUser(id: UUID(), displayName: "Driver")
        let service = CapturingAuthService(signUpUser: user)
        let repository = AuthRepository(authService: service)
        let profile = BusinessProfileDraft.validPilotProfile

        let result = await repository.signUp(
            request: SignUpRequest(
                email: "driver@example.com",
                password: "password123",
                businessProfile: profile
            )
        )

        let capturedRequest = await service.capturedSignUpRequest()

        XCTAssertEqual(result, .success(user))
        XCTAssertEqual(repository.authStatus, .authenticated(user))
        XCTAssertEqual(
            capturedRequest,
            SignUpRequest(
                email: "driver@example.com",
                password: "password123",
                businessProfile: profile
            )
        )
    }

    func testLoadBusinessProfileReturnsServiceProfile() async {
        let profile = BusinessProfileDraft.validPilotProfile
        let service = CapturingAuthService(businessProfile: profile)
        let repository = AuthRepository(authService: service)

        let result = await repository.loadBusinessProfile()

        XCTAssertEqual(result, .success(profile))
    }

    func testUpdateBusinessProfileNormalizesBeforeSaving() async {
        let service = CapturingAuthService()
        let repository = AuthRepository(authService: service)
        var profile = BusinessProfileDraft.validPilotProfile
        profile.legalName = "  Walters Logistics LLC  "
        profile.invoicePrefix = " HM "

        let result = await repository.updateBusinessProfile(profile)

        let capturedProfile = await service.capturedBusinessProfileUpdate()
        XCTAssertEqual(result, .success(profile.normalized))
        XCTAssertEqual(capturedProfile, profile.normalized)
    }

    func testPasswordResetDoesNotAuthenticate() async {
        let service = CapturingAuthService()
        let repository = AuthRepository(authService: service)

        let result = await repository.requestPasswordReset(
            email: "driver@example.com"
        )

        let capturedEmail = await service.capturedPasswordResetEmail()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(capturedEmail, "driver@example.com")
    }

    func testSignOutCallsServiceAndClearsAuthStatus() async {
        let user = SessionUser(id: UUID(), displayName: "Driver")
        let service = CapturingAuthService()
        let repository = AuthRepository(authService: service)
        repository.completeAuthentication(with: user)

        let result = await repository.signOut()

        let signOutCount = await service.capturedSignOutCount()
        XCTAssertEqual(result, .success)
        XCTAssertEqual(signOutCount, 1)
        XCTAssertEqual(repository.authStatus, .unauthenticated)
    }

    func testSignOutFailureStillClearsAuthStatus() async {
        let user = SessionUser(id: UUID(), displayName: "Driver")
        let repository = AuthRepository(
            authService: CapturingAuthService(signOutShouldFail: true)
        )
        repository.completeAuthentication(with: user)

        let result = await repository.signOut()

        XCTAssertEqual(result, .failure(.signOutFailed))
        XCTAssertEqual(repository.authStatus, .unauthenticated)
    }
}

private actor CapturingAuthService: AuthService {
    private let restoredUser: SessionUser?
    private let signInUser: SessionUser?
    private let signUpUser: SessionUser?
    private let businessProfile: BusinessProfileDraft?
    private let restoreShouldFail: Bool
    private let signInShouldFail: Bool
    private let signUpShouldFail: Bool
    private let signOutShouldFail: Bool
    private var signInRequest: SignInRequest?
    private var signUpRequest: SignUpRequest?
    private var businessProfileUpdate: BusinessProfileDraft?
    private var passwordResetEmail: String?
    private var signOutCount = 0

    init(
        restoredUser: SessionUser? = nil,
        signInUser: SessionUser? = nil,
        signUpUser: SessionUser? = nil,
        businessProfile: BusinessProfileDraft? = nil,
        restoreShouldFail: Bool = false,
        signInShouldFail: Bool = false,
        signUpShouldFail: Bool = false,
        signOutShouldFail: Bool = false
    ) {
        self.restoredUser = restoredUser
        self.signInUser = signInUser
        self.signUpUser = signUpUser
        self.businessProfile = businessProfile
        self.restoreShouldFail = restoreShouldFail
        self.signInShouldFail = signInShouldFail
        self.signUpShouldFail = signUpShouldFail
        self.signOutShouldFail = signOutShouldFail
    }

    func restoreSession() async throws -> SessionUser? {
        if restoreShouldFail { throw TestError.auth }
        return restoredUser
    }

    func signIn(request: SignInRequest) async throws -> SessionUser {
        if signInShouldFail { throw TestError.auth }
        signInRequest = request
        return signInUser ?? SessionUser(id: UUID(), displayName: "Driver")
    }

    func signUp(request: SignUpRequest) async throws -> SessionUser {
        if signUpShouldFail { throw TestError.auth }
        signUpRequest = request
        return signUpUser ?? SessionUser(id: UUID(), displayName: "Driver")
    }

    func currentBusinessProfile() async throws -> BusinessProfileDraft? {
        businessProfile
    }

    func updateBusinessProfile(_ profile: BusinessProfileDraft) async throws -> BusinessProfileDraft {
        businessProfileUpdate = profile
        return profile
    }

    func requestPasswordReset(email: String) async throws {
        passwordResetEmail = email
    }

    func signOut() async throws {
        signOutCount += 1
        if signOutShouldFail { throw TestError.auth }
    }

    func capturedSignInRequest() -> SignInRequest? {
        signInRequest
    }

    func capturedSignUpRequest() -> SignUpRequest? {
        signUpRequest
    }

    func capturedBusinessProfileUpdate() -> BusinessProfileDraft? {
        businessProfileUpdate
    }

    func capturedPasswordResetEmail() -> String? {
        passwordResetEmail
    }

    func capturedSignOutCount() -> Int {
        signOutCount
    }
}

private actor RetryRestoreAuthService: AuthService {
    private let user: SessionUser
    private var restoreAttempt = 0

    init(user: SessionUser) {
        self.user = user
    }

    func restoreSession() async throws -> SessionUser? {
        restoreAttempt += 1
        if restoreAttempt == 1 { throw TestError.auth }
        return user
    }

    func signIn(request: SignInRequest) async throws -> SessionUser {
        user
    }

    func signUp(request: SignUpRequest) async throws -> SessionUser {
        user
    }

    func currentBusinessProfile() async throws -> BusinessProfileDraft? {
        nil
    }

    func updateBusinessProfile(_ profile: BusinessProfileDraft) async throws -> BusinessProfileDraft {
        profile
    }

    func requestPasswordReset(email: String) async throws {}

    func signOut() async throws {}
}

private enum TestError: Error {
    case auth
}

private extension BusinessProfileDraft {
    static let validPilotProfile = BusinessProfileDraft(
        legalName: "Walters Logistics LLC",
        displayName: "Walters Logistics",
        mailingAddress: "123 Pilot Way, Detroit, MI 48201",
        phone: "313-555-0148",
        invoiceEmail: "billing@example.com",
        invoicePrefix: "HM",
        paymentTermsDays: 30
    )
}
