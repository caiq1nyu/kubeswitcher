// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KubeSwitcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "KubeSwitcherCore", targets: ["KubeSwitcherCore"]),
        .executable(name: "KubeSwitcher", targets: ["KubeSwitcherApp"]),
        .executable(name: "KubeSwitcherCoreChecks", targets: ["KubeSwitcherCoreChecks"]),
        .executable(name: "KubeSwitcherSmoke", targets: ["KubeSwitcherSmoke"])
    ],
    targets: [
        .target(
            name: "KubeSwitcherCore",
            path: "Sources/KubeSwitcherCore"
        ),
        .executableTarget(
            name: "KubeSwitcherApp",
            dependencies: ["KubeSwitcherCore"],
            path: "Sources/KubeSwitcherApp"
        ),
        .executableTarget(
            name: "KubeSwitcherCoreChecks",
            dependencies: ["KubeSwitcherCore"],
            path: "Sources/KubeSwitcherCoreChecks"
        ),
        .executableTarget(
            name: "KubeSwitcherSmoke",
            dependencies: ["KubeSwitcherCore"],
            path: "Sources/KubeSwitcherSmoke"
        )
    ]
)
