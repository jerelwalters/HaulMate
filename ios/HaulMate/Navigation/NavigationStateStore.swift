//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

@MainActor
protocol NavigationStatePersisting: AnyObject {
    func load() -> Data?
    func save(_ data: Data)
}

@MainActor
final class UserDefaultsNavigationStateStore: NavigationStatePersisting {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "app-navigation-state"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> Data? {
        defaults.data(forKey: key)
    }

    func save(_ data: Data) {
        defaults.set(data, forKey: key)
    }
}
