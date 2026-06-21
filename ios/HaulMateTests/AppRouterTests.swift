//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import HaulMate

@MainActor
final class AppRouterTests: XCTestCase {
    func testNavigationStateRestoresFromPersistedSnapshot() throws {
        let store = MemoryNavigationStateStore()
        let loadID = UUID()
        let router = AppRouter(store: store)

        router.selectedTab = .loads
        router.loadsPath = [.load(id: loadID)]
        router.presentedSheet = .newLoad

        let restored = AppRouter(store: store)

        XCTAssertEqual(restored.snapshot, router.snapshot)
    }

    func testActiveLoadNavigationRestoresFromPersistedSnapshot() {
        let store = MemoryNavigationStateStore()
        let loadID = UUID()
        let router = AppRouter(store: store)

        router.selectedTab = .dashboard
        router.dashboardPath = [.activeLoad(id: loadID)]

        let restored = AppRouter(store: store)

        XCTAssertEqual(restored.selectedTab, .dashboard)
        XCTAssertEqual(restored.dashboardPath, [.activeLoad(id: loadID)])
    }

    func testCustomSchemeDeepLinkSelectsLoad() {
        let store = MemoryNavigationStateStore()
        let router = AppRouter(store: store)
        let loadID = UUID()

        let handled = router.handle(url: URL(string: "haulmate://loads/\(loadID)")!)

        XCTAssertTrue(handled)
        XCTAssertEqual(router.selectedTab, .loads)
        XCTAssertEqual(router.loadsPath, [.load(id: loadID)])
    }

    func testDeepLinkNavigationRestoresFromPersistedSnapshot() {
        let store = MemoryNavigationStateStore()
        let loadID = UUID()
        let router = AppRouter(store: store)
        router.presentedSheet = .newLoad

        let handled = router.handle(
            url: URL(string: "haulmate://loads/\(loadID)")!
        )
        let restored = AppRouter(store: store)

        XCTAssertTrue(handled)
        XCTAssertEqual(restored.selectedTab, .loads)
        XCTAssertEqual(restored.loadsPath, [.load(id: loadID)])
        XCTAssertNil(restored.presentedSheet)
    }

    func testUnknownDeepLinkDoesNotChangeNavigation() {
        let router = AppRouter(store: MemoryNavigationStateStore())

        let handled = router.handle(url: URL(string: "https://example.com/loads/123")!)

        XCTAssertFalse(handled)
        XCTAssertEqual(router.snapshot, NavigationSnapshot())
    }

    func testSignOutResetClearsAccountNavigation() {
        let router = AppRouter(store: MemoryNavigationStateStore())
        router.selectedTab = .settings
        router.settingsPath = [.businessProfile]
        router.presentedSheet = .newLoad

        router.resetForSignOut()

        XCTAssertEqual(router.snapshot, NavigationSnapshot())
    }
}

@MainActor
private final class MemoryNavigationStateStore: NavigationStatePersisting {
    private var data: Data?

    func load() -> Data? {
        data
    }

    func save(_ data: Data) {
        self.data = data
    }
}
