//
//  Created by Jerel Walters on 6/21/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

protocol Localizable {
    var localized: String { get }
}

extension Localizable where Self: RawRepresentable, Self.RawValue == String {
    var localized: String {
        NSLocalizedString(
            String(describing: Self.self) + "_\(rawValue)",
            comment: ""
        )
    }

    func localized(_ arguments: CVarArg...) -> String {
        String(format: localized, locale: .current, arguments: arguments)
    }
}

enum AppStrings: String, Localizable {
    case appName
    case pilotDriver
}

enum AppAppearanceStrings: String, Localizable {
    case systemTitle
    case lightTitle
    case darkTitle
}

enum AppRootStrings: String, Localizable {
    case restoreSessionFailure
    case signInFailure
    case signUpFailure
    case passwordResetFailure
}

enum AppStatusStrings: String, Localizable {
    case loadingTitle
    case loadingAccessibilityLabel
    case retryButton
    case offlineTitle
    case syncingTitle
    case failedTitle
    case previewFailureMessage
}

enum AuthenticationStrings: String, Localizable {
    case signInTitle
    case createAccountTitle
    case emailRequired
    case emailInvalid
    case passwordRequired
    case passwordMinimum
    case headerMessage
    case modePickerTitle
    case accountSectionTitle
    case signInAccountSectionSubtitle
    case createAccountSectionSubtitle
    case emailPlaceholder
    case passwordPlaceholder
    case businessSetupTitle
    case invoiceIdentityTitle
    case invoiceIdentitySubtitle
    case legalBusinessNameLabel
    case legalBusinessNamePlaceholder
    case carrierDisplayNameLabel
    case carrierDisplayNamePlaceholder
    case businessEmailLabel
    case businessEmailPlaceholder
    case invoicePrefixLabel
    case paymentTermsLabel
    case netPaymentTermsFormat
    case continueButton
    case nextBusinessDetailsMessage
    case profileCachedStatus
    case businessSetupFooter
    case businessDetailsTitle
    case businessDetailsSubtitle
    case businessAddressLabel
    case businessPhoneLabel
    case logoFieldLabel
    case factoringCompanyLabel
    case factoringRemittanceLabel
    case finishSetupButton
    case backButton
    case businessSectionTitle
    case businessSectionSubtitle
    case legalNamePlaceholder
    case displayNamePlaceholder
    case addressPlaceholder
    case phonePlaceholder
    case invoiceSectionTitle
    case invoiceSectionSubtitle
    case invoiceEmailPlaceholder
    case invoicePrefixPlaceholder
    case paymentTermsFormat
    case logoPlaceholder
    case factoringToggle
    case factoringCompanyPlaceholder
    case factoringRemittancePlaceholder
    case validationSummaryTitle
    case submittingAccessibilityLabel
    case forgotPasswordButton
    case passwordResetSuccess
    case legalNameRequired
    case addressRequired
    case phoneRequired
    case invoiceEmailRequired
    case invoiceEmailInvalid
    case invoicePrefixRequired
    case paymentTermsInvalid
    case factoringCompanyRequired
    case factoringRemittanceRequired
}

enum DashboardStrings: String, Localizable {
    case todayTab
    case loadsTab
    case moreTab
    case newLoadAccessibilityLabel
    case todayTitle
    case greetingFormat
    case syncStatus
    case noActiveLoadTitle
    case noActiveLoadMessage
    case createLoadButton
    case needsAttentionTitle
    case activeLoadLabel
    case deliveryAppointmentLabel
    case acceptedPayLabel
    case openActiveLoadButton
    case estimatedProfitLabel
    case profitPerMileFormat
    case previewPodRequiredTitle
    case previewInvoiceOverdueTitle
    case previewInvoiceOverdueDetail
}

enum LoadsStrings: String, Localizable {
    case offlineMessage
    case navigationTitle
    case newLoadButton
}

enum LoadDetailStrings: String, Localizable {
    case restoringMessage
    case navigationTitle
}

enum NewLoadStrings: String, Localizable {
    case emptyTitle
    case emptyMessage
    case navigationTitle
    case closeButton
}

enum SettingsStrings: String, Localizable {
    case appearanceLabel
    case businessProfileLabel
    case signOutButton
    case navigationTitle
    case businessProfilePlaceholder
}

enum DesignSystemStrings: String, Localizable {
    case previewSubtitle
    case primaryAction
    case secondaryAction
}
