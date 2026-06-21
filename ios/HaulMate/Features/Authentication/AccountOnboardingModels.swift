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

struct SignInRequest: Equatable, Sendable {
    let email: String
    let password: String
}

struct SignUpRequest: Equatable, Sendable {
    let email: String
    let password: String
    let businessProfile: BusinessProfileDraft
}

struct BusinessProfileDraft: Equatable, Sendable {
    var legalName = ""
    var displayName = ""
    var mailingAddress = ""
    var phone = ""
    var invoiceEmail = ""
    var invoicePrefix = "HM"
    var paymentTermsDays = 30
    var logoFilename = ""
    var logoImageData: Data?
    var usesFactoring = false
    var factoringCompanyName = ""
    var factoringRemittanceDetails = ""

    var invoiceIdentityValidationErrors: [BusinessProfileValidationError] {
        var errors: [BusinessProfileValidationError] = []

        appendRequiredError(
            &errors,
            field: .legalName,
            value: legalName,
            message: AuthenticationStrings.legalNameRequired.localized
        )
        appendRequiredError(
            &errors,
            field: .invoiceEmail,
            value: invoiceEmail,
            message: AuthenticationStrings.invoiceEmailRequired.localized
        )

        if !invoiceEmail.trimmed.isEmpty,
           (!invoiceEmail.trimmed.contains("@") || !invoiceEmail.trimmed.contains(".")) {
            errors.append(
                BusinessProfileValidationError(
                    field: .invoiceEmail,
                    message: AuthenticationStrings.invoiceEmailInvalid.localized
                )
            )
        }

        appendRequiredError(
            &errors,
            field: .invoicePrefix,
            value: invoicePrefix,
            message: AuthenticationStrings.invoicePrefixRequired.localized
        )

        if paymentTermsDays < 1 {
            errors.append(
                BusinessProfileValidationError(
                    field: .paymentTerms,
                    message: AuthenticationStrings.paymentTermsInvalid.localized
                )
            )
        }

        return errors
    }

    var businessDetailsValidationErrors: [BusinessProfileValidationError] {
        var errors: [BusinessProfileValidationError] = []

        appendRequiredError(
            &errors,
            field: .mailingAddress,
            value: mailingAddress,
            message: AuthenticationStrings.addressRequired.localized
        )
        appendRequiredError(
            &errors,
            field: .phone,
            value: phone,
            message: AuthenticationStrings.phoneRequired.localized
        )

        if usesFactoring {
            appendRequiredError(
                &errors,
                field: .factoringCompany,
                value: factoringCompanyName,
                message: AuthenticationStrings.factoringCompanyRequired.localized
            )
            appendRequiredError(
                &errors,
                field: .factoringRemittance,
                value: factoringRemittanceDetails,
                message: AuthenticationStrings.factoringRemittanceRequired.localized
            )
        }

        return errors
    }

    var validationErrors: [BusinessProfileValidationError] {
        invoiceIdentityValidationErrors + businessDetailsValidationErrors
    }

    var canComplete: Bool {
        validationErrors.isEmpty
    }

    var hasLogo: Bool {
        logoImageData != nil
    }

    var normalized: BusinessProfileDraft {
        var draft = self
        draft.legalName = legalName.trimmed
        draft.displayName = displayName.trimmed
        draft.mailingAddress = mailingAddress.trimmed
        draft.phone = phone.trimmed
        draft.invoiceEmail = invoiceEmail.trimmed
        draft.invoicePrefix = invoicePrefix.trimmed
        draft.logoFilename = logoFilename.trimmed
        draft.factoringCompanyName = factoringCompanyName.trimmed
        draft.factoringRemittanceDetails = factoringRemittanceDetails.trimmed
        return draft
    }

    mutating func setLogoImageData(_ data: Data) {
        logoImageData = data
        logoFilename = "business-logo"
    }

    mutating func removeLogo() {
        logoImageData = nil
        logoFilename = ""
    }

    private func appendRequiredError(
        _ errors: inout [BusinessProfileValidationError],
        field: BusinessProfileField,
        value: String,
        message: String
    ) {
        guard value.trimmed.isEmpty else { return }

        errors.append(
            BusinessProfileValidationError(field: field, message: message)
        )
    }
}

struct BusinessProfileValidationError: Equatable, Identifiable, Sendable {
    let field: BusinessProfileField
    let message: String

    var id: BusinessProfileField { field }
}

enum BusinessProfileField: String, Sendable {
    case legalName
    case mailingAddress
    case phone
    case invoiceEmail
    case invoicePrefix
    case paymentTerms
    case factoringCompany
    case factoringRemittance
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
