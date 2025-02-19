// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpeechRecognitionService",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .visionOS(.v1)],
    products: [
        .library(
            name: "SpeechRecognitionService",
            targets: ["SpeechRecognitionService"]),
    ],
    targets: [.target(name: "SpeechRecognitionService")]
)
