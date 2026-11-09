// swift-tools-version: 6.0
import PackageDescription

// Shared, game-agnostic pieces of the Just Puzzles family. Foundation and
// Observation only: no SwiftUI, no UIKit, no StoreKit, so a game's `Engine/`
// can still be compiled with bare `swiftc` by passing these sources alongside
// it (see README.md).
let package = Package(
    name: "PuzzleKit",
    platforms: [.iOS(.v18), .macOS(.v14), .tvOS(.v17), .visionOS(.v2)],
    products: [
        .library(name: "PuzzleKit", targets: ["PuzzleKit"]),
    ],
    targets: [
        .target(name: "PuzzleKit"),
        .testTarget(name: "PuzzleKitTests", dependencies: ["PuzzleKit"]),
    ]
)
