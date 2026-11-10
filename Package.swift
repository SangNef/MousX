// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MousX",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MousX",
            path: "Sources/MousX"
        )
    ]
)
