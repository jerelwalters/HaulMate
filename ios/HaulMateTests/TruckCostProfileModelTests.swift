//
//  Created by Jerel Walters on 6/21/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import HaulMate

final class TruckCostProfileModelTests: XCTestCase {
    func testFigmaBaselineCalculatesDerivedFixedCostPerMile() {
        let draft = TruckCostProfileDraft.figmaBaseline

        XCTAssertTrue(draft.canSave)
        XCTAssertEqual(draft.derivedFixedCostPerMile, Decimal(string: "0.74"))
    }

    func testMissingInputsExplainEveryRequiredField() {
        let draft = TruckCostProfileDraft()

        XCTAssertFalse(draft.canSave)
        XCTAssertEqual(
            draft.validationErrors.map(\.field),
            [
                .equipment,
                .fuelEconomyMPG,
                .fuelPricePerGallon,
                .maintenanceReservePerMile,
                .monthlyFixedCosts,
                .estimatedWorkingMiles,
                .dispatchFeePercent,
                .factoringFeePercent,
                .profitTargetPercent
            ]
        )
        XCTAssertNil(draft.derivedFixedCostPerMile)
    }

    func testWorkingMilesMustBePositiveForDerivedFixedCost() {
        var draft = TruckCostProfileDraft.figmaBaseline
        draft.estimatedWorkingMiles = "0"

        XCTAssertFalse(draft.canSave)
        XCTAssertEqual(
            draft.validationErrors,
            [
                TruckCostProfileValidationError(
                    field: .estimatedWorkingMiles,
                    message: TruckCostProfileStrings.workingMilesInvalid.localized
                )
            ]
        )
        XCTAssertNil(draft.derivedFixedCostPerMile)
    }

    func testInvalidNegativePercentagesAreRejected() {
        var draft = TruckCostProfileDraft.figmaBaseline
        draft.dispatchFeePercent = "-1"
        draft.factoringFeePercent = "-0.5"
        draft.profitTargetPercent = "-10"

        XCTAssertFalse(draft.canSave)
        XCTAssertEqual(
            draft.validationErrors.map(\.field),
            [
                .dispatchFeePercent,
                .factoringFeePercent,
                .profitTargetPercent
            ]
        )
    }

    func testNormalizingProfileTrimsTextAndNumericGrouping() {
        var draft = TruckCostProfileDraft.figmaBaseline
        draft.equipmentName = "  Box truck  "
        draft.monthlyFixedCosts = "8,400"
        draft.estimatedWorkingMiles = "11,350"

        let normalized = draft.normalized

        XCTAssertEqual(normalized.equipmentName, "Box truck")
        XCTAssertEqual(normalized.monthlyFixedCosts, "8400")
        XCTAssertEqual(normalized.estimatedWorkingMiles, "11350")
        XCTAssertEqual(normalized.derivedFixedCostPerMile, Decimal(string: "0.74"))
    }
}
