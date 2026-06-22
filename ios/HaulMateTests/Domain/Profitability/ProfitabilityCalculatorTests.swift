//
//  Created by Jerel Walters on 6/22/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import HaulMate

final class ProfitabilityCalculatorTests: XCTestCase {
    func testCalculatesProfitabilityWithDecimalSafeInputs() throws {
        let result = ProfitabilityCalculator.calculate(
            ProfitabilityInput(
                lineHaulRate: decimal("1850"),
                fuelSurcharge: decimal("150"),
                accessorialRevenue: decimal("135"),
                loadedMiles: decimal("540"),
                deadheadMiles: decimal("72"),
                estimatedTolls: decimal("80"),
                operatingCosts: OperatingCostInputs(
                    fuelEconomyMilesPerGallon: decimal("6"),
                    fuelPricePerGallon: decimal("4"),
                    maintenanceReservePerMile: decimal("0.25"),
                    monthlyFixedCosts: decimal("2500"),
                    workingMilesPerMonth: decimal("5000")
                ),
                fees: [
                    .percentage(name: "Dispatch", rate: decimal("0.10")),
                    .percentage(name: "Factoring", rate: decimal("0.03")),
                    .flat(name: "Admin", amount: decimal("25"))
                ]
            )
        )

        let estimate = try XCTUnwrap(result.readyEstimate)

        XCTAssertEqual(estimate.grossRevenue, decimal("2135.00"))
        XCTAssertEqual(estimate.inputs.totalMiles, decimal("612"))
        XCTAssertEqual(estimate.inputs.fixedCostPerMile, decimal("0.5000"))
        XCTAssertEqual(estimate.fuelCost, decimal("408.00"))
        XCTAssertEqual(estimate.maintenanceCost, decimal("153.00"))
        XCTAssertEqual(estimate.fixedCostAllocation, decimal("306.00"))
        XCTAssertEqual(estimate.feeCost, decimal("302.55"))
        XCTAssertEqual(estimate.totalOperatingCost, decimal("1249.55"))
        XCTAssertEqual(estimate.estimatedProfit, decimal("885.45"))
        XCTAssertEqual(estimate.margin, decimal("0.4147"))
        XCTAssertEqual(estimate.revenuePerLoadedMile, decimal("3.95"))
        XCTAssertEqual(estimate.revenuePerTotalMile, decimal("3.49"))
    }

    func testNaturalLanguageProfitabilityBreakdownMatchesTheFormula() throws {
        // A driver can explain this quote as:
        // "It pays $1,350. I have to drive 360 total miles, not just 300 loaded.
        // Fuel is $240, maintenance reserve is $72, fixed cost allocation is $180,
        // tolls are $30, and dispatch/factoring/admin fees are $190.50.
        // That leaves an estimated $637.50 profit."
        let result = ProfitabilityCalculator.calculate(
            ProfitabilityInput(
                lineHaulRate: decimal("1200"),
                fuelSurcharge: decimal("100"),
                accessorialRevenue: decimal("50"),
                loadedMiles: decimal("300"),
                deadheadMiles: decimal("60"),
                estimatedTolls: decimal("30"),
                operatingCosts: OperatingCostInputs(
                    fuelEconomyMilesPerGallon: decimal("6"),
                    fuelPricePerGallon: decimal("4"),
                    maintenanceReservePerMile: decimal("0.20"),
                    monthlyFixedCosts: decimal("3000"),
                    workingMilesPerMonth: decimal("6000")
                ),
                fees: [
                    .percentage(name: "Dispatch", rate: decimal("0.10")),
                    .percentage(name: "Factoring", rate: decimal("0.03")),
                    .flat(name: "Admin", amount: decimal("15"))
                ]
            )
        )

        let estimate = try XCTUnwrap(result.readyEstimate)

        XCTAssertEqual(estimate.grossRevenue, decimal("1350.00"))
        XCTAssertEqual(estimate.inputs.loadedMiles, decimal("300"))
        XCTAssertEqual(estimate.inputs.deadheadMiles, decimal("60"))
        XCTAssertEqual(estimate.inputs.totalMiles, decimal("360"))
        XCTAssertEqual(estimate.inputs.fixedCostPerMile, decimal("0.5000"))
        XCTAssertEqual(estimate.fuelCost, decimal("240.00"))
        XCTAssertEqual(estimate.maintenanceCost, decimal("72.00"))
        XCTAssertEqual(estimate.fixedCostAllocation, decimal("180.00"))
        XCTAssertEqual(estimate.feeCost, decimal("190.50"))
        XCTAssertEqual(estimate.totalOperatingCost, decimal("712.50"))
        XCTAssertEqual(estimate.estimatedProfit, decimal("637.50"))
        XCTAssertEqual(estimate.margin, decimal("0.4722"))
        XCTAssertEqual(estimate.revenuePerLoadedMile, decimal("4.50"))
        XCTAssertEqual(estimate.revenuePerTotalMile, decimal("3.75"))
        XCTAssertEqual(
            estimate.inputs.feeAmounts.map(\.amount),
            [decimal("135.00"), decimal("40.50"), decimal("15.00")]
        )
    }

