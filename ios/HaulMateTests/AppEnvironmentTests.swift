//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI
import XCTest
@testable import HaulMate

@MainActor
final class AppEnvironmentTests: XCTestCase {
    func testEntryReturnsInjectedDependencies() {
        let appRootRepository = AppRootRepository(
            appService: AppRootManager()
        )
        let router = AppRouter(store: MemoryNavigationStore())
        var environment = EnvironmentValues()

        environment.appDependencies = AppDependencies(
            appRootRepository: appRootRepository,
            router: router
        )

        XCTAssertTrue(
            environment.appDependencies?.appRootRepository === appRootRepository
        )
        XCTAssertTrue(environment.appDependencies?.router === router)
    }
}

@MainActor
private final class MemoryNavigationStore: NavigationStatePersisting {
    func load() -> Data? { nil }
    func save(_ data: Data) {}
}
