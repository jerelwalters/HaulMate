//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

actor AppRootManager: AppService {
    private var currentUser: SessionUser?

    func restoreSession() async throws -> SessionUser? {
        currentUser
    }

    func signIn() async throws -> SessionUser {
        let user = SessionUser(id: UUID(), displayName: "Pilot Driver")
        currentUser = user
        return user
    }

    func signOut() async {
        currentUser = nil
    }
}
