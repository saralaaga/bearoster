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
        .executable(name: "Roster", targets: ["RosterApp"])
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
            dependencies: ["RosterCore"],
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
