// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Birthday",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BirthdayCore", targets: ["BirthdayCore"]),
        .executable(name: "Birthday", targets: ["BirthdayApp"])
    ],
    targets: [
        .target(
            name: "BirthdayCore",
            linkerSettings: [
                .linkedFramework("Contacts")
            ]
        ),
        .executableTarget(
            name: "BirthdayApp",
            dependencies: ["BirthdayCore"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "BirthdayCoreTests",
            dependencies: ["BirthdayCore"]
        ),
        .testTarget(
            name: "BirthdayAppTests",
            dependencies: ["BirthdayApp"]
        )
    ]
)