    func testDeadheadMilesLowerProfitAndRevenuePerTotalMile() throws {
        let noDeadhead = try XCTUnwrap(
            ProfitabilityCalculator.calculate(
                ProfitabilityInput(
                    lineHaulRate: decimal("1000"),
                    fuelSurcharge: decimal("0"),
                    loadedMiles: decimal("100"),
                    deadheadMiles: decimal("0"),
                    operatingCosts: noFixedCostInputs
                )
            ).readyEstimate
        )
        let withDeadhead = try XCTUnwrap(
            ProfitabilityCalculator.calculate(
                ProfitabilityInput(
                    lineHaulRate: decimal("1000"),
                    fuelSurcharge: decimal("0"),
                    loadedMiles: decimal("100"),
                    deadheadMiles: decimal("100"),
                    operatingCosts: noFixedCostInputs
                )
            ).readyEstimate
        )

        XCTAssertEqual(noDeadhead.fuelCost, decimal("40.00"))
        XCTAssertEqual(noDeadhead.estimatedProfit, decimal("960.00"))
        XCTAssertEqual(noDeadhead.revenuePerTotalMile, decimal("10.00"))
        XCTAssertEqual(withDeadhead.fuelCost, decimal("80.00"))
        XCTAssertEqual(withDeadhead.estimatedProfit, decimal("920.00"))
        XCTAssertEqual(withDeadhead.revenuePerTotalMile, decimal("5.00"))
    }

    func testFixedCostsAreSpreadAcrossWorkingMilesBeforeTheyHitALoad() throws {
        let result = ProfitabilityCalculator.calculate(
            ProfitabilityInput(
                lineHaulRate: decimal("900"),
                fuelSurcharge: decimal("0"),
                loadedMiles: decimal("200"),
                deadheadMiles: decimal("50"),
                operatingCosts: OperatingCostInputs(
                    fuelEconomyMilesPerGallon: decimal("10"),
                    fuelPricePerGallon: decimal("0"),
                    maintenanceReservePerMile: decimal("0"),
                    monthlyFixedCosts: decimal("3000"),
                    workingMilesPerMonth: decimal("6000")
                )
            )
        )

        let estimate = try XCTUnwrap(result.readyEstimate)

        XCTAssertEqual(estimate.inputs.totalMiles, decimal("250"))
        XCTAssertEqual(estimate.inputs.fixedCostPerMile, decimal("0.5000"))
        XCTAssertEqual(estimate.fixedCostAllocation, decimal("125.00"))
        XCTAssertEqual(estimate.estimatedProfit, decimal("775.00"))
    }

