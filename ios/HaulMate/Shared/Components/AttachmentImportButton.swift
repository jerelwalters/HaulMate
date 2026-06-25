//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct AttachmentImportButton<Label: View>: View {
    @State private var isImporting = false

    let onPicked: (URL) -> Void
    let onFailure: () -> Void
    let label: () -> Label

    init(
        onPicked: @escaping (URL) -> Void,
        onFailure: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.onPicked = onPicked
        self.onFailure = onFailure
        self.label = label
    }

    var body: some View {
        Button {
            isImporting = true
        } label: {
            label()
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            onPicked(url)
        case .failure:
            onFailure()
        }
    }
}
