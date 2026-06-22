//
//  Created by Jerel Walters on 6/21/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation
import SwiftUI

struct TruckCostProfileView: View {
    @State private var draft: TruckCostProfileDraft
    // Local-only confirmation until MOB-03 gets repository-backed profile persistence.
    @State private var savedDraft: TruckCostProfileDraft?

    init(draft: TruckCostProfileDraft = .figmaBaseline) {
        _draft = State(initialValue: draft)
    }

    private var validationErrors: [TruckCostProfileValidationError] {
        draft.validationErrors
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HMSpacing.lg) {
                header
                operatingProfileCard
                derivedFixedCostCard
                defaultFeesCard

                if !validationErrors.isEmpty {
                    missingInputsCard
                }

                saveButton
                footer
            }
            .padding(.horizontal, HMSpacing.lg)
            .padding(.vertical, HMSpacing.xl)
        }
        .hmAppBackground()
        .navigationTitle(TruckCostProfileStrings.navigationTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
        .tint(HMColor.accent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HMSpacing.xs) {
            Text(TruckCostProfileStrings.screenTitle.localized)
                .font(HMFont.screenTitle)
                .foregroundStyle(HMColor.textPrimary)

            Text(TruckCostProfileStrings.screenSubtitle.localized)
                .font(HMFont.body)
                .foregroundStyle(HMColor.textSecondary)
        }
    }

    private var operatingProfileCard: some View {
        VStack(spacing: 0) {
            textInputRow(
                label: TruckCostProfileStrings.equipmentLabel.localized,
                text: $draft.equipmentName,
                placeholder: TruckCostProfileStrings.equipmentPlaceholder.localized,
                suffix: nil,
                keyboardType: .default
            )

            divider

            textInputRow(
                label: TruckCostProfileStrings.fuelEconomyLabel.localized,
                text: $draft.fuelEconomyMPG,
                placeholder: "6.7",
                suffix: TruckCostProfileStrings.mpgSuffix.localized
            )

            divider

            textInputRow(
                label: TruckCostProfileStrings.fuelPriceLabel.localized,
                text: $draft.fuelPricePerGallon,
                placeholder: "3.64",
                prefix: "$",
                suffix: TruckCostProfileStrings.perGallonSuffix.localized
            )

            divider

            textInputRow(
                label: TruckCostProfileStrings.maintenanceReserveLabel.localized,
                text: $draft.maintenanceReservePerMile,
                placeholder: "0.35",
                prefix: "$",
                suffix: TruckCostProfileStrings.perMileSuffix.localized
            )

            divider

            textInputRow(
                label: TruckCostProfileStrings.monthlyFixedCostsLabel.localized,
                text: $draft.monthlyFixedCosts,
                placeholder: "8400",
                prefix: "$"
            )

            divider

            textInputRow(
                label: TruckCostProfileStrings.workingMilesLabel.localized,
                text: $draft.estimatedWorkingMiles,
                placeholder: "11350",
                suffix: TruckCostProfileStrings.perMonthSuffix.localized
            )
        }
        .padding(.horizontal, HMSpacing.lg)
        .padding(.vertical, HMSpacing.sm)
        .hmCard()
    }

    private var derivedFixedCostCard: some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            Text(TruckCostProfileStrings.derivedFixedCostLabel.localized)
                .font(HMFont.eyebrow)
                .foregroundStyle(.white.opacity(0.68))

            Text(derivedFixedCostText)
                .font(.system(.largeTitle, design: .default, weight: .heavy))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text(workingMilesSummaryText)
                .font(HMFont.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HMSpacing.xl)
        .background(HMColor.brandNavy, in: RoundedRectangle(cornerRadius: HMRadius.large))
        .accessibilityElement(children: .combine)
    }

    private var defaultFeesCard: some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            Text(TruckCostProfileStrings.defaultsSectionTitle.localized)
                .font(HMFont.sectionTitle)
                .foregroundStyle(HMColor.textPrimary)

            VStack(spacing: 0) {
                textInputRow(
                    label: TruckCostProfileStrings.dispatchFeeLabel.localized,
                    text: $draft.dispatchFeePercent,
                    placeholder: "5",
                    suffix: "%"
                )

                divider

                textInputRow(
                    label: TruckCostProfileStrings.factoringFeeLabel.localized,
                    text: $draft.factoringFeePercent,
                    placeholder: "3",
                    suffix: "%"
                )

                divider

                textInputRow(
                    label: TruckCostProfileStrings.profitTargetLabel.localized,
                    text: $draft.profitTargetPercent,
                    placeholder: "25",
                    suffix: "%"
                )
            }
        }
        .padding(HMSpacing.lg)
        .hmCard()
    }

    private var missingInputsCard: some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            Label(TruckCostProfileStrings.missingInputsTitle.localized, systemImage: "exclamationmark.triangle.fill")
                .font(HMFont.cardTitle)
                .foregroundStyle(HMColor.warning)

            VStack(alignment: .leading, spacing: HMSpacing.sm) {
                ForEach(validationErrors) { error in
                    Text(error.message)
                        .font(HMFont.caption)
                        .foregroundStyle(HMColor.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HMSpacing.lg)
        .hmCard(backgroundColor: HMColor.warningSurface)
    }

    private var saveButton: some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            Button(TruckCostProfileStrings.saveProfileButton.localized, action: saveProfile)
                .buttonStyle(HMPrimaryButtonStyle(kind: .accent))
                .disabled(!validationErrors.isEmpty)
                .accessibilityIdentifier("truck-cost-profile.save")

            if savedDraft != nil {
                Label(TruckCostProfileStrings.savedStatus.localized, systemImage: "checkmark.circle.fill")
                    .font(HMFont.caption)
                    .foregroundStyle(HMColor.success)
            }
        }
    }

    private var footer: some View {
        Text(TruckCostProfileStrings.footer.localized)
            .font(HMFont.eyebrow)
            .foregroundStyle(HMColor.textSecondary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, HMSpacing.sm)
    }

    private var divider: some View {
        Divider()
            .padding(.leading, HMSpacing.lg)
    }

    private var derivedFixedCostText: String {
        guard let fixedCost = draft.derivedFixedCostPerMile else {
            return TruckCostProfileStrings.missingCostValue.localized
        }

        return currency(fixedCost, fractionDigits: 2) + " " + TruckCostProfileStrings.perMileSuffix.localized
    }

    private var workingMilesSummaryText: String {
        guard let workingMiles = draft.decimalValue(for: .estimatedWorkingMiles), workingMiles > 0 else {
            return TruckCostProfileStrings.workingMilesMissingSummary.localized
        }

        return TruckCostProfileStrings.workingMilesSummaryFormat.localized(
            number(workingMiles, fractionDigits: 0)
        )
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

    private func saveProfile() {
        guard validationErrors.isEmpty else { return }
        savedDraft = draft.normalized
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
}

#if DEBUG
#Preview {
    NavigationStack {
        TruckCostProfileView()
    }
}

#Preview("Missing Inputs") {
    NavigationStack {
        TruckCostProfileView(draft: TruckCostProfileDraft())
    }
}

#Preview("Dark") {
    NavigationStack {
        TruckCostProfileView()
    }
    .preferredColorScheme(.dark)
}
#endif