    func testMissingInputsReturnIssuesInsteadOfZeroEstimate() {
        let result = ProfitabilityCalculator.calculate(
            ProfitabilityInput(
                lineHaulRate: nil,
                fuelSurcharge: nil,
                loadedMiles: nil,
                deadheadMiles: nil,
                operatingCosts: OperatingCostInputs(
                    fuelEconomyMilesPerGallon: nil,
                    fuelPricePerGallon: nil,
                    maintenanceReservePerMile: nil,
                    monthlyFixedCosts: nil,
                    workingMilesPerMonth: nil
                )
            )
        )

        XCTAssertEqual(
            result.inputIssues,
            [
                ProfitabilityInputIssue(field: .lineHaulRate, reason: .missing),
                ProfitabilityInputIssue(field: .fuelSurcharge, reason: .missing),
                ProfitabilityInputIssue(field: .loadedMiles, reason: .missing),
                ProfitabilityInputIssue(field: .deadheadMiles, reason: .missing),
                ProfitabilityInputIssue(
                    field: .fuelEconomyMilesPerGallon,
                    reason: .missing
                ),
                ProfitabilityInputIssue(field: .fuelPricePerGallon, reason: .missing),
                ProfitabilityInputIssue(
                    field: .maintenanceReservePerMile,
                    reason: .missing
                ),
                ProfitabilityInputIssue(field: .monthlyFixedCosts, reason: .missing),
                ProfitabilityInputIssue(field: .workingMilesPerMonth, reason: .missing)
            ]
        )
    }

    func testInvalidMilesMPGPercentagesAndCostsReturnIssues() {
        let result = ProfitabilityCalculator.calculate(
            ProfitabilityInput(
                lineHaulRate: decimal("0"),
                fuelSurcharge: decimal("0"),
                accessorialRevenue: decimal("-1"),
                loadedMiles: decimal("0"),
                deadheadMiles: decimal("0"),
                estimatedTolls: decimal("-10"),
                operatingCosts: OperatingCostInputs(
                    fuelEconomyMilesPerGallon: decimal("0"),
                    fuelPricePerGallon: decimal("-4"),
                    maintenanceReservePerMile: decimal("-0.10"),
                    monthlyFixedCosts: decimal("-100"),
                    workingMilesPerMonth: decimal("0")
                ),
                fees: [
                    .flat(name: "Admin", amount: decimal("-1")),
                    .percentage(name: "Dispatch", rate: decimal("-0.10")),
                    .percentage(name: "Broker", rate: decimal("1.10"))
                ]
            )
        )

        XCTAssertEqual(
            result.inputIssues,
            [
                ProfitabilityInputIssue(
                    field: .lineHaulRate,
                    reason: .mustBeGreaterThanZero
                ),
                ProfitabilityInputIssue(
                    field: .accessorialRevenue,
                    reason: .cannotBeNegative
                ),
                ProfitabilityInputIssue(
                    field: .loadedMiles,
                    reason: .mustBeGreaterThanZero
                ),
                ProfitabilityInputIssue(
                    field: .totalMiles,
                    reason: .mustBeGreaterThanZero
                ),
                ProfitabilityInputIssue(
                    field: .estimatedTolls,
                    reason: .cannotBeNegative
                ),
                ProfitabilityInputIssue(
                    field: .fuelEconomyMilesPerGallon,
                    reason: .mustBeGreaterThanZero
                ),
                ProfitabilityInputIssue(
                    field: .fuelPricePerGallon,
                    reason: .cannotBeNegative
                ),
                ProfitabilityInputIssue(
                    field: .maintenanceReservePerMile,
                    reason: .cannotBeNegative
                ),
                ProfitabilityInputIssue(
                    field: .monthlyFixedCosts,
                    reason: .cannotBeNegative
                ),
                ProfitabilityInputIssue(
                    field: .workingMilesPerMonth,
                    reason: .mustBeGreaterThanZero
                ),
                ProfitabilityInputIssue(
                    field: .fee(index: 0),
                    reason: .cannotBeNegative
                ),
                ProfitabilityInputIssue(
                    field: .fee(index: 1),
                    reason: .cannotBeNegative
                ),
                ProfitabilityInputIssue(
                    field: .fee(index: 2),
                    reason: .mustBeBetweenZeroAndOne
                )
            ]
        )
    }

