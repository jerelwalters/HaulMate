//
//  Created by Jerel Walters on 6/22/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import HaulMate

final class BillingCalculationsTests: XCTestCase {
    func testDetentionAppliesFreeTimeAndLinksEvidence() throws {
        let podPhotoID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let gateReceiptID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!

        let charge = try DetentionCalculator.calculate(
            DetentionCalculationInput(
                arrivalAt: time(8, 0),
                releasedAt: time(11, 30),
                freeTimeMinutes: 120,
                ratePerHour: decimal("75"),
                evidenceIDs: [podPhotoID, gateReceiptID]
            )
        )

        XCTAssertEqual(charge.elapsedMinutes, 210)
        XCTAssertEqual(charge.billableMinutes, 90)
        XCTAssertEqual(charge.amount, decimal("112.50"))
        XCTAssertEqual(charge.evidenceIDs, [podPhotoID, gateReceiptID])

        let lineItem = InvoiceLineItem.detention(
            description: "Detroit receiver detention",
            charge: charge
        )

        XCTAssertEqual(lineItem.kind, .detention)
        XCTAssertEqual(lineItem.amount, decimal("112.50"))
        XCTAssertEqual(lineItem.evidenceIDs, [podPhotoID, gateReceiptID])
    }

    func testDetentionWithinFreeTimeProducesZeroBillableAmount() throws {
        let charge = try DetentionCalculator.calculate(
            DetentionCalculationInput(
                arrivalAt: time(9, 0),
                releasedAt: time(10, 45),
                freeTimeMinutes: 120,
                ratePerHour: decimal("80"),
                evidenceIDs: []
            )
        )

        XCTAssertEqual(charge.elapsedMinutes, 105)
        XCTAssertEqual(charge.billableMinutes, 0)
        XCTAssertEqual(charge.amount, decimal("0.00"))
    }

    func testDetentionFormulaRoundsFractionalHourlyBillingToCents() throws {
        // A driver can explain this as:
        // "I waited 157 minutes. The first 120 were free. The remaining 37
        // minutes bill at $80/hour, which comes to $49.33."
        let charge = try DetentionCalculator.calculate(
            DetentionCalculationInput(
                arrivalAt: time(8, 0),
                releasedAt: time(10, 37),
                freeTimeMinutes: 120,
                ratePerHour: decimal("80"),
                evidenceIDs: []
            )
        )

        XCTAssertEqual(charge.elapsedMinutes, 157)
        XCTAssertEqual(charge.freeTimeMinutes, 120)
        XCTAssertEqual(charge.billableMinutes, 37)
        XCTAssertEqual(charge.amount, decimal("49.33"))
    }

    func testInvalidDetentionInputsThrow() {
        XCTAssertThrowsError(
            try DetentionCalculator.calculate(
                DetentionCalculationInput(
                    arrivalAt: time(12, 0),
                    releasedAt: time(11, 59),
                    freeTimeMinutes: 120,
                    ratePerHour: decimal("75"),
                    evidenceIDs: []
                )
            )
        ) { error in
            XCTAssertEqual(error as? DetentionCalculationError, .releasedBeforeArrival)
        }

        XCTAssertThrowsError(
            try DetentionCalculator.calculate(
                DetentionCalculationInput(
                    arrivalAt: time(8, 0),
                    releasedAt: time(9, 0),
                    freeTimeMinutes: -1,
                    ratePerHour: decimal("75"),
                    evidenceIDs: []
                )
            )
        ) { error in
            XCTAssertEqual(error as? DetentionCalculationError, .negativeFreeTime)
        }

        XCTAssertThrowsError(
            try DetentionCalculator.calculate(
                DetentionCalculationInput(
                    arrivalAt: time(8, 0),
                    releasedAt: time(9, 0),
                    freeTimeMinutes: 120,
                    ratePerHour: decimal("-1"),
                    evidenceIDs: []
                )
            )
        ) { error in
            XCTAssertEqual(error as? DetentionCalculationError, .negativeRate)
        }
    }

    func testInvoiceNumbersAdvanceSequentiallyPerAccount() throws {
        let accountID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        let sequence = InvoiceNumberSequence(
            accountID: accountID,
            prefix: " HM ",
            nextValue: 1042
        )

        let firstIssue = try sequence.issuingNext()
        let secondIssue = try firstIssue.nextSequence.issuingNext()

        XCTAssertEqual(firstIssue.number, "HM-1042")
        XCTAssertEqual(firstIssue.nextSequence.accountID, accountID)
        XCTAssertEqual(firstIssue.nextSequence.nextValue, 1043)
        XCTAssertEqual(secondIssue.number, "HM-1043")
        XCTAssertEqual(secondIssue.nextSequence.nextValue, 1044)
    }

    func testInvoiceRevisionHistoryIsVersionedNotReplaced() throws {
        let invoice = try makeInvoice(
            lineItems: [
                lineItem(.lineHaul, "Line haul", "1850"),
                lineItem(.fuelSurcharge, "Fuel surcharge", "150")
            ]
        )

        let revised = try invoice.revising(
            revisionID: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            createdAt: time(12, 0),
            lineItems: [
                lineItem(.lineHaul, "Line haul", "1850"),
                lineItem(.fuelSurcharge, "Fuel surcharge", "150"),
                lineItem(.detention, "Receiver detention", "112.50")
            ]
        )

        XCTAssertEqual(revised.revisions.count, 2)
        XCTAssertEqual(revised.revisions[0].revisionNumber, 1)
        XCTAssertEqual(revised.revisions[0].totalAmount, decimal("2000.00"))
        XCTAssertEqual(revised.currentRevision.revisionNumber, 2)
        XCTAssertEqual(revised.currentRevision.totalAmount, decimal("2112.50"))
        XCTAssertEqual(invoice.currentRevision.totalAmount, decimal("2000.00"))
    }

