// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Twitcher",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TwitcherCore", targets: ["TwitcherCore"]),
        .executable(name: "Twitcher", targets: ["Twitcher"]),
    ],
    targets: [
        .target(name: "TwitcherCore"),
        .executableTarget(
            name: "Twitcher",
            dependencies: ["TwitcherCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
            ]
        ),
        .executableTarget(name: "TwitcherCoreChecks", dependencies: ["TwitcherCore"]),
    ]
)
