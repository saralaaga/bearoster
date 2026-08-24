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
        .executable(name: "Roster", targets: ["RosterApp"])
    ],
    targets: [
        .target(
            name: "RosterCore",
            linkerSettings: [
                .linkedFramework("Contacts")
            ]
        ),
        .executableTarget(
            name: "RosterApp",
            dependencies: ["RosterCore"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "RosterCoreTests",
            dependencies: ["RosterCore"]
        ),
        .testTarget(
            name: "RosterAppTests",
            dependencies: ["RosterApp"]
        )
    ]
)
