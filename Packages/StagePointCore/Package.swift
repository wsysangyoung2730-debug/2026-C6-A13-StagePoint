// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StagePointCore",
    platforms: [.iOS("18.0"), .macOS(.v13)],
    products: [.library(name: "StagePointCore", targets: ["StagePointCore"])],
    targets: [
        .target(name: "StagePointCore"),
        .testTarget(name: "StagePointCoreTests", dependencies: ["StagePointCore"])
    ]
)
