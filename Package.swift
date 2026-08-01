// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PinnedItems",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PinnedItems", targets: ["PinnedItems"])
    ],
    targets: [
        .executableTarget(
            name: "PinnedItems",
            path: "Sources/PinnedItems"
        )
    ]
)
