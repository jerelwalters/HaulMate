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
