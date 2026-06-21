//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

protocol AppService: Sendable {
    func restoreSession() async throws -> SessionUser?
    func signIn() async throws -> SessionUser
    func signOut() async
}
