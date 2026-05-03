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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "PMT",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/PMT"
        )
    ]
)
