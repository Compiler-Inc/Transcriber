// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Transcriber",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .visionOS(.v1)],
    products: [.library(name: "Transcriber", targets: ["Transcriber"])],
    targets: [.target(name: "Transcriber")]
)
