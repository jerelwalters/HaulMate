//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI
import XCTest
@testable import HaulMate

@MainActor
final class AppEnvironmentTests: XCTestCase {
    func testEntryReturnsInjectedDependencies() {
        let authRepository = AuthRepository(authService: EnvironmentAuthServiceStub())
        let router = AppRouter(store: MemoryNavigationStore())
        var environment = EnvironmentValues()

        environment.appDependencies = AppDependencies(
            authRepository: authRepository,
            router: router
        )

        XCTAssertTrue(environment.appDependencies?.authRepository === authRepository)
        XCTAssertTrue(environment.appDependencies?.router === router)
    }

    func testEntryReturnsInjectedAppearanceModeBinding() {
        var appearanceMode = AppAppearanceMode.dark
        var environment = EnvironmentValues()

        environment.appAppearanceMode = Binding(
            get: { appearanceMode },
            set: { appearanceMode = $0 }
        )

        XCTAssertEqual(environment.appAppearanceMode.wrappedValue, .dark)

        environment.appAppearanceMode.wrappedValue = .light

        XCTAssertEqual(appearanceMode, .light)
    }

    func testAppearanceModeMapsToColorScheme() {
        XCTAssertNil(AppAppearanceMode.system.colorScheme)
        XCTAssertEqual(AppAppearanceMode.light.colorScheme, .light)
        XCTAssertEqual(AppAppearanceMode.dark.colorScheme, .dark)
    }
}

@MainActor
private final class MemoryNavigationStore: NavigationStatePersisting {
    func load() -> Data? { nil }
    func save(_ data: Data) {}
}

private actor EnvironmentAuthServiceStub: AuthService {
    func restoreSession() async throws -> SessionUser? {
        nil
    }

    func signIn(request: SignInRequest) async throws -> SessionUser {
        SessionUser(id: UUID(), displayName: "Driver")
    }

    func signUp(request: SignUpRequest) async throws -> SessionUser {
        SessionUser(id: UUID(), displayName: "Driver")
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
