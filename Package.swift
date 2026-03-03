// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FrameIt",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "FrameIt",
            path: "Sources/FrameIt"
        )
    ]
)
