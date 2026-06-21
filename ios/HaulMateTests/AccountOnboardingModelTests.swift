//
//  Created by Jerel Walters on 6/21/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import HaulMate

final class AccountOnboardingModelTests: XCTestCase {
    func testInvoiceIdentityRequiresFigmaFieldsBeforeContinuing() {
        let draft = BusinessProfileDraft()

        XCTAssertEqual(
            draft.invoiceIdentityValidationErrors.map(\.field),
            [
                .legalName,
                .invoiceEmail
            ]
        )
    }

    func testBusinessProfileRequiresDetailsBeforeCompletion() {
        var draft = BusinessProfileDraft()
        draft.legalName = "Walters Transport LLC"
        draft.invoiceEmail = "billing@walterstransport.com"

        XCTAssertFalse(draft.canComplete)
        XCTAssertEqual(
            draft.validationErrors.map(\.field),
            [
                .mailingAddress,
                .phone
            ]
        )
    }

    func testBusinessProfileRequiresValidInvoiceEmail() {
        var draft = BusinessProfileDraft.validPilotProfile
        draft.invoiceEmail = "billing"

        XCTAssertFalse(draft.canComplete)
        XCTAssertEqual(
            draft.validationErrors,
            [
                BusinessProfileValidationError(
                    field: .invoiceEmail,
                    message: AuthenticationStrings.invoiceEmailInvalid.localized
                )
            ]
        )
    }

    func testFactoringRequiresRemittanceFieldsWhenEnabled() {
        var draft = BusinessProfileDraft.validPilotProfile
        draft.usesFactoring = true

        XCTAssertFalse(draft.canComplete)
        XCTAssertEqual(
            draft.validationErrors.map(\.field),
            [
                .factoringCompany,
                .factoringRemittance
            ]
        )
    }

    func testValidBusinessProfileCanComplete() {
        XCTAssertTrue(BusinessProfileDraft.validPilotProfile.canComplete)
    }

    func testNormalizingBusinessProfileTrimsSubmittedValues() {
        var draft = BusinessProfileDraft.validPilotProfile
        draft.legalName = "  Walters Logistics LLC  "
        draft.invoicePrefix = " HM "

        let normalized = draft.normalized

        XCTAssertEqual(normalized.legalName, "Walters Logistics LLC")
        XCTAssertEqual(normalized.invoicePrefix, "HM")
    }

    func testLogoIsOptionalAndCanBeRemoved() {
        var draft = BusinessProfileDraft.validPilotProfile

        XCTAssertTrue(draft.canComplete)
        XCTAssertFalse(draft.hasLogo)

        draft.setLogoImageData(Data([0x01, 0x02]))

        XCTAssertTrue(draft.canComplete)
        XCTAssertTrue(draft.hasLogo)
        XCTAssertEqual(draft.logoFilename, "business-logo")

        draft.removeLogo()

        XCTAssertTrue(draft.canComplete)
        XCTAssertFalse(draft.hasLogo)
        XCTAssertTrue(draft.logoFilename.isEmpty)
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
