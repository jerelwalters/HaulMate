//
//  Created by Jerel Walters on 7/1/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import AuthorizationModule

final class BusinessProfileDraftTests: XCTestCase {
    func testValidationReportsTypedIssuesWithoutVendorTypes() {
        var draft = BusinessProfileDraft()
        draft.invoiceEmail = "billing"
        draft.paymentTermsDays = 0

        XCTAssertEqual(
            draft.invoiceIdentityValidationErrors,
            [
                BusinessProfileValidationError(field: .legalName, reason: .required),
                BusinessProfileValidationError(field: .invoiceEmail, reason: .invalidEmail),
                BusinessProfileValidationError(field: .paymentTerms, reason: .invalidPaymentTerms)
            ]
        )
    }

    func testNormalizationTrimsBusinessProfileFields() {
        var draft = BusinessProfileDraft.validPilotProfile
        draft.legalName = "  Walters Logistics LLC  "
        draft.invoicePrefix = " HM "

        let normalized = draft.normalized

        XCTAssertEqual(normalized.legalName, "Walters Logistics LLC")
        XCTAssertEqual(normalized.invoicePrefix, "HM")
    }
}

private extension BusinessProfileDraft {
    static let validPilotProfile = BusinessProfileDraft(
        legalName: "Walters Logistics LLC",
        displayName: "Walters Logistics",
        mailingAddress: "123 Pilot Way, Detroit, MI 48201",
        phone: "313-555-0148",
        invoiceEmail: "billing@example.com",
        invoicePrefix: "HM",
        paymentTermsDays: 30
    )
}
