//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

protocol AppService: Sendable {
    func restoreSession() async throws -> SessionUser?
    func signIn(request: SignInRequest) async throws -> SessionUser
    func signUp(request: SignUpRequest) async throws -> SessionUser
    func requestPasswordReset(email: String) async throws
    func signOut() async
}
