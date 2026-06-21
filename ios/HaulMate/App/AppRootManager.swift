//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

actor AppRootManager: AppService {
    private var currentUser: SessionUser?
    private var businessProfile: BusinessProfileDraft?

    // P0-BE-02 replaces this in-memory auth/profile store with backend-backed auth and profile ownership.
    func restoreSession() async throws -> SessionUser? {
        currentUser
    }

    func signIn(request: SignInRequest) async throws -> SessionUser {
        let user = currentUser ?? SessionUser(
            id: UUID(),
            displayName: displayName(fromEmail: request.email)
        )
        currentUser = user
        return user
    }

    func signUp(request: SignUpRequest) async throws -> SessionUser {
        businessProfile = request.businessProfile

        let profileName = request.businessProfile.displayName.trimmed.isEmpty
            ? request.businessProfile.legalName
            : request.businessProfile.displayName
        let user = SessionUser(
            id: UUID(),
            displayName: profileName.trimmed
        )
        currentUser = user
        return user
    }

    func requestPasswordReset(email: String) async throws {}

    func signOut() async {
        currentUser = nil
        businessProfile = nil
    }

    private func displayName(fromEmail email: String) -> String {
        email
            .split(separator: "@")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized ?? AppStrings.pilotDriver.localized
    }
}