    func testPartialAndFullPaymentsReconcileRemainingBalance() throws {
        let invoice = try makeInvoice(
            lineItems: [
                lineItem(.lineHaul, "Line haul", "1000"),
                lineItem(.detention, "Detention", "112.50")
            ]
        )

        let partiallyPaid = try invoice.recordingPayment(
            InvoicePayment(amount: decimal("400"), receivedAt: time(12, 0))
        )

        XCTAssertEqual(partiallyPaid.paymentReconciliation.totalDue, decimal("1112.50"))
        XCTAssertEqual(partiallyPaid.paymentReconciliation.totalPaid, decimal("400.00"))
        XCTAssertEqual(partiallyPaid.paymentReconciliation.remainingBalance, decimal("712.50"))
        XCTAssertEqual(partiallyPaid.paymentReconciliation.status, .partial)

        let paid = try partiallyPaid.recordingPayment(
            InvoicePayment(amount: decimal("712.50"), receivedAt: time(13, 0))
        )

        XCTAssertEqual(paid.paymentReconciliation.totalPaid, decimal("1112.50"))
        XCTAssertEqual(paid.paymentReconciliation.remainingBalance, decimal("0.00"))
        XCTAssertEqual(paid.paymentReconciliation.unappliedCredit, decimal("0.00"))
        XCTAssertEqual(paid.paymentReconciliation.status, .paid)
    }

    func testInvoiceRevisionReconcilesExistingPaymentsAgainstCurrentRevision() throws {
        let invoice = try makeInvoice(
            lineItems: [lineItem(.lineHaul, "Line haul", "1000")]
        )
        let partiallyPaid = try invoice.recordingPayment(
            InvoicePayment(amount: decimal("400"), receivedAt: time(12, 0))
        )

        let revised = try partiallyPaid.revising(
            createdAt: time(13, 0),
            lineItems: [
                lineItem(.lineHaul, "Line haul", "1000"),
                lineItem(.detention, "Receiver detention", "200")
            ]
        )

        XCTAssertEqual(revised.revisions.count, 2)
        XCTAssertEqual(revised.payments.count, 1)
        XCTAssertEqual(revised.revisions[0].totalAmount, decimal("1000.00"))
        XCTAssertEqual(revised.currentRevision.totalAmount, decimal("1200.00"))
        XCTAssertEqual(revised.paymentReconciliation.totalPaid, decimal("400.00"))
        XCTAssertEqual(revised.paymentReconciliation.remainingBalance, decimal("800.00"))
        XCTAssertEqual(revised.paymentReconciliation.status, .partial)
    }

    func testOverpaymentBecomesUnappliedCreditInsteadOfNegativeBalance() throws {
        let invoice = try makeInvoice(
            lineItems: [lineItem(.lineHaul, "Line haul", "1000")]
        )

        let overpaid = try invoice.recordingPayment(
            InvoicePayment(amount: decimal("1100"), receivedAt: time(12, 0))
        )

        XCTAssertEqual(overpaid.paymentReconciliation.totalDue, decimal("1000.00"))
        XCTAssertEqual(overpaid.paymentReconciliation.totalPaid, decimal("1100.00"))
        XCTAssertEqual(overpaid.paymentReconciliation.remainingBalance, decimal("0.00"))
        XCTAssertEqual(overpaid.paymentReconciliation.unappliedCredit, decimal("100.00"))
        XCTAssertEqual(overpaid.paymentReconciliation.status, .paid)
    }

    func testInvoiceValidationRejectsInvalidFinancialHistory() throws {
        XCTAssertThrowsError(
            try makeInvoice(lineItems: [])
        ) { error in
            XCTAssertEqual(error as? InvoiceValidationError, .emptyLineItems)
        }

        XCTAssertThrowsError(
            try makeInvoice(lineItems: [lineItem(.adjustment, "Bad credit", "-1")])
        ) { error in
            XCTAssertEqual(error as? InvoiceValidationError, .negativeLineItemAmount)
        }

        let invoice = try makeInvoice(lineItems: [lineItem(.lineHaul, "Line haul", "1000")])

        XCTAssertThrowsError(
            try invoice.recordingPayment(
                InvoicePayment(amount: decimal("0"), receivedAt: time(12, 0))
            )
        ) { error in
            XCTAssertEqual(error as? InvoiceValidationError, .invalidPaymentAmount)
        }
    }
}

private func makeInvoice(
    lineItems: [InvoiceLineItem]
) throws -> Invoice {
    try Invoice(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
        accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
        number: "HM-1042",
        createdAt: time(10, 0),
        lineItems: lineItems
    )
}

private func lineItem(
    _ kind: InvoiceLineItemKind,
    _ description: String,
    _ amount: String
) -> InvoiceLineItem {
    InvoiceLineItem(
        kind: kind,
        description: description,
        amount: decimal(amount)
    )
}

private func time(_ hour: Int, _ minute: Int) -> Date {
    Date(timeIntervalSince1970: TimeInterval((hour * 60 + minute) * 60))
}

private func decimal(_ value: String) -> Decimal {
    Decimal(string: value)!
}
