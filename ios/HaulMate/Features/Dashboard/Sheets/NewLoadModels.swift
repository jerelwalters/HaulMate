//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

struct NewLoadDraft: Equatable, Sendable {
    let truckProfile: TruckCostProfileDraft

    var brokerCustomer = ""
    var referenceNumber = ""
    var pickupLocation = ""
    var deliveryLocation = ""
    var lineHaulRate = ""
    var fuelSurcharge = "0"
    var accessorialRevenue = "0"
    var loadedMiles = ""
    var deadheadMiles = "0"
    var estimatedTolls = "0"
    var dispatchFeePercent: String
    var factoringFeePercent: String
    var otherFlatFee = "0"
    var overrideFuelEconomyMPG = ""
    var overrideFuelPricePerGallon = ""
    var overrideMaintenanceReservePerMile = ""
    var overrideMonthlyFixedCosts = ""
    var overrideWorkingMiles = ""
    var status = NewLoadSaveStatus.evaluating

    init(truckProfile: TruckCostProfileDraft = .figmaBaseline) {
        let normalizedProfile = truckProfile.normalized
        self.truckProfile = normalizedProfile
        dispatchFeePercent = normalizedProfile.dispatchFeePercent
        factoringFeePercent = normalizedProfile.factoringFeePercent
    }

    var profitabilityCalculation: ProfitabilityCalculation {
        ProfitabilityCalculator.calculate(profitabilityInput)
    }

    var readyEstimate: ProfitabilityEstimate? {
        profitabilityCalculation.readyEstimate
    }

    var inputIssues: [ProfitabilityInputIssue] {
        profitabilityCalculation.inputIssues
    }

    var saveValidationErrors: [NewLoadValidationError] {
        var errors: [NewLoadValidationError] = []

        appendRequiredTextError(
            &errors,
            field: .brokerCustomer,
            value: brokerCustomer,
            message: NewLoadStrings.brokerRequired.localized
        )
        appendRequiredTextError(
            &errors,
            field: .referenceNumber,
            value: referenceNumber,
            message: NewLoadStrings.referenceRequired.localized
        )
        appendRequiredTextError(
            &errors,
            field: .pickupLocation,
            value: pickupLocation,
            message: NewLoadStrings.pickupRequired.localized
        )
        appendRequiredTextError(
            &errors,
            field: .deliveryLocation,
            value: deliveryLocation,
            message: NewLoadStrings.deliveryRequired.localized
        )

        return errors
    }

    var canSave: Bool {
        readyEstimate != nil && saveValidationErrors.isEmpty
    }

    var normalized: NewLoadDraft {
        var draft = NewLoadDraft(truckProfile: truckProfile)
        draft.brokerCustomer = brokerCustomer.trimmed
        draft.referenceNumber = referenceNumber.trimmed
        draft.pickupLocation = pickupLocation.trimmed
        draft.deliveryLocation = deliveryLocation.trimmed
        draft.lineHaulRate = normalizedDecimalString(lineHaulRate)
        draft.fuelSurcharge = normalizedDecimalString(fuelSurcharge)
        draft.accessorialRevenue = normalizedDecimalString(accessorialRevenue)
        draft.loadedMiles = normalizedDecimalString(loadedMiles)
        draft.deadheadMiles = normalizedDecimalString(deadheadMiles)
        draft.estimatedTolls = normalizedDecimalString(estimatedTolls)
        draft.dispatchFeePercent = normalizedDecimalString(dispatchFeePercent)
        draft.factoringFeePercent = normalizedDecimalString(factoringFeePercent)
        draft.otherFlatFee = normalizedDecimalString(otherFlatFee)
        draft.overrideFuelEconomyMPG = normalizedDecimalString(overrideFuelEconomyMPG)
        draft.overrideFuelPricePerGallon = normalizedDecimalString(overrideFuelPricePerGallon)
        draft.overrideMaintenanceReservePerMile = normalizedDecimalString(overrideMaintenanceReservePerMile)
        draft.overrideMonthlyFixedCosts = normalizedDecimalString(overrideMonthlyFixedCosts)
        draft.overrideWorkingMiles = normalizedDecimalString(overrideWorkingMiles)
        draft.status = status
        return draft
    }

    func saveSnapshot(
        attachment: RateConfirmationAttachment? = nil
    ) -> SavedLoadEvaluation? {
        guard canSave, let estimate = readyEstimate else { return nil }

        return SavedLoadEvaluation(
            draft: normalized,
            estimate: estimate,
            attachment: attachment
        )
    }

    private var profitabilityInput: ProfitabilityInput {
        ProfitabilityInput(
            lineHaulRate: decimal(from: lineHaulRate),
            fuelSurcharge: decimalOrZero(from: fuelSurcharge),
            accessorialRevenue: decimalOrZero(from: accessorialRevenue),
            loadedMiles: decimal(from: loadedMiles),
            deadheadMiles: decimalOrZero(from: deadheadMiles),
            estimatedTolls: decimalOrZero(from: estimatedTolls),
            operatingCosts: operatingCosts,
            fees: profitabilityFees
        )
    }