    func testRoundingUsesMoneyAndRatioScales() throws {
        let result = ProfitabilityCalculator.calculate(
            ProfitabilityInput(
                lineHaulRate: decimal("100"),
                fuelSurcharge: decimal("0"),
                loadedMiles: decimal("3"),
                deadheadMiles: decimal("0"),
                operatingCosts: OperatingCostInputs(
                    fuelEconomyMilesPerGallon: decimal("9"),
                    fuelPricePerGallon: decimal("4"),
                    maintenanceReservePerMile: decimal("0"),
                    monthlyFixedCosts: decimal("1"),
                    workingMilesPerMonth: decimal("3")
                )
            )
        )

        let estimate = try XCTUnwrap(result.readyEstimate)

        XCTAssertEqual(estimate.inputs.fixedCostPerMile, decimal("0.3333"))
        XCTAssertEqual(estimate.fuelCost, decimal("1.33"))
        XCTAssertEqual(estimate.fixedCostAllocation, decimal("1.00"))
        XCTAssertEqual(estimate.estimatedProfit, decimal("97.67"))
        XCTAssertEqual(estimate.margin, decimal("0.9767"))
        XCTAssertEqual(estimate.revenuePerLoadedMile, decimal("33.33"))
        XCTAssertEqual(estimate.revenuePerTotalMile, decimal("33.33"))
    }

    func testLoadOverridesDoNotMutateSavedCostDefaults() throws {
        let defaults = TruckCostDefaults(
            fuelEconomyMilesPerGallon: decimal("6"),
            fuelPricePerGallon: decimal("3.50"),
            maintenanceReservePerMile: decimal("0.20"),
            monthlyFixedCosts: decimal("2000"),
            workingMilesPerMonth: decimal("4000")
        )
        let overrides = LoadCostOverrides(
            fuelPricePerGallon: decimal("4.00"),
            maintenanceReservePerMile: decimal("0.25")
        )

        let result = ProfitabilityCalculator.calculate(
            ProfitabilityInput(
                lineHaulRate: decimal("1000"),
                fuelSurcharge: decimal("0"),
                loadedMiles: decimal("100"),
                deadheadMiles: decimal("20"),
                operatingCosts: defaults.operatingCosts(applying: overrides)
            )
        )

        let estimate = try XCTUnwrap(result.readyEstimate)

        XCTAssertEqual(defaults.fuelPricePerGallon, decimal("3.50"))
        XCTAssertEqual(defaults.maintenanceReservePerMile, decimal("0.20"))
        XCTAssertEqual(estimate.inputs.fuelPricePerGallon, decimal("4.00"))
        XCTAssertEqual(estimate.inputs.maintenanceReservePerMile, decimal("0.25"))
        XCTAssertEqual(estimate.fuelCost, decimal("80.00"))
        XCTAssertEqual(estimate.maintenanceCost, decimal("30.00"))
    }
}

private extension ProfitabilityCalculation {
    var readyEstimate: ProfitabilityEstimate? {
        guard case .ready(let estimate) = self else { return nil }
        return estimate
    }

    var inputIssues: [ProfitabilityInputIssue] {
        guard case .invalid(let issues) = self else { return [] }
        return issues
    }
}

private func decimal(_ value: String) -> Decimal {
    Decimal(string: value)!
}

private let noFixedCostInputs = OperatingCostInputs(
    fuelEconomyMilesPerGallon: decimal("10"),
    fuelPricePerGallon: decimal("4"),
    maintenanceReservePerMile: decimal("0"),
    monthlyFixedCosts: decimal("0"),
    workingMilesPerMonth: decimal("1000")
)
