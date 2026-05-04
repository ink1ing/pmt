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
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "PMT",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "WhisperKit", package: "argmax-oss-swift")
            ],
            path: "Sources/PMT"
        )
    ]
)
