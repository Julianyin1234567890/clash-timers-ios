// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClashTimersCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ClashTimersCore", targets: ["ClashTimersCore"])],
    targets: [
        .target(name: "ClashTimersCore", resources: [.process("Resources")]),
        .testTarget(name: "ClashTimersCoreTests", dependencies: ["ClashTimersCore"],
                    resources: [.process("Fixtures")])
    ]
)
