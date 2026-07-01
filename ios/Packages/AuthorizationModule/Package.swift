// swift-tools-version: 6.0
//
//  Created by Jerel Walters on 7/1/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "AuthorizationModule",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AuthorizationModule",
            targets: ["AuthorizationModule"]
        )
    ],
    targets: [
        .target(name: "AuthorizationModule"),
        .testTarget(
            name: "AuthorizationModuleTests",
            dependencies: ["AuthorizationModule"]
        )
    ]
)
