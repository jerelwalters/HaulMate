//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct AuthenticationView: View {
    @Environment(\.appDependencies) private var dependencies

    @State private var mode: AuthenticationMode = .signIn
    @State private var credentials = AuthenticationCredentials()
    @State private var businessProfile = BusinessProfileDraft()
    @State private var onboardingStep: AccountOnboardingStep = .invoiceIdentity
    @State private var hasAttemptedSubmit = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    private var authRepository: AuthRepository {
        dependencies.required.authRepository
    }

    init(mode: AuthenticationMode = .signIn) {
        _mode = State(initialValue: mode)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HMColor.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: HMSpacing.lg) {
                        header
                        modePicker
                        accountSection

                        if mode == .createAccount {
                            switch onboardingStep {
                            case .invoiceIdentity:
                                invoiceIdentitySection
                            case .businessDetails:
                                businessDetailsSection
                            }
                        }

                        feedbackSection
                        actionSection
                    }
                    .padding(.horizontal, HMSpacing.lg)
                    .padding(.vertical, HMSpacing.xl)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: mode) {
                clearFeedback()
                hasAttemptedSubmit = false
                onboardingStep = .invoiceIdentity
            }
        }
        .tint(HMColor.accent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HMSpacing.lg) {
            Image(systemName: "truck.box.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(HMColor.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: HMSpacing.xs) {
                Text(AppStrings.appName.localized)
                    .font(HMFont.screenTitle)
                    .foregroundStyle(HMColor.textPrimary)
                Text(AuthenticationStrings.headerMessage.localized)
                    .font(HMFont.body)
                    .foregroundStyle(HMColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, HMSpacing.sm)
    }

    private var modePicker: some View {
        Picker(AuthenticationStrings.modePickerTitle.localized, selection: $mode) {
            ForEach(AuthenticationMode.allCases) { mode in
                Text(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("authentication.mode")
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            sectionHeader(
                title: AuthenticationStrings.accountSectionTitle.localized,
                subtitle: mode == .signIn
                    ? AuthenticationStrings.signInAccountSectionSubtitle.localized
                    : AuthenticationStrings.createAccountSectionSubtitle.localized
            )

            TextField(AuthenticationStrings.emailPlaceholder.localized, text: $credentials.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("authentication.email")

            SecureField(AuthenticationStrings.passwordPlaceholder.localized, text: $credentials.password)
                .textContentType(mode == .signIn ? .password : .newPassword)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("authentication.password")
        }
        .padding(HMSpacing.lg)
        .hmCard()
    }

    private var invoiceIdentitySection: some View {
        VStack(alignment: .leading, spacing: HMSpacing.lg) {
            VStack(alignment: .leading, spacing: HMSpacing.xs) {
                Text(AuthenticationStrings.businessSetupTitle.localized)
                    .font(HMFont.sectionTitle)
                    .foregroundStyle(HMColor.textPrimary)

                Text(AuthenticationStrings.invoiceIdentityTitle.localized)
                    .font(HMFont.cardTitle)
                    .foregroundStyle(HMColor.textPrimary)

                Text(AuthenticationStrings.invoiceIdentitySubtitle.localized)
                    .font(HMFont.caption)
                    .foregroundStyle(HMColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: HMSpacing.md) {
                labeledField(AuthenticationStrings.legalBusinessNameLabel.localized) {
                    TextField(AuthenticationStrings.legalBusinessNamePlaceholder.localized, text: $businessProfile.legalName)
                        .textContentType(.organizationName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("onboarding.legal-name")
                }

                labeledField(AuthenticationStrings.carrierDisplayNameLabel.localized) {
                    TextField(AuthenticationStrings.carrierDisplayNamePlaceholder.localized, text: $businessProfile.displayName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("onboarding.display-name")
                }

                labeledField(AuthenticationStrings.businessEmailLabel.localized) {
                    TextField(AuthenticationStrings.businessEmailPlaceholder.localized, text: $businessProfile.invoiceEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("onboarding.invoice-email")
                }

                VStack(alignment: .leading, spacing: HMSpacing.md) {
                    labeledField(AuthenticationStrings.invoicePrefixLabel.localized) {
                        TextField(AuthenticationStrings.invoicePrefixPlaceholder.localized, text: $businessProfile.invoicePrefix)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("onboarding.invoice-prefix")
                    }

                    paymentTermsControl
                }

                statusStrip(AuthenticationStrings.profileCachedStatus.localized)

                Text(AuthenticationStrings.nextBusinessDetailsMessage.localized)
                    .font(HMFont.caption)
                    .foregroundStyle(HMColor.textSecondary)

                Text(AuthenticationStrings.businessSetupFooter.localized)
                    .font(HMFont.eyebrow)
                    .foregroundStyle(HMColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, HMSpacing.xs)
            }
        }
        .padding(HMSpacing.lg)
        .hmCard()
    }

    private var businessDetailsSection: some View {
        VStack(alignment: .leading, spacing: HMSpacing.md) {
            sectionHeader(
                title: AuthenticationStrings.businessDetailsTitle.localized,
                subtitle: AuthenticationStrings.businessDetailsSubtitle.localized
            )

            labeledField(AuthenticationStrings.businessAddressLabel.localized) {
                TextField(AuthenticationStrings.addressPlaceholder.localized, text: $businessProfile.mailingAddress, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("onboarding.address")
            }

            labeledField(AuthenticationStrings.businessPhoneLabel.localized) {
                TextField(AuthenticationStrings.phonePlaceholder.localized, text: $businessProfile.phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.phone")
            }

            labeledField(AuthenticationStrings.logoFieldLabel.localized) {
                TextField(AuthenticationStrings.logoPlaceholder.localized, text: $businessProfile.logoFilename)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.logo")
            }

            Toggle(AuthenticationStrings.factoringToggle.localized, isOn: $businessProfile.usesFactoring)
                .font(HMFont.cardTitle)
                .foregroundStyle(HMColor.textPrimary)
                .accessibilityIdentifier("onboarding.uses-factoring")

            if businessProfile.usesFactoring {
                labeledField(AuthenticationStrings.factoringCompanyLabel.localized) {
                    TextField(AuthenticationStrings.factoringCompanyPlaceholder.localized, text: $businessProfile.factoringCompanyName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("onboarding.factoring-company")
                }

                labeledField(AuthenticationStrings.factoringRemittanceLabel.localized) {
                    TextField(
                        AuthenticationStrings.factoringRemittancePlaceholder.localized,
                        text: $businessProfile.factoringRemittanceDetails,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("onboarding.factoring-remittance")
                }
            }
        }
        .padding(HMSpacing.lg)
        .hmCard()
    }

    private var paymentTermsControl: some View {
        labeledField(AuthenticationStrings.paymentTermsLabel.localized) {
            HStack(spacing: HMSpacing.sm) {
                Text(AuthenticationStrings.netPaymentTermsFormat.localized(businessProfile.paymentTermsDays))
                    .font(HMFont.body)
                    .foregroundStyle(HMColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: HMSpacing.xs)

                Stepper(
                    AuthenticationStrings.paymentTermsLabel.localized,
                    value: $businessProfile.paymentTermsDays,
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
            .accessibilityValue(AuthenticationStrings.netPaymentTermsFormat.localized(businessProfile.paymentTermsDays))
            .accessibilityIdentifier("onboarding.payment-terms")
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
                .accessibilityIdentifier("authentication.error")
        } else if let statusMessage {
            Label(statusMessage, systemImage: "checkmark.circle.fill")
                .font(HMFont.caption)
                .foregroundStyle(HMColor.success)
                .padding(HMSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HMColor.successSurface, in: RoundedRectangle(cornerRadius: HMRadius.medium))
                .accessibilityIdentifier("authentication.status")
        } else if hasAttemptedSubmit,
                  mode == .createAccount,
                  !displayedValidationErrors.isEmpty {
            validationSummary
        }
    }

    private var validationSummary: some View {
        VStack(alignment: .leading, spacing: HMSpacing.sm) {
            Label(AuthenticationStrings.validationSummaryTitle.localized, systemImage: "exclamationmark.triangle.fill")
                .font(HMFont.cardTitle)
                .foregroundStyle(HMColor.danger)

            ForEach(displayedValidationErrors) { validationError in
                Text(validationError.message)
                    .font(HMFont.caption)
                    .foregroundStyle(HMColor.textPrimary)
            }
        }
        .padding(HMSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HMColor.dangerSurface, in: RoundedRectangle(cornerRadius: HMRadius.medium))
        .accessibilityIdentifier("onboarding.validation-summary")
    }

    private var actionSection: some View {
        VStack(spacing: HMSpacing.md) {
            Button(action: submit) {
                if isSubmitting {
                    ProgressView()
                        .tint(mode == .createAccount ? HMColor.brandNavy : .white)
                        .accessibilityLabel(AuthenticationStrings.submittingAccessibilityLabel.localized)
                } else {
                    Text(primaryActionTitle)
                }
            }
            .buttonStyle(HMPrimaryButtonStyle(kind: mode == .createAccount ? .accent : .navy))
            .disabled(isSubmitting)
            .accessibilityIdentifier("authentication.submit")

            if mode == .createAccount,
               onboardingStep == .businessDetails {
                Button(AuthenticationStrings.backButton.localized) {
                    clearFeedback()
                    hasAttemptedSubmit = false
                    onboardingStep = .invoiceIdentity
                }
                .font(HMFont.caption)
                .foregroundStyle(HMColor.link)
                .disabled(isSubmitting)
                .accessibilityIdentifier("onboarding.back")
            }

            Button(AuthenticationStrings.forgotPasswordButton.localized, action: requestPasswordReset)
                .font(HMFont.caption)
                .foregroundStyle(HMColor.link)
                .disabled(isSubmitting)
                .accessibilityIdentifier("authentication.reset-password")
        }
    }

    private var primaryActionTitle: String {
        switch mode {
        case .signIn:
            return mode.title
        case .createAccount:
            switch onboardingStep {
            case .invoiceIdentity:
                return AuthenticationStrings.continueButton.localized
            case .businessDetails:
                return AuthenticationStrings.finishSetupButton.localized
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: HMSpacing.xs) {
            Text(title)
                .font(HMFont.sectionTitle)
                .foregroundStyle(HMColor.textPrimary)
            Text(subtitle)
                .font(HMFont.caption)
                .foregroundStyle(HMColor.textSecondary)
        }
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

    private func statusStrip(_ message: String) -> some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(HMFont.caption)
            .foregroundStyle(HMColor.success)
            .padding(.horizontal, HMSpacing.md)
            .padding(.vertical, HMSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HMColor.successSurface, in: RoundedRectangle(cornerRadius: HMRadius.small))
            .accessibilityIdentifier("onboarding.cached-status")
    }

    private func submit() {
        hasAttemptedSubmit = true
        clearFeedback()

        if let validationMessage = authenticationValidationMessage {
            errorMessage = validationMessage
            return
        }

        if mode == .createAccount,
           onboardingStep == .invoiceIdentity {
            if let validationMessage = businessProfile.invoiceIdentityValidationErrors.first?.message {
                errorMessage = validationMessage
                return
            }

            hasAttemptedSubmit = false
            onboardingStep = .businessDetails
            return
        }

        if mode == .createAccount,
           let validationMessage = businessProfile.validationErrors.first?.message {
            errorMessage = validationMessage
            return
        }

        isSubmitting = true

        Task {
            let result: AuthenticatedUserActionResult

            switch mode {
            case .signIn:
                result = await authRepository.signIn(
                    request: SignInRequest(
                        email: credentials.email.trimmed,
                        password: credentials.password
                    )
                )
            case .createAccount:
                result = await authRepository.signUp(
                    request: SignUpRequest(
                        email: credentials.email.trimmed,
                        password: credentials.password,
                        businessProfile: businessProfile.normalized
                    )
                )
            }

            isSubmitting = false
            apply(result: result)
        }
    }

    private func requestPasswordReset() {
        clearFeedback()

        if let validationMessage = credentials.emailValidationMessage {
            errorMessage = validationMessage
            return
        }

        isSubmitting = true

        Task {
            let result = await authRepository.requestPasswordReset(
                email: credentials.email.trimmed
            )
            isSubmitting = false

            switch result {
            case .success:
                statusMessage = AuthenticationStrings.passwordResetSuccess.localized
            case .failure(let error):
                errorMessage = error.localizedMessage
            }
        }
    }

    private var authenticationValidationMessage: String? {
        switch mode {
        case .signIn:
            return credentials.signInValidationMessage
        case .createAccount:
            return credentials.createAccountValidationMessage
        }
    }

    private var displayedValidationErrors: [BusinessProfileValidationError] {
        guard mode == .createAccount else { return [] }

        switch onboardingStep {
        case .invoiceIdentity:
            return businessProfile.invoiceIdentityValidationErrors
        case .businessDetails:
            return businessProfile.validationErrors
        }
    }

    private func apply(result: AuthenticatedUserActionResult) {
        switch result {
        case .success:
            clearFeedback()
        case .failure(let error):
            errorMessage = error.localizedMessage
        }
    }

    private func clearFeedback() {
        errorMessage = nil
        statusMessage = nil
    }
}

#if DEBUG
#Preview("Sign In") {
    AuthenticationView()
        .withPreviewDependencies()
}

#Preview("Create Account") {
    AuthenticationView(mode: .createAccount)
        .withPreviewDependencies()
}
#endif
