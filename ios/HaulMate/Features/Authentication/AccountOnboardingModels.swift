//
//  Created by Jerel Walters on 6/21/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

enum AuthenticationMode: String, CaseIterable, Identifiable {
    case signIn
    case createAccount

    var id: Self { self }

    var title: String {
        switch self {
        case .signIn:
            return AuthenticationStrings.signInTitle.localized
        case .createAccount:
            return AuthenticationStrings.createAccountTitle.localized
        }
    }
}

enum AccountOnboardingStep {
    case invoiceIdentity
    case businessDetails
}

struct AuthenticationCredentials: Equatable, Sendable {
    var email = ""
    var password = ""

    var emailValidationMessage: String? {
        let trimmedEmail = email.trimmed

        if trimmedEmail.isEmpty {
            return AuthenticationStrings.emailRequired.localized
        }

        if !trimmedEmail.contains("@") || !trimmedEmail.contains(".") {
            return AuthenticationStrings.emailInvalid.localized
        }

        return nil
    }

    var signInValidationMessage: String? {
        if let emailValidationMessage {
            return emailValidationMessage
        }

        if password.isEmpty {
            return AuthenticationStrings.passwordRequired.localized
        }

        return nil
    }

    var createAccountValidationMessage: String? {
        if let emailValidationMessage {
            return emailValidationMessage
        }

        if password.count < 8 {
            return AuthenticationStrings.passwordMinimum.localized
        }

        return nil
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension BusinessProfileValidationError {
    var message: String {
        switch reason {
        case .required:
            return requiredMessage
        case .invalidEmail:
            return AuthenticationStrings.invoiceEmailInvalid.localized
        case .invalidPaymentTerms:
            return AuthenticationStrings.paymentTermsInvalid.localized
        }
    }

    private var requiredMessage: String {
        switch field {
        case .legalName:
            return AuthenticationStrings.legalNameRequired.localized
        case .mailingAddress:
            return AuthenticationStrings.addressRequired.localized
        case .phone:
            return AuthenticationStrings.phoneRequired.localized
        case .invoiceEmail:
            return AuthenticationStrings.invoiceEmailRequired.localized
        case .invoicePrefix:
            return AuthenticationStrings.invoicePrefixRequired.localized
        case .paymentTerms:
            return AuthenticationStrings.paymentTermsInvalid.localized
        case .factoringCompany:
            return AuthenticationStrings.factoringCompanyRequired.localized
        case .factoringRemittance:
            return AuthenticationStrings.factoringRemittanceRequired.localized
        }
    }
}
