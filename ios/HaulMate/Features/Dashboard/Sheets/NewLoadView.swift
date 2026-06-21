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
                    title: "Load intake is next",
                    message: "This modal is ready for the P0-MOB-05 workflow."
                )
            )
            .navigationTitle("New Load")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: dismiss.callAsFunction)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    NewLoadView()
}
#endif
