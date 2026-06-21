//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation
import Observation

enum AppTab: String, Codable, CaseIterable, Identifiable {
    case dashboard
    case loads
    case settings

    var id: Self { self }
}

enum DashboardRoute: Hashable, Codable {
    case activeLoad(id: UUID)
}

enum LoadsRoute: Hashable, Codable {
    case load(id: UUID)
}

enum SettingsRoute: Hashable, Codable {
    case businessProfile
}

enum AppSheet: Hashable, Codable, Identifiable {
    case newLoad

    var id: String {
        switch self {
        case .newLoad:
            return "new-load"
        }
    }
}

struct NavigationSnapshot: Codable, Equatable {
    var selectedTab: AppTab = .dashboard
    var dashboardPath: [DashboardRoute] = []
    var loadsPath: [LoadsRoute] = []
    var settingsPath: [SettingsRoute] = []
    var presentedSheet: AppSheet?
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab { didSet { persist() } }
    var dashboardPath: [DashboardRoute] { didSet { persist() } }
    var loadsPath: [LoadsRoute] { didSet { persist() } }
    var settingsPath: [SettingsRoute] { didSet { persist() } }
    var presentedSheet: AppSheet? { didSet { persist() } }

    private let store: any NavigationStatePersisting

    init(store: any NavigationStatePersisting = UserDefaultsNavigationStateStore()) {
        self.store = store

        let snapshot = store.load()
            .flatMap { try? JSONDecoder().decode(NavigationSnapshot.self, from: $0) }
            ?? NavigationSnapshot()

        selectedTab = snapshot.selectedTab
        dashboardPath = snapshot.dashboardPath
        loadsPath = snapshot.loadsPath
        settingsPath = snapshot.settingsPath
        presentedSheet = snapshot.presentedSheet
    }

    @discardableResult
    func handle(url: URL) -> Bool {
        guard let loadID = Self.loadID(from: url) else { return false }

        selectedTab = .loads
        loadsPath = [.load(id: loadID)]
        presentedSheet = nil
        return true
    }

    func resetForSignOut() {
        selectedTab = .dashboard
        dashboardPath = []
        loadsPath = []
        settingsPath = []
        presentedSheet = nil
    }

    var snapshot: NavigationSnapshot {
        NavigationSnapshot(
            selectedTab: selectedTab,
            dashboardPath: dashboardPath,
            loadsPath: loadsPath,
            settingsPath: settingsPath,
            presentedSheet: presentedSheet
        )
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        store.save(data)
    }

    private static func loadID(from url: URL) -> UUID? {
        let components = url.pathComponents.filter { $0 != "/" }

        if url.scheme?.lowercased() == "haulmate",
           url.host?.lowercased() == "loads",
           let id = components.first {
            return UUID(uuidString: id)
        }

        if url.scheme?.lowercased() == "https",
           url.host?.lowercased() == "app.haulmate.com",
           components.count == 2,
           components[0].lowercased() == "loads" {
            return UUID(uuidString: components[1])
        }

        return nil
    }
}