    private var operatingCosts: OperatingCostInputs {
        truckCostDefaults.operatingCosts(applying: costOverrides)
    }

    private var truckCostDefaults: TruckCostDefaults {
        TruckCostDefaults(
            fuelEconomyMilesPerGallon: truckProfile.decimalValue(for: .fuelEconomyMPG),
            fuelPricePerGallon: truckProfile.decimalValue(for: .fuelPricePerGallon),
            maintenanceReservePerMile: truckProfile.decimalValue(for: .maintenanceReservePerMile),
            monthlyFixedCosts: truckProfile.decimalValue(for: .monthlyFixedCosts),
            workingMilesPerMonth: truckProfile.decimalValue(for: .estimatedWorkingMiles)
        )
    }

    private var costOverrides: LoadCostOverrides {
        LoadCostOverrides(
            fuelEconomyMilesPerGallon: optionalDecimal(from: overrideFuelEconomyMPG),
            fuelPricePerGallon: optionalDecimal(from: overrideFuelPricePerGallon),
            maintenanceReservePerMile: optionalDecimal(from: overrideMaintenanceReservePerMile),
            monthlyFixedCosts: optionalDecimal(from: overrideMonthlyFixedCosts),
            workingMilesPerMonth: optionalDecimal(from: overrideWorkingMiles)
        )
    }

    private var profitabilityFees: [ProfitabilityFee] {
        [
            .percentage(
                name: NewLoadStrings.dispatchFeeLabel.localized,
                rate: percentageRate(from: dispatchFeePercent)
            ),
            .percentage(
                name: NewLoadStrings.factoringFeeLabel.localized,
                rate: percentageRate(from: factoringFeePercent)
            ),
            .flat(
                name: NewLoadStrings.otherFlatFeeLabel.localized,
                amount: decimalOrZero(from: otherFlatFee)
            )
        ]
    }

    private func appendRequiredTextError(
        _ errors: inout [NewLoadValidationError],
        field: NewLoadField,
        value: String,
        message: String
    ) {
        guard value.trimmed.isEmpty else { return }

        errors.append(NewLoadValidationError(field: field, message: message))
    }

    private func optionalDecimal(from value: String) -> Decimal? {
        value.trimmed.isEmpty ? nil : decimal(from: value)
    }

    private func decimalOrZero(from value: String) -> Decimal {
        value.trimmed.isEmpty ? 0 : (decimal(from: value) ?? -1)
    }

    private func percentageRate(from value: String) -> Decimal {
        decimalOrZero(from: value) / 100
    }

    private func decimal(from value: String) -> Decimal? {
        let normalized = normalizedDecimalString(value)
        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func normalizedDecimalString(_ value: String) -> String {
        value.trimmed.replacingOccurrences(of: ",", with: "")
    }
}

enum NewLoadSaveStatus: String, CaseIterable, Identifiable, Sendable {
    case evaluating
    case accepted
    case rejected

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .evaluating:
            return NewLoadStrings.evaluatingStatus.localized
        case .accepted:
            return NewLoadStrings.acceptedStatus.localized
        case .rejected:
            return NewLoadStrings.rejectedStatus.localized
        }
    }
}

struct NewLoadValidationError: Equatable, Identifiable, Sendable {
    let field: NewLoadField
    let message: String

    var id: NewLoadField { field }
}

enum NewLoadField: Hashable, Sendable {
    case brokerCustomer
    case referenceNumber
    case pickupLocation
    case deliveryLocation
}

struct RateConfirmationAttachment: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case pdf
        case image
        case other
    }

    let fileName: String
    let kind: Kind

    init(fileName: String, kind: Kind) {
        self.fileName = fileName
        self.kind = kind
    }

    init(url: URL) {
        fileName = url.lastPathComponent

        switch url.pathExtension.lowercased() {
        case "pdf":
            kind = .pdf
        case "jpg", "jpeg", "png", "heic", "heif":
            kind = .image
        default:
            kind = .other
        }
    }

    var localizedKind: String {
        switch kind {
        case .pdf:
            return NewLoadStrings.attachmentKindPDF.localized
        case .image:
            return NewLoadStrings.attachmentKindImage.localized
        case .other:
            return NewLoadStrings.attachmentKindOther.localized
        }
    }
}

struct SavedLoadEvaluation: Equatable, Sendable {
    let draft: NewLoadDraft
    let estimate: ProfitabilityEstimate
    let attachment: RateConfirmationAttachment?
}

extension ProfitabilityCalculation {
    var readyEstimate: ProfitabilityEstimate? {
        switch self {
        case .ready(let estimate):
            return estimate
        case .invalid:
            return nil
        }
    }

    var inputIssues: [ProfitabilityInputIssue] {
        switch self {
        case .ready:
            return []
        case .invalid(let issues):
            return issues
        }
    }
}
