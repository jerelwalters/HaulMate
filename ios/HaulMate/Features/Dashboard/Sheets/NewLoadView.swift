//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct NewLoadView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppStatusView(
                state: .empty(
                    title: NewLoadStrings.emptyTitle.localized,
                    message: NewLoadStrings.emptyMessage.localized
                )
            )
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
}

#if DEBUG
#Preview {
    NewLoadView()
}
#endif
