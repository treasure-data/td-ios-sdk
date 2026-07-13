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
        .package(url: "https://github.com/treasure-data/KeenClient-iOS.git", exact: "4.1.1"),
        .package(url: "https://github.com/nicklockwood/GZIP.git", exact: "1.3.2")
    ],
    targets: [
        // Internal Objective-C module: re-declares KeenClient's private
        // `sendEvents:...` selector (via the KeenClient (TDOverride) category) so
        // the Swift TDClient subclass can override it. SwiftPM has no bridging
        // header, so this is exposed as an importable module instead.
        .target(
            name: "TreasureDataObjC",
            dependencies: [
                .product(name: "KeenClientTD", package: "KeenClient-iOS"),
            ],
            path: "TreasureDataObjC",
            publicHeadersPath: "include"
        ),
        // The public Swift SDK. Consumers `import TreasureData`.
        .target(
            name: "TreasureData",
            dependencies: [
                "TreasureDataObjC",
                .product(name: "KeenClientTD", package: "KeenClient-iOS"),
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
                "TreasureDataObjC",
                "TreasureDataExample",
                "TreasureDataExampleSwift",
                "TreasureDataTests",
                "Support",
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
