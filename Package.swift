// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "TreasureData",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12),
        .tvOS(.v12)
    ],
    products: [
        .library(
            name: "TreasureData",
            targets: ["TreasureData"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/GZIP.git", exact: "1.3.2")
    ],
    targets: [
        // The public Swift SDK. Consumers `import TreasureData`. Uses the system
        // libsqlite3 and CommonCrypto directly; no third-party engine dependency.
        .target(
            name: "TreasureData",
            dependencies: [
                "GZIP",
            ],
            path: ".",
            exclude: [
                "TreasureData.xcodeproj",
                "TreasureData.xcworkspace",
                "Podfile",
                "Podfile.lock",
                "Gemfile",
                "Rakefile",
                "scripts",
                "docs",
                "TestHost",
                "TreasureData-iOS-SDK.podspec",
                "TreasureDataExample",
                "TreasureDataExampleSwift",
                "TreasureDataTests",
            ],
            sources: [
                "TreasureData",
                "TreasureDataInternal",
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        // Integration tests (credential-gated; run in CI with API_* env vars).
        // Only the Swift integration files are included — the ObjC unit tests
        // live in the Xcode workspace test target, not SwiftPM.
        .testTarget(
            name: "TreasureDataIntegrationTests",
            dependencies: ["TreasureData"],
            path: "TreasureDataTests",
            sources: [
                "IntegrationTests.swift",
                "TDAPI.swift",
            ]
        ),
    ]
)
