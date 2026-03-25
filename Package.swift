// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LocalPaste",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LocalPaste", targets: ["LocalPaste"])
    ],
    targets: [
        .executableTarget(
            name: "LocalPaste",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
