//
//  Created by Jerel Walters on 7/1/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct BusinessProfileView: View {
    @Environment(\.appDependencies) private var dependencies

    @State private var draft: BusinessProfileDraft
    @State private var hasLoadedProfile: Bool
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var hasAttemptedSave = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    private let loadProfileOnAppear: Bool

    private var authRepository: AuthRepository {
        dependencies.required.authRepository
    }

    private var validationErrors: [BusinessProfileValidationError] {
        draft.validationErrors
    }

    init(
        draft: BusinessProfileDraft = BusinessProfileDraft(),
        loadProfileOnAppear: Bool = true
    ) {
        self.loadProfileOnAppear = loadProfileOnAppear
        _draft = State(initialValue: draft)
        _hasLoadedProfile = State(initialValue: !loadProfileOnAppear)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HMSpacing.lg) {
                header

                if isLoading {
                    ProgressView(SettingsStrings.businessProfileLoading.localized)
                        .font(HMFont.body)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, HMSpacing.xxl)
                } else {
                    businessDetailsCard
                    invoiceDefaultsCard
                    remittanceCard
                    feedbackSection
                    saveButton
                }
            }
            .padding(.horizontal, HMSpacing.lg)
            .padding(.vertical, HMSpacing.xl)
        }
        .hmAppBackground()
        .navigationTitle(SettingsStrings.businessProfileLabel.localized)
        .navigationBarTitleDisplayMode(.inline)
        .tint(HMColor.accent)
        .task {
            await loadProfileIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HMSpacing.xs) {
            Text(SettingsStrings.businessProfileScreenTitle.localized)
                .font(HMFont.screenTitle)
                .foregroundStyle(HMColor.textPrimary)

            Text(SettingsStrings.businessProfileScreenSubtitle.localized)
                .font(HMFont.body)
                .foregroundStyle(HMColor.textSecondary)
        }
    }

    private var businessDetailsCard: some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            sectionHeader(SettingsStrings.businessDetailsSectionTitle.localized)

            labeledField(AuthenticationStrings.legalBusinessNameLabel.localized) {
                TextField(AuthenticationStrings.legalBusinessNamePlaceholder.localized, text: $draft.legalName)
                    .textContentType(.organizationName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("business-profile.legal-name")
            }

            labeledField(AuthenticationStrings.carrierDisplayNameLabel.localized) {
                TextField(AuthenticationStrings.carrierDisplayNamePlaceholder.localized, text: $draft.displayName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("business-profile.display-name")
            }

            labeledField(AuthenticationStrings.businessAddressLabel.localized) {
                TextField(AuthenticationStrings.addressPlaceholder.localized, text: $draft.mailingAddress, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("business-profile.address")
            }

            labeledField(AuthenticationStrings.businessPhoneLabel.localized) {
                TextField(AuthenticationStrings.phonePlaceholder.localized, text: $draft.phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("business-profile.phone")
            }
        }
        .padding(HMSpacing.lg)
        .hmCard()
    }

    private var invoiceDefaultsCard: some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            sectionHeader(SettingsStrings.invoiceDefaultsSectionTitle.localized)

            labeledField(AuthenticationStrings.businessEmailLabel.localized) {
                TextField(AuthenticationStrings.businessEmailPlaceholder.localized, text: $draft.invoiceEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("business-profile.invoice-email")
            }

            labeledField(AuthenticationStrings.invoicePrefixLabel.localized) {
                TextField(AuthenticationStrings.invoicePrefixPlaceholder.localized, text: $draft.invoicePrefix)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("business-profile.invoice-prefix")
            }

            paymentTermsControl

            labeledField(AuthenticationStrings.logoFieldLabel.localized) {
                TextField(AuthenticationStrings.logoPlaceholder.localized, text: $draft.logoFilename)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("business-profile.logo")
            }
        }
        .padding(HMSpacing.lg)
        .hmCard()
    }

    private var remittanceCard: some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            sectionHeader(SettingsStrings.remittanceSectionTitle.localized)

            Toggle(AuthenticationStrings.factoringToggle.localized, isOn: $draft.usesFactoring)
                .font(HMFont.cardTitle)
                .foregroundStyle(HMColor.textPrimary)
                .accessibilityIdentifier("business-profile.uses-factoring")

            if draft.usesFactoring {
                labeledField(AuthenticationStrings.factoringCompanyLabel.localized) {
                    TextField(AuthenticationStrings.factoringCompanyPlaceholder.localized, text: $draft.factoringCompanyName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("business-profile.factoring-company")
                }

                labeledField(AuthenticationStrings.factoringRemittanceLabel.localized) {
                    TextField(
                        AuthenticationStrings.factoringRemittancePlaceholder.localized,
                        text: $draft.factoringRemittanceDetails,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("business-profile.factoring-remittance")
                }
            }
        }
        .padding(HMSpacing.lg)
        .hmCard()
    }

    private var paymentTermsControl: some View {
        labeledField(AuthenticationStrings.paymentTermsLabel.localized) {
            HStack(spacing: HMSpacing.sm) {
                Text(AuthenticationStrings.netPaymentTermsFormat.localized(draft.paymentTermsDays))
                    .font(HMFont.body)
                    .foregroundStyle(HMColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: HMSpacing.xs)

                Stepper(
                    AuthenticationStrings.paymentTermsLabel.localized,
                    value: $draft.paymentTermsDays,
                    in: 1...120
                )
                .labelsHidden()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, HMSpacing.sm)
            .padding(.vertical, HMSpacing.xs)
            .background(HMColor.surfaceMuted, in: RoundedRectangle(cornerRadius: HMRadius.small))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AuthenticationStrings.paymentTermsLabel.localized)
            .accessibilityValue(AuthenticationStrings.netPaymentTermsFormat.localized(draft.paymentTermsDays))
            .accessibilityIdentifier("business-profile.payment-terms")
        }
    }

    @ViewBuilder
    private var feedbackSection: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(HMFont.caption)
                .foregroundStyle(HMColor.danger)
                .padding(HMSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HMColor.dangerSurface, in: RoundedRectangle(cornerRadius: HMRadius.medium))
                .accessibilityIdentifier("business-profile.error")
        } else if let statusMessage {
            Label(statusMessage, systemImage: "checkmark.circle.fill")
                .font(HMFont.caption)
                .foregroundStyle(HMColor.success)
                .padding(HMSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HMColor.successSurface, in: RoundedRectangle(cornerRadius: HMRadius.medium))
                .accessibilityIdentifier("business-profile.status")
        } else if hasAttemptedSave, !validationErrors.isEmpty {
            validationSummary
        }
    }

    private var validationSummary: some View {
        VStack(alignment: .leading, spacing: HMSpacing.sm) {
            Label(AuthenticationStrings.validationSummaryTitle.localized, systemImage: "exclamationmark.triangle.fill")
                .font(HMFont.cardTitle)
                .foregroundStyle(HMColor.danger)

            ForEach(validationErrors) { validationError in
                Text(validationError.message)
                    .font(HMFont.caption)
                    .foregroundStyle(HMColor.textPrimary)
            }
        }
        .padding(HMSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HMColor.dangerSurface, in: RoundedRectangle(cornerRadius: HMRadius.medium))
        .accessibilityIdentifier("business-profile.validation-summary")
    }

    private var saveButton: some View {
        Button(action: saveProfile) {
            if isSaving {
                ProgressView()
                    .tint(HMColor.brandNavy)
                    .accessibilityLabel(SettingsStrings.saveBusinessProfileButton.localized)
            } else {
                Text(SettingsStrings.saveBusinessProfileButton.localized)
            }
        }
        .buttonStyle(HMPrimaryButtonStyle(kind: .accent))
        .disabled(isSaving || isLoading)
        .accessibilityIdentifier("business-profile.save")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(HMFont.sectionTitle)
            .foregroundStyle(HMColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledField<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: HMSpacing.xs) {
            Text(label.uppercased())
                .font(HMFont.eyebrow)
                .foregroundStyle(HMColor.textSecondary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadProfileIfNeeded() async {
        guard loadProfileOnAppear, !hasLoadedProfile else { return }

        isLoading = true
        defer {
            isLoading = false
            hasLoadedProfile = true
        }

        switch await authRepository.loadBusinessProfile() {
        case .success(let profile):
            if let profile {
                draft = profile
            }
        case .failure(let error):
            errorMessage = error.localizedMessage
        }
    }

    private func saveProfile() {
        hasAttemptedSave = true
        errorMessage = nil
        statusMessage = nil

        guard validationErrors.isEmpty else { return }

        isSaving = true

        Task {
            let result = await authRepository.updateBusinessProfile(draft)
            isSaving = false

            switch result {
            case .success(let profile):
                if let profile {
                    draft = profile
                }
                hasAttemptedSave = false
                statusMessage = SettingsStrings.businessProfileSavedStatus.localized
            case .failure(let error):
                errorMessage = error.localizedMessage
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        BusinessProfileView(
            draft: .settingsPreview,
            loadProfileOnAppear: false
        )
    }
    .withPreviewDependencies(user: .preview)
}

private extension BusinessProfileDraft {
    static let settingsPreview = BusinessProfileDraft(
        legalName: "Walters Logistics LLC",
        displayName: "Walters Logistics",
        mailingAddress: "123 Pilot Way, Detroit, MI 48201",
        phone: "313-555-0148",
        invoiceEmail: "billing@example.com",
        invoicePrefix: "HM",
        paymentTermsDays: 30
    )
}
#endif
