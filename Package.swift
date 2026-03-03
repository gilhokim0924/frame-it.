// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FrameIt",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "FrameIt",
            path: "Sources/FrameIt"
        )
    ]
)
