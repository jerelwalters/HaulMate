//
//  Created by Jerel Walters on 6/22/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

struct TruckCostDefaults: Equatable, Sendable {
    let fuelEconomyMilesPerGallon: Decimal?
    let fuelPricePerGallon: Decimal?
    let maintenanceReservePerMile: Decimal?
    let monthlyFixedCosts: Decimal?
    let workingMilesPerMonth: Decimal?

    func operatingCosts(
        applying overrides: LoadCostOverrides = LoadCostOverrides()
    ) -> OperatingCostInputs {
        OperatingCostInputs(
            fuelEconomyMilesPerGallon: overrides.fuelEconomyMilesPerGallon
                ?? fuelEconomyMilesPerGallon,
            fuelPricePerGallon: overrides.fuelPricePerGallon
                ?? fuelPricePerGallon,
            maintenanceReservePerMile: overrides.maintenanceReservePerMile
                ?? maintenanceReservePerMile,
            monthlyFixedCosts: overrides.monthlyFixedCosts
                ?? monthlyFixedCosts,
            workingMilesPerMonth: overrides.workingMilesPerMonth
                ?? workingMilesPerMonth
        )
    }
}

struct LoadCostOverrides: Equatable, Sendable {
    var fuelEconomyMilesPerGallon: Decimal? = nil
    var fuelPricePerGallon: Decimal? = nil
    var maintenanceReservePerMile: Decimal? = nil
    var monthlyFixedCosts: Decimal? = nil
    var workingMilesPerMonth: Decimal? = nil
}

struct ProfitabilityInput: Equatable, Sendable {
    let lineHaulRate: Decimal?
    let fuelSurcharge: Decimal?
    let accessorialRevenue: Decimal
    let loadedMiles: Decimal?
    let deadheadMiles: Decimal?
    let estimatedTolls: Decimal
    let operatingCosts: OperatingCostInputs
    let fees: [ProfitabilityFee]

    init(
        lineHaulRate: Decimal?,
        fuelSurcharge: Decimal?,
        accessorialRevenue: Decimal = 0,
        loadedMiles: Decimal?,
        deadheadMiles: Decimal?,
        estimatedTolls: Decimal = 0,
        operatingCosts: OperatingCostInputs,
        fees: [ProfitabilityFee] = []
    ) {
        self.lineHaulRate = lineHaulRate
        self.fuelSurcharge = fuelSurcharge
        self.accessorialRevenue = accessorialRevenue
        self.loadedMiles = loadedMiles
        self.deadheadMiles = deadheadMiles
        self.estimatedTolls = estimatedTolls
        self.operatingCosts = operatingCosts
        self.fees = fees
    }
}

struct OperatingCostInputs: Equatable, Sendable {
    let fuelEconomyMilesPerGallon: Decimal?
    let fuelPricePerGallon: Decimal?
    let maintenanceReservePerMile: Decimal?
    let monthlyFixedCosts: Decimal?
    let workingMilesPerMonth: Decimal?
}

struct ProfitabilityFee: Equatable, Sendable {
    let name: String
    let kind: ProfitabilityFeeKind

    static func flat(name: String, amount: Decimal) -> ProfitabilityFee {
        ProfitabilityFee(name: name, kind: .flat(amount: amount))
    }

    static func percentage(name: String, rate: Decimal) -> ProfitabilityFee {
        ProfitabilityFee(name: name, kind: .percentage(rate: rate))
    }
}

enum ProfitabilityFeeKind: Equatable, Sendable {
    case flat(amount: Decimal)
    case percentage(rate: Decimal)
}

enum ProfitabilityCalculation: Equatable, Sendable {
    case ready(ProfitabilityEstimate)
    case invalid([ProfitabilityInputIssue])
}

struct ProfitabilityEstimate: Equatable, Sendable {
    let inputs: ResolvedProfitabilityInputs
    let grossRevenue: Decimal
    let fuelCost: Decimal
    let maintenanceCost: Decimal
    let fixedCostAllocation: Decimal
    let feeCost: Decimal
    let totalOperatingCost: Decimal
    let estimatedProfit: Decimal
    let margin: Decimal
    let revenuePerLoadedMile: Decimal
    let revenuePerTotalMile: Decimal
}

struct ResolvedProfitabilityInputs: Equatable, Sendable {
    let lineHaulRate: Decimal
    let fuelSurcharge: Decimal
    let accessorialRevenue: Decimal
    let loadedMiles: Decimal
    let deadheadMiles: Decimal
    let totalMiles: Decimal
    let fuelEconomyMilesPerGallon: Decimal
    let fuelPricePerGallon: Decimal
    let maintenanceReservePerMile: Decimal
    let fixedCostPerMile: Decimal
    let estimatedTolls: Decimal
    let feeAmounts: [ProfitabilityFeeAmount]
}

