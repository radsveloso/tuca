// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Tuca",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Tuca", path: "Sources/Tuca")
    ]
)
