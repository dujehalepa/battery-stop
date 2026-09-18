// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BatteryStop",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "BatteryStopCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "BatteryStopApp",
            dependencies: ["BatteryStopCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
