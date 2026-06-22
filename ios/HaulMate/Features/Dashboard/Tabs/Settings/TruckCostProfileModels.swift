//
//  Created by Jerel Walters on 6/21/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

struct TruckCostProfileDraft: Equatable, Sendable {
    var equipmentName = ""
    var fuelEconomyMPG = ""
    var fuelPricePerGallon = ""
    var maintenanceReservePerMile = ""
    var monthlyFixedCosts = ""
    var estimatedWorkingMiles = ""
    var dispatchFeePercent = ""
    var factoringFeePercent = ""
    var profitTargetPercent = ""

    var validationErrors: [TruckCostProfileValidationError] {
        var errors: [TruckCostProfileValidationError] = []

        appendRequiredTextError(
            &errors,
            field: .equipment,
            value: equipmentName,
            message: TruckCostProfileStrings.equipmentRequired.localized
        )
        appendDecimalError(
            &errors,
            field: .fuelEconomyMPG,
            value: fuelEconomyMPG,
            requiredMessage: TruckCostProfileStrings.fuelEconomyRequired.localized,
            invalidMessage: TruckCostProfileStrings.fuelEconomyInvalid.localized,
            minimum: .greaterThanZero
        )
        appendDecimalError(
            &errors,
            field: .fuelPricePerGallon,
            value: fuelPricePerGallon,
            requiredMessage: TruckCostProfileStrings.fuelPriceRequired.localized,
            invalidMessage: TruckCostProfileStrings.fuelPriceInvalid.localized,
            minimum: .zeroOrGreater
        )
        appendDecimalError(
            &errors,
            field: .maintenanceReservePerMile,
            value: maintenanceReservePerMile,
            requiredMessage: TruckCostProfileStrings.maintenanceReserveRequired.localized,
            invalidMessage: TruckCostProfileStrings.maintenanceReserveInvalid.localized,
            minimum: .zeroOrGreater
        )
        appendDecimalError(
            &errors,
            field: .monthlyFixedCosts,
            value: monthlyFixedCosts,
            requiredMessage: TruckCostProfileStrings.monthlyFixedCostsRequired.localized,
            invalidMessage: TruckCostProfileStrings.monthlyFixedCostsInvalid.localized,
            minimum: .zeroOrGreater
        )
        appendDecimalError(
            &errors,
            field: .estimatedWorkingMiles,
            value: estimatedWorkingMiles,
            requiredMessage: TruckCostProfileStrings.workingMilesRequired.localized,
            invalidMessage: TruckCostProfileStrings.workingMilesInvalid.localized,
            minimum: .greaterThanZero
        )
        appendDecimalError(
            &errors,
            field: .dispatchFeePercent,
            value: dispatchFeePercent,
            requiredMessage: TruckCostProfileStrings.dispatchFeeRequired.localized,
            invalidMessage: TruckCostProfileStrings.dispatchFeeInvalid.localized,
            minimum: .zeroOrGreater
        )
        appendDecimalError(
            &errors,
            field: .factoringFeePercent,
            value: factoringFeePercent,
            requiredMessage: TruckCostProfileStrings.factoringFeeRequired.localized,
            invalidMessage: TruckCostProfileStrings.factoringFeeInvalid.localized,
            minimum: .zeroOrGreater
        )
        appendDecimalError(
            &errors,
            field: .profitTargetPercent,
            value: profitTargetPercent,
            requiredMessage: TruckCostProfileStrings.profitTargetRequired.localized,
            invalidMessage: TruckCostProfileStrings.profitTargetInvalid.localized,
            minimum: .zeroOrGreater
        )

        return errors
    }

    var canSave: Bool {
        validationErrors.isEmpty
    }

    var derivedFixedCostPerMile: Decimal? {
        // Fixed-cost allocation is separate from MPG and fuel cost; load evaluation combines those inputs later.
        guard
            let monthlyFixedCosts = decimal(from: monthlyFixedCosts),
            let estimatedWorkingMiles = decimal(from: estimatedWorkingMiles),
            monthlyFixedCosts >= 0,
            estimatedWorkingMiles > 0
        else {
            return nil
        }

        return (monthlyFixedCosts / estimatedWorkingMiles).rounded(scale: 2)
    }

