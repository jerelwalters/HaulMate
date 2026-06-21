//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

enum AppContentState: Equatable {
    case loading
    case empty(title: String, message: String)
    case offline(message: String)
    case syncing(message: String)
    case failed(message: String)
}

struct AppStatusView: View {
    let state: AppContentState
    var retry: (() -> Void)?

    init(state: AppContentState, retry: (() -> Void)? = nil) {
        self.state = state
        self.retry = retry
    }

    var body: some View {
        ZStack {
            HMColor.canvas
                .ignoresSafeArea()

            VStack(spacing: HMSpacing.lg) {
                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)

                VStack(spacing: HMSpacing.sm) {
                    Text(title)
                        .font(HMFont.cardTitle)
                        .foregroundStyle(HMColor.textPrimary)
                    if let message {
                        Text(message)
                            .font(HMFont.body)
                            .foregroundStyle(HMColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                if case .loading = state {
                    ProgressView()
                        .tint(HMColor.accent)
                        .accessibilityLabel(AppStatusStrings.loadingAccessibilityLabel.localized)
                }

                if let retry {
                    Button(AppStatusStrings.retryButton.localized, action: retry)
                        .buttonStyle(.borderedProminent)
                        .tint(HMColor.accent)
                }
            }
            .padding(HMSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch state {
        case .loading:
            return AppStatusStrings.loadingTitle.localized
        case .empty(let title, _):
            return title
        case .offline:
            return AppStatusStrings.offlineTitle.localized
        case .syncing:
            return AppStatusStrings.syncingTitle.localized
        case .failed:
            return AppStatusStrings.failedTitle.localized
        }
    }

    private var message: String? {
        switch state {
        case .loading:
            return nil
        case .empty(_, let message),
             .offline(let message),
             .syncing(let message),
             .failed(let message):
            return message
        }
    }

    private var iconName: String {
        switch state {
        case .loading:
            return "arrow.triangle.2.circlepath"
        case .empty:
            return "shippingbox"
        case .offline:
            return "wifi.slash"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch state {
        case .loading,
             .syncing:
            return HMColor.accent
        case .empty:
            return HMColor.textSecondary
        case .offline:
            return HMColor.warning
        case .failed:
            return HMColor.danger
        }
    }
}

#if DEBUG
#Preview("Loading") {
    AppStatusView(state: .loading)
}

#Preview("Loading · Dark") {
    AppStatusView(state: .loading)
        .preferredColorScheme(.dark)
}

#Preview("Failure") {
    AppStatusView(
        state: .failed(message: AppStatusStrings.previewFailureMessage.localized),
        retry: {}
    )
}

#Preview("Failure · Dark") {
    AppStatusView(
        state: .failed(message: AppStatusStrings.previewFailureMessage.localized),
        retry: {}
    )
    .preferredColorScheme(.dark)
}
#endif
