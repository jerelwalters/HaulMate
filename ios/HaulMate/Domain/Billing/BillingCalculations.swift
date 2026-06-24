//
//  Created by Jerel Walters on 6/22/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

/// The terms and evidence needed to decide whether waiting time can be billed.
/// Free time is the grace period from the rate confirmation before detention starts.
struct DetentionCalculationInput: Equatable, Sendable {
    let arrivalAt: Date
    let releasedAt: Date
    let freeTimeMinutes: Int
    let ratePerHour: Decimal
    let evidenceIDs: [UUID]
}

/// A billable detention result. Elapsed time is total wait; billable time is
/// only the portion after free time expires.
struct DetentionCharge: Equatable, Sendable {
    let elapsedMinutes: Int
    let freeTimeMinutes: Int
    let billableMinutes: Int
    let ratePerHour: Decimal
    let amount: Decimal
    let evidenceIDs: [UUID]
}

enum DetentionCalculationError: Error, Equatable, Sendable {
    case releasedBeforeArrival
    case negativeFreeTime
    case negativeRate
}

enum DetentionCalculator {
    static func calculate(_ input: DetentionCalculationInput) throws -> DetentionCharge {
        guard input.releasedAt >= input.arrivalAt else {
            throw DetentionCalculationError.releasedBeforeArrival
        }

        guard input.freeTimeMinutes >= 0 else {
            throw DetentionCalculationError.negativeFreeTime
        }

        guard input.ratePerHour >= 0 else {
            throw DetentionCalculationError.negativeRate
        }

        // Detention starts with the full wait, then subtracts the free time the
        // carrier agreed to before hourly billing is allowed.
        let elapsedMinutes = Int(
            (input.releasedAt.timeIntervalSince(input.arrivalAt) / 60)
                .rounded(.down)
        )
        let billableMinutes = max(0, elapsedMinutes - input.freeTimeMinutes)
        let amount = (Decimal(billableMinutes) / Decimal(60) * input.ratePerHour).roundedMoney()

        return DetentionCharge(
            elapsedMinutes: elapsedMinutes,
            freeTimeMinutes: input.freeTimeMinutes,
            billableMinutes: billableMinutes,
            ratePerHour: input.ratePerHour.roundedMoney(),
            amount: amount,
            evidenceIDs: input.evidenceIDs
        )
    }
}

/// Per-account invoice numbering. The sequence is returned with the next value
/// so persistence can save it atomically with the invoice later.
struct InvoiceNumberSequence: Equatable, Sendable {
    let accountID: UUID
    let prefix: String
    let nextValue: Int

    func issuingNext() throws -> InvoiceNumberIssue {
        let trimmedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrefix.isEmpty else {
            throw InvoiceNumberSequenceError.emptyPrefix
        }

        guard nextValue > 0 else {
            throw InvoiceNumberSequenceError.invalidNextValue
        }

        let invoiceNumber = "\(trimmedPrefix)-\(nextValue)"
        let nextSequence = InvoiceNumberSequence(
            accountID: accountID,
            prefix: trimmedPrefix,
            nextValue: nextValue + 1
        )

        return InvoiceNumberIssue(number: invoiceNumber, nextSequence: nextSequence)
    }
}

struct InvoiceNumberIssue: Equatable, Sendable {
    let number: String
    let nextSequence: InvoiceNumberSequence
}

enum InvoiceNumberSequenceError: Error, Equatable, Sendable {
    case emptyPrefix
    case invalidNextValue
}

/// One row on an invoice. Evidence IDs connect accessorial charges like
/// detention to the proof needed for collection.
struct InvoiceLineItem: Equatable, Identifiable, Sendable {
    let id: UUID
    let kind: InvoiceLineItemKind
    let description: String
    let amount: Decimal
    let evidenceIDs: [UUID]

    init(
        id: UUID = UUID(),
        kind: InvoiceLineItemKind,
        description: String,
        amount: Decimal,
        evidenceIDs: [UUID] = []
    ) {
        self.id = id
        self.kind = kind
        self.description = description
        self.amount = amount
        self.evidenceIDs = evidenceIDs
    }

    static func detention(
        id: UUID = UUID(),
        description: String,
        charge: DetentionCharge
    ) -> InvoiceLineItem {
        InvoiceLineItem(
            id: id,
            kind: .detention,
            description: description,
            amount: charge.amount,
            evidenceIDs: charge.evidenceIDs
        )
    }
}

enum InvoiceLineItemKind: String, Codable, Sendable {
    case lineHaul
    case fuelSurcharge
    case detention
    case accessorial
    case adjustment
}

/// A reproducible financial snapshot. Later invoice changes append revisions
/// instead of silently replacing the previous total.
struct InvoiceRevision: Equatable, Identifiable, Sendable {
    let id: UUID
    let invoiceID: UUID
    let revisionNumber: Int
    let createdAt: Date
    let lineItems: [InvoiceLineItem]

