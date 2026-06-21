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
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                if let message {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if case .loading = state {
                ProgressView()
                    .accessibilityLabel("Loading")
            }

            if let retry {
                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var title: String {
        switch state {
        case .loading:
            return "Loading"
        case .empty(let title, _):
            return title
        case .offline:
            return "You're Offline"
        case .syncing:
            return "Syncing"
        case .failed:
            return "Something Went Wrong"
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
}

#if DEBUG
#Preview("Loading") {
    AppStatusView(state: .loading)
}

#Preview("Failure") {
    AppStatusView(
        state: .failed(message: "We couldn't refresh this load."),
        retry: {}
    )
}
#endif
