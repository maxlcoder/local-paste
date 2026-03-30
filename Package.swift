// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LocalPaste",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "LocalPasteUI", targets: ["LocalPasteUI"]),
        .executable(name: "LocalPaste", targets: ["LocalPaste"])
    ],
    targets: [
        .target(
            name: "LocalPasteUI",
            path: "Sources/LocalPaste",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "LocalPaste",
            dependencies: ["LocalPasteUI"],
            path: "Sources/LocalPasteExecutable"
        )
    ]
)
