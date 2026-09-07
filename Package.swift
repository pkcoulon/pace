// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pace",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pace",
            path: "Sources/Pace",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
