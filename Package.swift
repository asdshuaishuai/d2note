// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "d2note",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "d2note",
            path: "Sources/d2note"
        )
    ]
)
