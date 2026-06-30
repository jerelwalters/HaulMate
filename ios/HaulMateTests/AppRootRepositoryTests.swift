//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import HaulMate

@MainActor
final class AppRootRepositoryTests: XCTestCase {
    func testRestoreWithoutStoredUserShowsUnauthenticatedRoot() async {
        let repository = AppRootRepository(
            appService: AppServiceStub(restoredUser: nil)
        )

        await repository.restore()

        XCTAssertEqual(repository.phase, .unauthenticated)
    }

    func testRestoreWithStoredUserShowsAuthenticatedRoot() async {
        let user = SessionUser(id: UUID(), displayName: "Driver")
        let repository = AppRootRepository(
            appService: AppServiceStub(restoredUser: user)
        )

        await repository.restore()

        XCTAssertEqual(repository.phase, .authenticated(user))
    }

    func testRestoreFailureExposesRetryableFailure() async {
        let repository = AppRootRepository(
            appService: AppServiceStub(restoreShouldFail: true)
        )

        await repository.restore()

        XCTAssertEqual(
            repository.phase,
            .failed(message: AppRootStrings.restoreSessionFailure.localized)
        )
    }

    func testForcedRetryAfterRestoreFailureShowsAuthenticatedRoot() async {
        let user = SessionUser(id: UUID(), displayName: "Driver")
        let repository = AppRootRepository(
            appService: RetryRestoreAppServiceStub(user: user)
        )

        await repository.restore()

        XCTAssertEqual(
            repository.phase,
            .failed(message: AppRootStrings.restoreSessionFailure.localized)
        )

        await repository.restore(force: true)

        XCTAssertEqual(repository.phase, .authenticated(user))
    }

    func testSignInAuthenticatesWithCredentials() async {
        let user = SessionUser(id: UUID(), displayName: "Driver")
        let service = CapturingAppServiceStub(signInUser: user)
        let repository = AppRootRepository(appService: service)

        let result = await repository.signIn(
            request: SignInRequest(
                email: "driver@example.com",
                password: "password123"
            )
        )

        let capturedRequest = await service.capturedSignInRequest()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(repository.phase, .authenticated(user))
        XCTAssertEqual(
            capturedRequest,
            SignInRequest(
                email: "driver@example.com",
                password: "password123"
            )
        )
    }

    func testSignUpAuthenticatesWithBusinessProfile() async {
        let user = SessionUser(id: UUID(), displayName: "Driver")
        let service = CapturingAppServiceStub(signUpUser: user)
        let repository = AppRootRepository(appService: service)
        let profile = BusinessProfileDraft.validPilotProfile

        let result = await repository.signUp(
            request: SignUpRequest(
                email: "driver@example.com",
                password: "password123",
                businessProfile: profile
            )
        )

        let capturedRequest = await service.capturedSignUpRequest()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(repository.phase, .authenticated(user))
        XCTAssertEqual(
            capturedRequest,
            SignUpRequest(
                email: "driver@example.com",
                password: "password123",
                businessProfile: profile
            )
        )
    }

    func testPasswordResetDoesNotAuthenticate() async {
        let service = CapturingAppServiceStub()
        let repository = AppRootRepository(appService: service)
        await repository.restore()

        let result = await repository.requestPasswordReset(
            email: "driver@example.com"
        )

        let capturedEmail = await service.capturedPasswordResetEmail()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(repository.phase, .unauthenticated)
        XCTAssertEqual(capturedEmail, "driver@example.com")
    }
}

private actor AppServiceStub: AppService {
    private let restoredUser: SessionUser?
    private let restoreShouldFail: Bool

    init(
        restoredUser: SessionUser? = nil,
        restoreShouldFail: Bool = false
    ) {
        self.restoredUser = restoredUser
        self.restoreShouldFail = restoreShouldFail
    }

    func restoreSession() async throws -> SessionUser? {
        if restoreShouldFail { throw TestError.restore }
        return restoredUser
    }

    func signIn(request: SignInRequest) async throws -> SessionUser {
        SessionUser(id: UUID(), displayName: "Driver")
    }

    func signUp(request: SignUpRequest) async throws -> SessionUser {
        SessionUser(id: UUID(), displayName: "Driver")
    }

    func requestPasswordReset(email: String) async throws {}

    func signOut() async throws {}
}

private actor RetryRestoreAppServiceStub: AppService {
    private let user: SessionUser
    private var restoreAttempt = 0

    init(user: SessionUser) {
        self.user = user
    }

    func restoreSession() async throws -> SessionUser? {
        restoreAttempt += 1
        if restoreAttempt == 1 { throw TestError.restore }
        return user
    }

    func signIn(request: SignInRequest) async throws -> SessionUser {
        user
    }

    func signUp(request: SignUpRequest) async throws -> SessionUser {
        user
    }

    func requestPasswordReset(email: String) async throws {}

    func signOut() async throws {}
}

private enum TestError: Error {
    case restore
}

private actor CapturingAppServiceStub: AppService {
    private let restoredUser: SessionUser?
    private let signInUser: SessionUser
    private let signUpUser: SessionUser

    private var signInRequest: SignInRequest?
    private var signUpRequest: SignUpRequest?
    private var passwordResetEmail: String?

    init(
        restoredUser: SessionUser? = nil,
        signInUser: SessionUser = SessionUser(id: UUID(), displayName: "Sign In"),
        signUpUser: SessionUser = SessionUser(id: UUID(), displayName: "Sign Up")
    ) {
        self.restoredUser = restoredUser
        self.signInUser = signInUser
        self.signUpUser = signUpUser
    }

    func restoreSession() async throws -> SessionUser? {
        restoredUser
    }

    func signIn(request: SignInRequest) async throws -> SessionUser {
        signInRequest = request
        return signInUser
    }

    func signUp(request: SignUpRequest) async throws -> SessionUser {
        signUpRequest = request
        return signUpUser
    }

    func requestPasswordReset(email: String) async throws {
        passwordResetEmail = email
    }

    func capturedSignInRequest() -> SignInRequest? {
        signInRequest
    }

    func capturedSignUpRequest() -> SignUpRequest? {
        signUpRequest
    }

    func capturedPasswordResetEmail() -> String? {
        passwordResetEmail
    }

    func signOut() async throws {}
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
