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
            .failed(message: "We couldn't restore your session.")
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
            .failed(message: "We couldn't restore your session.")
        )

        await repository.restore(force: true)

        XCTAssertEqual(repository.phase, .authenticated(user))
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

    func signIn() async throws -> SessionUser {
        SessionUser(id: UUID(), displayName: "Driver")
    }

    func signOut() async {}
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

    func signIn() async throws -> SessionUser {
        user
    }

    func signOut() async {}
}

private enum TestError: Error {
    case restore
}
