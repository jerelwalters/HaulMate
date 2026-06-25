//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import StorageModule

enum HaulMateStorageKeys {
    static let activeWorkflow = StorageKey("active-workflow")
    static let profile = StorageKey("profile")
    static let recentDocuments = StorageKey("recent-documents")
    static let syncMetadata = StorageKey("sync-metadata")
}
