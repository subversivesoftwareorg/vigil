// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Vigil",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "Vigil",
            path: "Vigil",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "VigilTests",
            dependencies: ["Vigil"],
            path: "VigilTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