struct ProfitabilityFeeAmount: Equatable, Sendable {
    let fee: ProfitabilityFee
    let amount: Decimal
}

struct ProfitabilityInputIssue: Equatable, Sendable {
    let field: ProfitabilityInputField
    let reason: ProfitabilityInputIssueReason
}

enum ProfitabilityInputField: Equatable, Sendable {
    case lineHaulRate
    case fuelSurcharge
    case accessorialRevenue
    case loadedMiles
    case deadheadMiles
    case totalMiles
    case fuelEconomyMilesPerGallon
    case fuelPricePerGallon
    case maintenanceReservePerMile
    case monthlyFixedCosts
    case workingMilesPerMonth
    case estimatedTolls
    case fee(index: Int)
}

enum ProfitabilityInputIssueReason: Equatable, Sendable {
    case missing
    case mustBeGreaterThanZero
    case cannotBeNegative
    case mustBeBetweenZeroAndOne
}

enum ProfitabilityCalculator {
    static func calculate(_ input: ProfitabilityInput) -> ProfitabilityCalculation {
        let issues = validate(input)
        guard issues.isEmpty else { return .invalid(issues) }

        let lineHaulRate = input.lineHaulRate!
        let fuelSurcharge = input.fuelSurcharge!
        let loadedMiles = input.loadedMiles!
        let deadheadMiles = input.deadheadMiles!
        let fuelEconomy = input.operatingCosts.fuelEconomyMilesPerGallon!
        let fuelPrice = input.operatingCosts.fuelPricePerGallon!
        let maintenanceReserve = input.operatingCosts.maintenanceReservePerMile!
        let monthlyFixedCosts = input.operatingCosts.monthlyFixedCosts!
        let workingMiles = input.operatingCosts.workingMilesPerMonth!

        let totalMiles = loadedMiles + deadheadMiles
        let grossRevenue = lineHaulRate + fuelSurcharge + input.accessorialRevenue
        let fixedCostPerMile = monthlyFixedCosts / workingMiles
        let fuelCost = totalMiles / fuelEconomy * fuelPrice
        let maintenanceCost = totalMiles * maintenanceReserve
        let fixedCostAllocation = totalMiles * fixedCostPerMile
        let feeAmounts = input.fees.map { fee in
            ProfitabilityFeeAmount(
                fee: fee,
                amount: roundedMoney(amount(for: fee, grossRevenue: grossRevenue))
            )
        }
        let feeCost = feeAmounts.reduce(Decimal(0)) { $0 + $1.amount }
        let totalOperatingCost = fuelCost
            + maintenanceCost
            + fixedCostAllocation
            + input.estimatedTolls
            + feeCost
        let estimatedProfit = grossRevenue - totalOperatingCost

        let resolvedInputs = ResolvedProfitabilityInputs(
            lineHaulRate: roundedMoney(lineHaulRate),
            fuelSurcharge: roundedMoney(fuelSurcharge),
            accessorialRevenue: roundedMoney(input.accessorialRevenue),
            loadedMiles: loadedMiles,
            deadheadMiles: deadheadMiles,
            totalMiles: totalMiles,
            fuelEconomyMilesPerGallon: fuelEconomy,
            fuelPricePerGallon: roundedMoney(fuelPrice),
            maintenanceReservePerMile: maintenanceReserve,
            fixedCostPerMile: rounded(fixedCostPerMile, scale: 4),
            estimatedTolls: roundedMoney(input.estimatedTolls),
            feeAmounts: feeAmounts
        )

        return .ready(
            ProfitabilityEstimate(
                inputs: resolvedInputs,
                grossRevenue: roundedMoney(grossRevenue),
                fuelCost: roundedMoney(fuelCost),
                maintenanceCost: roundedMoney(maintenanceCost),
                fixedCostAllocation: roundedMoney(fixedCostAllocation),
                feeCost: roundedMoney(feeCost),
                totalOperatingCost: roundedMoney(totalOperatingCost),
                estimatedProfit: roundedMoney(estimatedProfit),
                margin: rounded(estimatedProfit / grossRevenue, scale: 4),
                revenuePerLoadedMile: roundedMoney(grossRevenue / loadedMiles),
                revenuePerTotalMile: roundedMoney(grossRevenue / totalMiles)
            )
        )
    }

