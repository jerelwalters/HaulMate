//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct NewLoadView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: NewLoadDraft
    @State private var rateConfirmationAttachment: RateConfirmationAttachment?
    @State private var savedLoad: SavedLoadEvaluation?
    @State private var importFailureMessage: String?

    init(draft: NewLoadDraft = NewLoadDraft()) {
        _draft = State(initialValue: draft)
    }

    private var estimate: ProfitabilityEstimate? {
        draft.readyEstimate
    }

    private var inputIssues: [ProfitabilityInputIssue] {
        draft.inputIssues
    }

    private var saveValidationErrors: [NewLoadValidationError] {
        draft.saveValidationErrors
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HMSpacing.lg) {
                    header
                    routeCard
                    rateConfirmationCard
                    revenueAndMilesCard
                    feesCard
                    overridesCard
                    resultCard
                    saveCard
                }
                .padding(.horizontal, HMSpacing.lg)
                .padding(.vertical, HMSpacing.xl)
            }
            .hmAppBackground()
            .navigationTitle(NewLoadStrings.navigationTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NewLoadStrings.closeButton.localized, action: dismiss.callAsFunction)
                }
            }
            .tint(HMColor.accent)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HMSpacing.xs) {
            Text(NewLoadStrings.screenTitle.localized)
                .font(HMFont.screenTitle)
                .foregroundStyle(HMColor.textPrimary)

            Text(NewLoadStrings.screenSubtitle.localized)
                .font(HMFont.body)
                .foregroundStyle(HMColor.textSecondary)
        }
    }

    private var routeCard: some View {
        card(title: NewLoadStrings.routeSectionTitle.localized) {
            VStack(spacing: 0) {
                textInputRow(
                    label: NewLoadStrings.brokerCustomerLabel.localized,
                    text: $draft.brokerCustomer,
                    placeholder: NewLoadStrings.brokerCustomerPlaceholder.localized,
                    keyboardType: .default
                )

                divider

                textInputRow(
                    label: NewLoadStrings.referenceNumberLabel.localized,
                    text: $draft.referenceNumber,
                    placeholder: NewLoadStrings.referenceNumberPlaceholder.localized,
                    keyboardType: .default
                )

                divider

                textInputRow(
                    label: NewLoadStrings.pickupLabel.localized,
                    text: $draft.pickupLocation,
                    placeholder: NewLoadStrings.pickupPlaceholder.localized,
                    keyboardType: .default
                )

                divider

                textInputRow(
                    label: NewLoadStrings.deliveryLabel.localized,
                    text: $draft.deliveryLocation,
                    placeholder: NewLoadStrings.deliveryPlaceholder.localized,
                    keyboardType: .default
                )
            }
        }
    }

    private var rateConfirmationCard: some View {
        card(title: NewLoadStrings.rateConfirmationTitle.localized) {
            VStack(alignment: .leading, spacing: HMSpacing.md) {
                if let rateConfirmationAttachment {
                    HStack(spacing: HMSpacing.md) {
                        Image(systemName: rateConfirmationAttachment.kind == .pdf ? "doc.richtext" : "photo")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(HMColor.link)
                            .frame(width: 40, height: 40)
                            .background(HMColor.surfaceMuted, in: RoundedRectangle(cornerRadius: HMRadius.medium))

                        VStack(alignment: .leading, spacing: HMSpacing.xs) {
                            Text(rateConfirmationAttachment.fileName)
                                .font(HMFont.cardTitle)
                                .foregroundStyle(HMColor.textPrimary)
                            Text(rateConfirmationAttachment.localizedKind)
                                .font(HMFont.caption)
                                .foregroundStyle(HMColor.textSecondary)
                        }

                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                } else {
                    Text(NewLoadStrings.noRateConfirmationAttached.localized)
                        .font(HMFont.body)
                        .foregroundStyle(HMColor.textSecondary)
                }

                if let importFailureMessage {
                    Label(importFailureMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(HMFont.caption)
                        .foregroundStyle(HMColor.warning)
                }

                AttachmentImportButton(
                    onPicked: { url in
                        importFailureMessage = nil
                        rateConfirmationAttachment = RateConfirmationAttachment(url: url)
                    },
                    onFailure: {
                        importFailureMessage = NewLoadStrings.attachmentImportFailure.localized
                    }
                ) {
                    Label(
                        rateConfirmationAttachment == nil
                            ? NewLoadStrings.attachRateConfirmationButton.localized
                            : NewLoadStrings.replaceRateConfirmationButton.localized,
                        systemImage: "paperclip"
                    )
                }
                .buttonStyle(HMPrimaryButtonStyle(kind: .navy))
                .accessibilityIdentifier("new-load.attach-rate-confirmation")
            }
        }
    }

    private var revenueAndMilesCard: some View {
        card(title: NewLoadStrings.revenueSectionTitle.localized) {
            VStack(spacing: 0) {
                textInputRow(
                    label: NewLoadStrings.lineHaulRateLabel.localized,
                    text: $draft.lineHaulRate,
                    placeholder: "1850",
                    prefix: "$"
                )

                divider

                textInputRow(
                    label: NewLoadStrings.fuelSurchargeLabel.localized,
                    text: $draft.fuelSurcharge,
                    placeholder: "0",
                    prefix: "$"
                )

                divider

                textInputRow(
                    label: NewLoadStrings.accessorialRevenueLabel.localized,
                    text: $draft.accessorialRevenue,
                    placeholder: "0",
                    prefix: "$"
                )

                divider

                textInputRow(
                    label: NewLoadStrings.loadedMilesLabel.localized,
                    text: $draft.loadedMiles,
                    placeholder: "540",
                    suffix: NewLoadStrings.milesSuffix.localized
                )

                divider

                textInputRow(
                    label: NewLoadStrings.deadheadMilesLabel.localized,
                    text: $draft.deadheadMiles,
                    placeholder: "0",
                    suffix: NewLoadStrings.milesSuffix.localized
                )

                divider

                textInputRow(
                    label: NewLoadStrings.estimatedTollsLabel.localized,
                    text: $draft.estimatedTolls,
                    placeholder: "0",
                    prefix: "$"
                )
            }
        }
    }

    private var feesCard: some View {
        card(title: NewLoadStrings.feesSectionTitle.localized) {
            VStack(spacing: 0) {
                textInputRow(
                    label: NewLoadStrings.dispatchFeeLabel.localized,
                    text: $draft.dispatchFeePercent,
                    placeholder: "5",
                    suffix: "%"
                )

                divider

                textInputRow(
                    label: NewLoadStrings.factoringFeeLabel.localized,
                    text: $draft.factoringFeePercent,
                    placeholder: "3",
                    suffix: "%"
                )

                divider

                textInputRow(
                    label: NewLoadStrings.otherFlatFeeLabel.localized,
                    text: $draft.otherFlatFee,
                    placeholder: "0",
                    prefix: "$"
                )
            }
        }
    }

    private var overridesCard: some View {
        card(title: NewLoadStrings.overridesSectionTitle.localized) {
            VStack(alignment: .leading, spacing: HMSpacing.md) {
                Text(NewLoadStrings.overridesSectionSubtitle.localized)
                    .font(HMFont.caption)
                    .foregroundStyle(HMColor.textSecondary)

                VStack(spacing: 0) {
                    textInputRow(
                        label: NewLoadStrings.fuelEconomyOverrideLabel.localized,
                        text: $draft.overrideFuelEconomyMPG,
                        placeholder: draft.truckProfile.fuelEconomyMPG,
                        suffix: TruckCostProfileStrings.mpgSuffix.localized
                    )

                    divider

                    textInputRow(
                        label: NewLoadStrings.fuelPriceOverrideLabel.localized,
                        text: $draft.overrideFuelPricePerGallon,
                        placeholder: draft.truckProfile.fuelPricePerGallon,
                        prefix: "$",
                        suffix: TruckCostProfileStrings.perGallonSuffix.localized
                    )

                    divider

                    textInputRow(
                        label: NewLoadStrings.maintenanceOverrideLabel.localized,
                        text: $draft.overrideMaintenanceReservePerMile,
                        placeholder: draft.truckProfile.maintenanceReservePerMile,
                        prefix: "$",
                        suffix: TruckCostProfileStrings.perMileSuffix.localized
                    )

                    divider

                    textInputRow(
                        label: NewLoadStrings.monthlyFixedCostsOverrideLabel.localized,
                        text: $draft.overrideMonthlyFixedCosts,
                        placeholder: draft.truckProfile.monthlyFixedCosts,
                        prefix: "$"
                    )

                    divider

                    textInputRow(
                        label: NewLoadStrings.workingMilesOverrideLabel.localized,
                        text: $draft.overrideWorkingMiles,
                        placeholder: draft.truckProfile.estimatedWorkingMiles,
                        suffix: TruckCostProfileStrings.perMonthSuffix.localized
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        if let estimate {
            VStack(alignment: .leading, spacing: HMSpacing.lg) {
                Text(NewLoadStrings.resultsSectionTitle.localized)
                    .font(HMFont.eyebrow)
                    .foregroundStyle(.white.opacity(0.68))

                VStack(alignment: .leading, spacing: HMSpacing.xs) {
                    Text(currency(estimate.estimatedProfit, fractionDigits: 0))
                        .font(.system(.largeTitle, design: .default, weight: .heavy))
                        .foregroundStyle(estimate.estimatedProfit >= 0 ? HMColor.success : HMColor.danger)
                        .contentTransition(.numericText())

                    Text(NewLoadStrings.estimatedProfitLabel.localized)
                        .font(HMFont.caption)
                        .foregroundStyle(.white.opacity(0.74))
                }

                HStack(spacing: HMSpacing.lg) {
                    metric(
                        label: NewLoadStrings.grossRevenueLabel.localized,
                        value: currency(estimate.grossRevenue, fractionDigits: 0)
                    )
                    metric(
                        label: NewLoadStrings.operatingCostLabel.localized,
                        value: currency(estimate.totalOperatingCost, fractionDigits: 0)
                    )
                    metric(
                        label: NewLoadStrings.marginLabel.localized,
                        value: percent(estimate.margin)
                    )
                }

                VStack(spacing: 0) {
                    resultRow(
                        label: NewLoadStrings.revenuePerLoadedMileLabel.localized,
                        value: currency(estimate.revenuePerLoadedMile, fractionDigits: 2)
                    )
                    resultDivider
                    resultRow(
                        label: NewLoadStrings.revenuePerTotalMileLabel.localized,
                        value: currency(estimate.revenuePerTotalMile, fractionDigits: 2)
                    )
                    resultDivider
                    resultRow(
                        label: NewLoadStrings.loadedMilesSummaryLabel.localized,
                        value: number(estimate.inputs.loadedMiles, fractionDigits: 0)
                    )
                    resultDivider
                    resultRow(
                        label: NewLoadStrings.deadheadMilesSummaryLabel.localized,
                        value: number(estimate.inputs.deadheadMiles, fractionDigits: 0)
                    )
                    resultDivider
                    resultRow(
                        label: NewLoadStrings.totalMilesSummaryLabel.localized,
                        value: number(estimate.inputs.totalMiles, fractionDigits: 0)
                    )
                }
                .padding(HMSpacing.md)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: HMRadius.medium))
            }
            .padding(HMSpacing.xl)
            .background(HMColor.brandNavy, in: RoundedRectangle(cornerRadius: HMRadius.large))
            .accessibilityIdentifier("new-load.profitability-results")
        } else {
            missingInputsCard
        }
    }

    private var missingInputsCard: some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            Label(NewLoadStrings.missingInputsTitle.localized, systemImage: "exclamationmark.triangle.fill")
                .font(HMFont.cardTitle)
                .foregroundStyle(HMColor.warning)

            VStack(alignment: .leading, spacing: HMSpacing.sm) {
                ForEach(Array(inputIssues.enumerated()), id: \.offset) { _, issue in
                    Text(message(for: issue))
                        .font(HMFont.caption)
                        .foregroundStyle(HMColor.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HMSpacing.lg)
        .hmCard(backgroundColor: HMColor.warningSurface)
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            Text(NewLoadStrings.saveStatusLabel.localized)
                .font(HMFont.sectionTitle)
                .foregroundStyle(HMColor.textPrimary)

            Picker(NewLoadStrings.saveStatusLabel.localized, selection: $draft.status) {
                ForEach(NewLoadSaveStatus.allCases) { status in
                    Text(status.localizedTitle).tag(status)
                }
            }
            .pickerStyle(.segmented)

            if !saveValidationErrors.isEmpty {
                VStack(alignment: .leading, spacing: HMSpacing.sm) {
                    ForEach(saveValidationErrors) { error in
                        Text(error.message)
                            .font(HMFont.caption)
                            .foregroundStyle(HMColor.textPrimary)
                    }
                }
                .padding(HMSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HMColor.warningSurface, in: RoundedRectangle(cornerRadius: HMRadius.medium))
            }

            Button(NewLoadStrings.saveLoadButton.localized, action: saveLoad)
                .buttonStyle(HMPrimaryButtonStyle(kind: .accent))
                .disabled(!draft.canSave)
                .accessibilityIdentifier("new-load.save")

            if let savedLoad {
                Label(
                    NewLoadStrings.savedStatusFormat.localized(savedLoad.draft.status.localizedTitle),
                    systemImage: "checkmark.circle.fill"
                )
                .font(HMFont.caption)
                .foregroundStyle(HMColor.success)
            }
        }
        .padding(HMSpacing.lg)
        .hmCard()
    }

    private var divider: some View {
        Divider()
            .padding(.leading, HMSpacing.lg)
    }

    private var resultDivider: some View {
        Divider()
            .overlay(.white.opacity(0.18))
    }

    private func card<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            Text(title)
                .font(HMFont.sectionTitle)
                .foregroundStyle(HMColor.textPrimary)

            content()
        }
        .padding(HMSpacing.lg)
        .hmCard()
    }

    private func textInputRow(
        label: String,
        text: Binding<String>,
        placeholder: String,
        prefix: String? = nil,
        suffix: String? = nil,
        keyboardType: UIKeyboardType = .decimalPad
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HMSpacing.md) {
            Text(label)
                .font(HMFont.body)
                .foregroundStyle(HMColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: HMSpacing.xs) {
                if let prefix {
                    Text(prefix)
                        .foregroundStyle(HMColor.textSecondary)
                }

                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .default ? .words : .never)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(HMColor.textPrimary)
                    .frame(minWidth: 72)
                    .accessibilityLabel(label)

                if let suffix {
                    Text(suffix)
                        .foregroundStyle(HMColor.textSecondary)
                        .fixedSize()
                }
            }
            .font(HMFont.cardTitle)
        }
        .padding(.vertical, HMSpacing.md)
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: HMSpacing.xs) {
            Text(label)
                .font(HMFont.eyebrow)
                .foregroundStyle(.white.opacity(0.68))
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(HMFont.caption)
                .foregroundStyle(.white.opacity(0.72))

            Spacer()

            Text(value)
                .font(HMFont.cardTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, HMSpacing.sm)
    }

    private func saveLoad() {
        savedLoad = draft.saveSnapshot(attachment: rateConfirmationAttachment)
    }

    private func message(for issue: ProfitabilityInputIssue) -> String {
        switch issue.field {
        case .lineHaulRate:
            return NewLoadStrings.lineHaulInvalid.localized
        case .fuelSurcharge:
            return NewLoadStrings.fuelSurchargeInvalid.localized
        case .accessorialRevenue:
            return NewLoadStrings.accessorialRevenueInvalid.localized
        case .loadedMiles:
            return NewLoadStrings.loadedMilesInvalid.localized
        case .deadheadMiles:
            return NewLoadStrings.deadheadMilesInvalid.localized
        case .totalMiles:
            return NewLoadStrings.totalMilesInvalid.localized
        case .fuelEconomyMilesPerGallon:
            return NewLoadStrings.fuelEconomyInvalid.localized
        case .fuelPricePerGallon:
            return NewLoadStrings.fuelPriceInvalid.localized
        case .maintenanceReservePerMile:
            return NewLoadStrings.maintenanceReserveInvalid.localized
        case .monthlyFixedCosts:
            return NewLoadStrings.monthlyFixedCostsInvalid.localized
        case .workingMilesPerMonth:
            return NewLoadStrings.workingMilesInvalid.localized
        case .estimatedTolls:
            return NewLoadStrings.estimatedTollsInvalid.localized
        case .fee(_):
            return NewLoadStrings.feeInvalid.localized
        }
    }

    private func currency(_ amount: Decimal, fractionDigits: Int) -> String {
        amount.formatted(
            .currency(code: "USD")
            .precision(.fractionLength(fractionDigits))
        )
    }

    private func number(_ amount: Decimal, fractionDigits: Int) -> String {
        amount.formatted(
            .number
                .precision(.fractionLength(fractionDigits))
                .grouping(.automatic)
        )
    }

    private func percent(_ amount: Decimal) -> String {
        (amount * 100).formatted(
            .number
                .precision(.fractionLength(1))
                .grouping(.automatic)
        ) + "%"
    }
}

#if DEBUG
#Preview {
    NewLoadView(draft: .preview)
}

#Preview("Missing Inputs") {
    NewLoadView()
}

#Preview("Dark") {
    NewLoadView(draft: .preview)
        .preferredColorScheme(.dark)
}

private extension NewLoadDraft {
    static var preview: NewLoadDraft {
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
}
#endif
