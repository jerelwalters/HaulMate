//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct AuthenticationView: View {
    @Environment(\.appDependencies) private var dependencies

    private var appRootRepository: AppRootRepository {
        dependencies.required.appRootRepository
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "truck.box.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("HaulMate")
                    .font(.largeTitle.bold())
                Text("Know whether the load pays, prove what happened, and invoice faster.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button("Continue to Pilot", action: signIn)
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("authentication.continue")
        }
        .padding(24)
    }

    private func signIn() {
        Task { await appRootRepository.signIn() }
    }
}

#if DEBUG
#Preview {
    AuthenticationView()
        .withPreviewDependencies()
}
#endif