    var normalized: TruckCostProfileDraft {
        // Keep percentages in user-facing percent units here; the core profitability layer can convert to ratios.
        TruckCostProfileDraft(
            equipmentName: equipmentName.trimmed,
            fuelEconomyMPG: normalizedDecimalString(fuelEconomyMPG),
            fuelPricePerGallon: normalizedDecimalString(fuelPricePerGallon),
            maintenanceReservePerMile: normalizedDecimalString(maintenanceReservePerMile),
            monthlyFixedCosts: normalizedDecimalString(monthlyFixedCosts),
            estimatedWorkingMiles: normalizedDecimalString(estimatedWorkingMiles),
            dispatchFeePercent: normalizedDecimalString(dispatchFeePercent),
            factoringFeePercent: normalizedDecimalString(factoringFeePercent),
            profitTargetPercent: normalizedDecimalString(profitTargetPercent)
        )
    }

    func decimalValue(for field: TruckCostProfileField) -> Decimal? {
        switch field {
        case .equipment:
            return nil
        case .fuelEconomyMPG:
            return decimal(from: fuelEconomyMPG)
        case .fuelPricePerGallon:
            return decimal(from: fuelPricePerGallon)
        case .maintenanceReservePerMile:
            return decimal(from: maintenanceReservePerMile)
        case .monthlyFixedCosts:
            return decimal(from: monthlyFixedCosts)
        case .estimatedWorkingMiles:
            return decimal(from: estimatedWorkingMiles)
        case .dispatchFeePercent:
            return decimal(from: dispatchFeePercent)
        case .factoringFeePercent:
            return decimal(from: factoringFeePercent)
        case .profitTargetPercent:
            return decimal(from: profitTargetPercent)
        }
    }

    private func appendRequiredTextError(
        _ errors: inout [TruckCostProfileValidationError],
        field: TruckCostProfileField,
        value: String,
        message: String
    ) {
        guard value.trimmed.isEmpty else { return }

        errors.append(
            TruckCostProfileValidationError(field: field, message: message)
        )
    }

    private func appendDecimalError(
        _ errors: inout [TruckCostProfileValidationError],
        field: TruckCostProfileField,
        value: String,
        requiredMessage: String,
        invalidMessage: String,
        minimum: DecimalMinimum
    ) {
        if value.trimmed.isEmpty {
            errors.append(
                TruckCostProfileValidationError(field: field, message: requiredMessage)
            )
            return
        }

        guard let decimal = decimal(from: value) else {
            errors.append(
                TruckCostProfileValidationError(field: field, message: invalidMessage)
            )
            return
        }

        switch minimum {
        case .zeroOrGreater where decimal < 0:
            errors.append(
                TruckCostProfileValidationError(field: field, message: invalidMessage)
            )
        case .greaterThanZero where decimal <= 0:
            errors.append(
                TruckCostProfileValidationError(field: field, message: invalidMessage)
            )
        default:
            break
        }
    }

    private func decimal(from value: String) -> Decimal? {
        // Decimal(string:) rejects grouping separators, but pilots may type currency-style values like "8,400".
        let normalized = value.trimmed
            .replacingOccurrences(of: ",", with: "")

        guard !normalized.isEmpty else { return nil }

        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func normalizedDecimalString(_ value: String) -> String {
        value.trimmed.replacingOccurrences(of: ",", with: "")
    }
}

struct TruckCostProfileValidationError: Equatable, Identifiable, Sendable {
    let field: TruckCostProfileField
    let message: String

    var id: TruckCostProfileField { field }
}

enum TruckCostProfileField: String, Sendable {
    case equipment
    case fuelEconomyMPG
    case fuelPricePerGallon
    case maintenanceReservePerMile
    case monthlyFixedCosts
    case estimatedWorkingMiles
    case dispatchFeePercent
    case factoringFeePercent
    case profitTargetPercent
}

private enum DecimalMinimum {
    case zeroOrGreater
    case greaterThanZero
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}

extension TruckCostProfileDraft {
    // Matches Jira KAN-15 Figma node 1-512 and the committed supporting-flow export.
    static let figmaBaseline = TruckCostProfileDraft(
        equipmentName: "Tractor-trailer",
        fuelEconomyMPG: "6.7",
        fuelPricePerGallon: "3.64",
        maintenanceReservePerMile: "0.35",
        monthlyFixedCosts: "8400",
        estimatedWorkingMiles: "11350",
        dispatchFeePercent: "5",
        factoringFeePercent: "3",
        profitTargetPercent: "25"
    )
}
