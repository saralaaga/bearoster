// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Roster",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "RosterCore", targets: ["RosterCore"]),
        .library(name: "RosterShared", targets: ["RosterShared"]),
        .executable(name: "Bearoster", targets: ["RosterApp"]),
        .executable(name: "RosterIOS", targets: ["RosterIOSApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0")
    ],
    targets: [
        .target(
            name: "RosterCore",
            linkerSettings: [
                .linkedFramework("Contacts")
            ]
        ),
        .target(
            name: "RosterShared",
            dependencies: [
                "RosterCore",
                .product(name: "MCP", package: "swift-sdk")
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "RosterApp",
            dependencies: ["RosterShared"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "RosterIOSApp",
            dependencies: ["RosterShared"],
            linkerSettings: [
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "RosterCoreTests",
            dependencies: ["RosterCore"]
        ),
        .testTarget(
            name: "RosterAppTests",
            dependencies: ["RosterShared"]
        )
    ]
)
