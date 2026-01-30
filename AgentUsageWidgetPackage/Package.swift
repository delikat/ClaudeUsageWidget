// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AgentUsageWidgetPackage",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "Shared",
            type: .dynamic,
            targets: ["Shared"]
        ),
    ],
    targets: [
        .target(
            name: "Shared",
            path: "Sources/Shared"
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"],
            path: "Tests/SharedTests"
        ),
    ]
)
