// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClassBell",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClassBell",
            resources: [.process("Resources")]
        )
    ]
)
