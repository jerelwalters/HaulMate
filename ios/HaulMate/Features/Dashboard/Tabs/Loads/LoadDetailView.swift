//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct LoadDetailView: View {
    let loadID: UUID

    var body: some View {
        AppStatusView(state: .syncing(message: LoadDetailStrings.restoringMessage.localized))
            .navigationTitle(LoadDetailStrings.navigationTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("load.\(loadID.uuidString)")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        LoadDetailView(loadID: SessionUser.preview.id)
    }
}
#endif
