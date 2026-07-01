//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import AuthorizationModule

extension AuthRepository {
    convenience init() {
        self.init(
            sessionStore: HaulMateSecureSessionStore(),
            businessProfileStore: HaulMateBusinessProfileStore(),
            accountDataCleaner: HaulMateAccountScopedDataCleaner(),
            sessionRefresher: NoOpAuthSessionRefresher(),
            fallbackDisplayName: AppStrings.pilotDriver.localized
        )
    }
}

extension AuthRepositoryError {
    var localizedMessage: String {
        switch self {
        case .restoreSessionFailed:
            return AppRootStrings.restoreSessionFailure.localized
        case .signInFailed:
            return AppRootStrings.signInFailure.localized
        case .signUpFailed:
            return AppRootStrings.signUpFailure.localized
        case .businessProfileLoadFailed:
            return AppRootStrings.businessProfileLoadFailure.localized
        case .businessProfileSaveFailed:
            return AppRootStrings.businessProfileSaveFailure.localized
        case .passwordResetFailed:
            return AppRootStrings.passwordResetFailure.localized
        case .signOutFailed:
            return AppRootStrings.signOutFailure.localized
        }
    }
}
