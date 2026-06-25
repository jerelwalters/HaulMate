// swift-tools-version: 6.0
//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "StorageModule",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "StorageModule",
            targets: ["StorageModule"]
        )
    ],
    targets: [
        .target(
            name: "StorageModule",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "StorageModuleTests",
            dependencies: ["StorageModule"]
        )
    ]
)
