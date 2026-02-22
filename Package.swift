// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Sayit",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "Sayit",
            path: "Sources/Sayit",
            exclude: ["Info.plist"]
        )
    ]
)
