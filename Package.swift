// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Notchit",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NotchitCore", path: "Sources/NotchitCore"),
        .executableTarget(name: "Notchit", dependencies: ["NotchitCore"], path: "Sources/Notchit"),
        .testTarget(name: "NotchitCoreTests", dependencies: ["NotchitCore"], path: "Tests/NotchitCoreTests")
    ]
)
