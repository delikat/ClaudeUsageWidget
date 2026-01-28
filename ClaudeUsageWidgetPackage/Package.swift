// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ClaudeUsageWidgetPackage",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "Shared",
            targets: ["Shared"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.0"),
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
        .testTarget(
            name: "SnapshotTests",
            dependencies: [
                "Shared",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/SnapshotTests"
        ),
    ]
)
