// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Rhythm",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [.library(name: "Rhythm", targets: ["Rhythm"])],
    targets: [
        .target(name: "Rhythm"),
        .testTarget(name: "RhythmTests", dependencies: ["Rhythm"])
    ]
)
