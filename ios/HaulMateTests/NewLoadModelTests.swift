//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import HaulMate

final class NewLoadModelTests: XCTestCase {
    func testDraftCalculatesProfitabilityAndKeepsDeadheadVisible() throws {
        let draft = completeDraft()

        let estimate = try XCTUnwrap(draft.readyEstimate)

        XCTAssertEqual(estimate.grossRevenue, decimal("2075.00"))
        XCTAssertEqual(estimate.inputs.loadedMiles, decimal("540"))
        XCTAssertEqual(estimate.inputs.deadheadMiles, decimal("72"))
        XCTAssertEqual(estimate.inputs.totalMiles, decimal("612"))
        XCTAssertEqual(estimate.fuelCost, decimal("332.49"))
        XCTAssertEqual(estimate.maintenanceCost, decimal("214.20"))
        XCTAssertEqual(estimate.fixedCostAllocation, decimal("452.93"))
        XCTAssertEqual(estimate.feeCost, decimal("166.00"))
        XCTAssertEqual(estimate.totalOperatingCost, decimal("1245.62"))
        XCTAssertEqual(estimate.estimatedProfit, decimal("829.38"))
        XCTAssertEqual(estimate.revenuePerLoadedMile, decimal("3.84"))
        XCTAssertEqual(estimate.revenuePerTotalMile, decimal("3.39"))
    }

    func testPerLoadOverrideChangesCalculationWithoutMutatingTruckProfile() throws {
        var draft = completeDraft()
        let defaultFuelPrice = draft.truckProfile.fuelPricePerGallon
        let defaultFuelCost = try XCTUnwrap(draft.readyEstimate?.fuelCost)

        draft.overrideFuelPricePerGallon = "4.64"

        let overriddenEstimate = try XCTUnwrap(draft.readyEstimate)

        XCTAssertEqual(draft.truckProfile.fuelPricePerGallon, defaultFuelPrice)
        XCTAssertGreaterThan(overriddenEstimate.fuelCost, defaultFuelCost)
        XCTAssertEqual(overriddenEstimate.fuelCost, decimal("423.83"))
    }

    func testSaveSnapshotNormalizesFieldsAndPreservesRateConfirmationAttachment() throws {
        var draft = completeDraft()
        draft.brokerCustomer = "  Acme Logistics  "
        draft.referenceNumber = "  RC-4182  "
        draft.status = .accepted
        let attachment = RateConfirmationAttachment(fileName: "rate-confirmation.pdf", kind: .pdf)

        let savedLoad = try XCTUnwrap(draft.saveSnapshot(attachment: attachment))

        XCTAssertEqual(savedLoad.draft.brokerCustomer, "Acme Logistics")
        XCTAssertEqual(savedLoad.draft.referenceNumber, "RC-4182")
        XCTAssertEqual(savedLoad.draft.status, .accepted)
        XCTAssertEqual(savedLoad.attachment, attachment)
        XCTAssertEqual(savedLoad.estimate, try XCTUnwrap(draft.readyEstimate))
    }

    func testMissingRequiredLoadFactsBlockSaveBeforePersistence() {
        var draft = NewLoadDraft()
        draft.lineHaulRate = ""
        draft.loadedMiles = ""

        XCTAssertFalse(draft.canSave)
        XCTAssertNil(draft.saveSnapshot())
        XCTAssertEqual(
            draft.saveValidationErrors.map(\.field),
            [
                .brokerCustomer,
                .referenceNumber,
                .pickupLocation,
                .deliveryLocation
            ]
        )
        XCTAssertEqual(
            draft.inputIssues,
            [
                ProfitabilityInputIssue(field: .lineHaulRate, reason: .missing),
                ProfitabilityInputIssue(field: .loadedMiles, reason: .missing)
            ]
        )
    }

    private func completeDraft() -> NewLoadDraft {
        var draft = NewLoadDraft()
        draft.brokerCustomer = "Acme Logistics"
        draft.referenceNumber = "RC-4182"
        draft.pickupLocation = "Detroit, MI"
        draft.deliveryLocation = "Columbus, OH"
        draft.lineHaulRate = "1850"
        draft.fuelSurcharge = "150"
        draft.accessorialRevenue = "75"
        draft.loadedMiles = "540"
        draft.deadheadMiles = "72"
        draft.estimatedTolls = "80"
        return draft
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }
}
