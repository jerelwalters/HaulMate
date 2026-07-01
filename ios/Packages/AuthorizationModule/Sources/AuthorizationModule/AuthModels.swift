//
//  Created by Jerel Walters on 7/1/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

public struct SessionUser: Codable, Equatable, Sendable {
    public let id: UUID
    public let displayName: String

    public init(id: UUID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct SignInRequest: Equatable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct SignUpRequest: Equatable, Sendable {
    public let email: String
    public let password: String
    public let businessProfile: BusinessProfileDraft

    public init(
        email: String,
        password: String,
        businessProfile: BusinessProfileDraft
    ) {
        self.email = email
        self.password = password
        self.businessProfile = businessProfile
    }
}

public struct BusinessProfileDraft: Equatable, Sendable {
    public var legalName: String
    public var displayName: String
    public var mailingAddress: String
    public var phone: String
    public var invoiceEmail: String
    public var invoicePrefix: String
    public var paymentTermsDays: Int
    public var logoFilename: String
    public var logoImageData: Data?
    public var usesFactoring: Bool
    public var factoringCompanyName: String
    public var factoringRemittanceDetails: String

    public init(
        legalName: String = "",
        displayName: String = "",
        mailingAddress: String = "",
        phone: String = "",
        invoiceEmail: String = "",
        invoicePrefix: String = "HM",
        paymentTermsDays: Int = 30,
        logoFilename: String = "",
        logoImageData: Data? = nil,
        usesFactoring: Bool = false,
        factoringCompanyName: String = "",
        factoringRemittanceDetails: String = ""
    ) {
        self.legalName = legalName
        self.displayName = displayName
        self.mailingAddress = mailingAddress
        self.phone = phone
        self.invoiceEmail = invoiceEmail
        self.invoicePrefix = invoicePrefix
        self.paymentTermsDays = paymentTermsDays
        self.logoFilename = logoFilename
        self.logoImageData = logoImageData
        self.usesFactoring = usesFactoring
        self.factoringCompanyName = factoringCompanyName
        self.factoringRemittanceDetails = factoringRemittanceDetails
    }

    public var invoiceIdentityValidationErrors: [BusinessProfileValidationError] {
        var errors: [BusinessProfileValidationError] = []

        appendRequiredError(&errors, field: .legalName, value: legalName)
        appendRequiredError(&errors, field: .invoiceEmail, value: invoiceEmail)

        if !invoiceEmail.authTrimmed.isEmpty,
           (!invoiceEmail.authTrimmed.contains("@") || !invoiceEmail.authTrimmed.contains(".")) {
            errors.append(
                BusinessProfileValidationError(field: .invoiceEmail, reason: .invalidEmail)
            )
        }

        appendRequiredError(&errors, field: .invoicePrefix, value: invoicePrefix)

        if paymentTermsDays < 1 {
            errors.append(
                BusinessProfileValidationError(field: .paymentTerms, reason: .invalidPaymentTerms)
            )
        }

        return errors
    }

    public var businessDetailsValidationErrors: [BusinessProfileValidationError] {
        var errors: [BusinessProfileValidationError] = []

        appendRequiredError(&errors, field: .mailingAddress, value: mailingAddress)
        appendRequiredError(&errors, field: .phone, value: phone)

        if usesFactoring {
            appendRequiredError(&errors, field: .factoringCompany, value: factoringCompanyName)
            appendRequiredError(&errors, field: .factoringRemittance, value: factoringRemittanceDetails)
        }

        return errors
    }

    public var validationErrors: [BusinessProfileValidationError] {
        invoiceIdentityValidationErrors + businessDetailsValidationErrors
    }

    public var canComplete: Bool {
        validationErrors.isEmpty
    }

    public var hasLogo: Bool {
        logoImageData != nil
    }

    public var normalized: BusinessProfileDraft {
        var draft = self
        draft.legalName = legalName.authTrimmed
        draft.displayName = displayName.authTrimmed
        draft.mailingAddress = mailingAddress.authTrimmed
        draft.phone = phone.authTrimmed
        draft.invoiceEmail = invoiceEmail.authTrimmed
        draft.invoicePrefix = invoicePrefix.authTrimmed
        draft.logoFilename = logoFilename.authTrimmed
        draft.factoringCompanyName = factoringCompanyName.authTrimmed
        draft.factoringRemittanceDetails = factoringRemittanceDetails.authTrimmed
        return draft
    }

    public mutating func setLogoImageData(_ data: Data) {
        logoImageData = data
        logoFilename = "business-logo"
    }

    public mutating func removeLogo() {
        logoImageData = nil
        logoFilename = ""
    }

    private func appendRequiredError(
        _ errors: inout [BusinessProfileValidationError],
        field: BusinessProfileField,
        value: String
    ) {
        guard value.authTrimmed.isEmpty else { return }

        errors.append(
            BusinessProfileValidationError(field: field, reason: .required)
        )
    }
}

public struct BusinessProfileValidationError: Equatable, Identifiable, Sendable {
    public let field: BusinessProfileField
    public let reason: BusinessProfileValidationReason

    public var id: BusinessProfileField { field }

    public init(
        field: BusinessProfileField,
        reason: BusinessProfileValidationReason
    ) {
        self.field = field
        self.reason = reason
    }
}

public enum BusinessProfileValidationReason: Equatable, Sendable {
    case required
    case invalidEmail
    case invalidPaymentTerms
}

public enum BusinessProfileField: String, Sendable {
    case legalName
    case mailingAddress
    case phone
    case invoiceEmail
    case invoicePrefix
    case paymentTerms
    case factoringCompany
    case factoringRemittance
}

private extension String {
    var authTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