    var totalAmount: Decimal {
        lineItems.reduce(Decimal(0)) { $0 + $1.amount }.roundedMoney()
    }
}

/// Money received against an invoice. Multiple payments allow partial payment
/// tracking without losing the original invoice total.
struct InvoicePayment: Equatable, Identifiable, Sendable {
    let id: UUID
    let amount: Decimal
    let receivedAt: Date
    let note: String?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        receivedAt: Date,
        note: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.receivedAt = receivedAt
        self.note = note
    }
}

/// Versioned invoice history plus payments. The current revision determines
/// what is due; payments determine what remains.
struct Invoice: Equatable, Identifiable, Sendable {
    let id: UUID
    let accountID: UUID
    let number: String
    let revisions: [InvoiceRevision]
    let payments: [InvoicePayment]

    init(
        id: UUID = UUID(),
        accountID: UUID,
        number: String,
        createdAt: Date,
        lineItems: [InvoiceLineItem]
    ) throws {
        let initialRevision = try Invoice.makeRevision(
            id: UUID(),
            invoiceID: id,
            revisionNumber: 1,
            createdAt: createdAt,
            lineItems: lineItems
        )

        self.id = id
        self.accountID = accountID
        self.number = number
        self.revisions = [initialRevision]
        self.payments = []
    }

    private init(
        id: UUID,
        accountID: UUID,
        number: String,
        revisions: [InvoiceRevision],
        payments: [InvoicePayment]
    ) {
        self.id = id
        self.accountID = accountID
        self.number = number
        self.revisions = revisions
        self.payments = payments
    }

    var currentRevision: InvoiceRevision {
        revisions[revisions.count - 1]
    }

    var paymentReconciliation: InvoicePaymentReconciliation {
        InvoicePaymentReconciliation(
            totalDue: currentRevision.totalAmount,
            payments: payments
        )
    }

    func revising(
        revisionID: UUID = UUID(),
        createdAt: Date,
        lineItems: [InvoiceLineItem]
    ) throws -> Invoice {
        let revision = try Invoice.makeRevision(
            id: revisionID,
            invoiceID: id,
            revisionNumber: currentRevision.revisionNumber + 1,
            createdAt: createdAt,
            lineItems: lineItems
        )

        return Invoice(
            id: id,
            accountID: accountID,
            number: number,
            revisions: revisions + [revision],
            payments: payments
        )
    }

    func recordingPayment(_ payment: InvoicePayment) throws -> Invoice {
        guard payment.amount > 0 else {
            throw InvoiceValidationError.invalidPaymentAmount
        }

        return Invoice(
            id: id,
            accountID: accountID,
            number: number,
            revisions: revisions,
            payments: payments + [payment]
        )
    }

    private static func makeRevision(
        id: UUID,
        invoiceID: UUID,
        revisionNumber: Int,
        createdAt: Date,
        lineItems: [InvoiceLineItem]
    ) throws -> InvoiceRevision {
        guard !lineItems.isEmpty else {
            throw InvoiceValidationError.emptyLineItems
        }

        guard lineItems.allSatisfy({ $0.amount >= 0 }) else {
            throw InvoiceValidationError.negativeLineItemAmount
        }

        return InvoiceRevision(
            id: id,
            invoiceID: invoiceID,
            revisionNumber: revisionNumber,
            createdAt: createdAt,
            lineItems: lineItems.map { lineItem in
                InvoiceLineItem(
                    id: lineItem.id,
                    kind: lineItem.kind,
                    description: lineItem.description,
                    amount: lineItem.amount.roundedMoney(),
                    evidenceIDs: lineItem.evidenceIDs
                )
            }
        )
    }
}

enum InvoiceValidationError: Error, Equatable, Sendable {
    case emptyLineItems
    case negativeLineItemAmount
    case invalidPaymentAmount
}

/// The current money state of an invoice after adding all recorded payments.
/// Overpayment is kept as unapplied credit instead of making balance negative.
struct InvoicePaymentReconciliation: Equatable, Sendable {
    let totalDue: Decimal
    let totalPaid: Decimal
    let remainingBalance: Decimal
    let unappliedCredit: Decimal
    let status: InvoicePaymentStatus

    init(totalDue: Decimal, payments: [InvoicePayment]) {
        let roundedTotalDue = totalDue.roundedMoney()
        let paid = payments
            .map(\.amount)
            .reduce(Decimal(0), +)
            .roundedMoney()
        let rawRemaining = (roundedTotalDue - paid).roundedMoney()

        self.totalDue = roundedTotalDue
        totalPaid = paid
        remainingBalance = max(rawRemaining, 0)
        unappliedCredit = max(-rawRemaining, 0)

        if paid <= 0 {
            status = .unpaid
        } else if paid < roundedTotalDue {
            status = .partial
        } else {
            status = .paid
        }
    }
}

enum InvoicePaymentStatus: String, Codable, Sendable {
    case unpaid
    case partial
    case paid
}

private extension Decimal {
    func roundedMoney() -> Decimal {
        var input = self
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }
}