    private static func validate(
        _ input: ProfitabilityInput
    ) -> [ProfitabilityInputIssue] {
        var issues: [ProfitabilityInputIssue] = []

        validateRequiredPositive(input.lineHaulRate, field: .lineHaulRate, into: &issues)
        validateRequiredMoney(input.fuelSurcharge, field: .fuelSurcharge, into: &issues)
        validateNonNegative(input.accessorialRevenue, field: .accessorialRevenue, into: &issues)
        validateRequiredPositive(input.loadedMiles, field: .loadedMiles, into: &issues)
        validateRequiredNonNegative(input.deadheadMiles, field: .deadheadMiles, into: &issues)

        if let loadedMiles = input.loadedMiles,
           let deadheadMiles = input.deadheadMiles,
           loadedMiles + deadheadMiles <= 0 {
            issues.append(
                ProfitabilityInputIssue(
                    field: .totalMiles,
                    reason: .mustBeGreaterThanZero
                )
            )
        }

        validateNonNegative(input.estimatedTolls, field: .estimatedTolls, into: &issues)
        validateRequiredPositive(
            input.operatingCosts.fuelEconomyMilesPerGallon,
            field: .fuelEconomyMilesPerGallon,
            into: &issues
        )
        validateRequiredMoney(
            input.operatingCosts.fuelPricePerGallon,
            field: .fuelPricePerGallon,
            into: &issues
        )
        validateRequiredMoney(
            input.operatingCosts.maintenanceReservePerMile,
            field: .maintenanceReservePerMile,
            into: &issues
        )
        validateRequiredMoney(
            input.operatingCosts.monthlyFixedCosts,
            field: .monthlyFixedCosts,
            into: &issues
        )
        validateRequiredPositive(
            input.operatingCosts.workingMilesPerMonth,
            field: .workingMilesPerMonth,
            into: &issues
        )

        for (index, fee) in input.fees.enumerated() {
            validate(fee: fee, index: index, into: &issues)
        }

        return issues
    }

    private static func validateRequiredMoney(
        _ value: Decimal?,
        field: ProfitabilityInputField,
        into issues: inout [ProfitabilityInputIssue]
    ) {
        guard let value else {
            issues.append(ProfitabilityInputIssue(field: field, reason: .missing))
            return
        }

        validateNonNegative(value, field: field, into: &issues)
    }

    private static func validateRequiredPositive(
        _ value: Decimal?,
        field: ProfitabilityInputField,
        into issues: inout [ProfitabilityInputIssue]
    ) {
        guard let value else {
            issues.append(ProfitabilityInputIssue(field: field, reason: .missing))
            return
        }

        guard value > 0 else {
            issues.append(
                ProfitabilityInputIssue(
                    field: field,
                    reason: .mustBeGreaterThanZero
                )
            )
            return
        }
    }

    private static func validateRequiredNonNegative(
        _ value: Decimal?,
        field: ProfitabilityInputField,
        into issues: inout [ProfitabilityInputIssue]
    ) {
        guard let value else {
            issues.append(ProfitabilityInputIssue(field: field, reason: .missing))
            return
        }

        validateNonNegative(value, field: field, into: &issues)
    }

    private static func validateNonNegative(
        _ value: Decimal,
        field: ProfitabilityInputField,
        into issues: inout [ProfitabilityInputIssue]
    ) {
        guard value >= 0 else {
            issues.append(
                ProfitabilityInputIssue(field: field, reason: .cannotBeNegative)
            )
            return
        }
    }

    private static func validate(
        fee: ProfitabilityFee,
        index: Int,
        into issues: inout [ProfitabilityInputIssue]
    ) {
        let issueField = ProfitabilityInputField.fee(index: index)

        switch fee.kind {
        case .flat(let amount):
            validateNonNegative(amount, field: issueField, into: &issues)
        case .percentage(let rate):
            validatePercentage(rate, field: issueField, into: &issues)
        }
    }

    private static func validatePercentage(
        _ rate: Decimal,
        field: ProfitabilityInputField,
        into issues: inout [ProfitabilityInputIssue]
    ) {
        guard rate >= 0 else {
            issues.append(
                ProfitabilityInputIssue(field: field, reason: .cannotBeNegative)
            )
            return
        }

        guard rate <= 1 else {
            issues.append(
                ProfitabilityInputIssue(field: field, reason: .mustBeBetweenZeroAndOne)
            )
            return
        }
    }

    private static func amount(
        for fee: ProfitabilityFee,
        grossRevenue: Decimal
    ) -> Decimal {
        switch fee.kind {
        case .flat(let amount):
            return amount
        case .percentage(let rate):
            return grossRevenue * rate
        }
    }

    private static func roundedMoney(_ value: Decimal) -> Decimal {
        rounded(value, scale: 2)
    }

    private static func rounded(
        _ value: Decimal,
        scale: Int
    ) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }
}
