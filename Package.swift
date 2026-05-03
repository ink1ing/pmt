// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PMT",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PMT", targets: ["PMT"])
    ],
    targets: [
        .executableTarget(
            name: "PMT",
            path: "Sources/PMT"
        )
    ]
)
