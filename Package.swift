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
        // Campaign-WebView / TDJSBridge layer. iOS-only (WebKit); tvOS consumers
        // link only "TreasureData". Opt-in — tracking-only apps never pull WebKit.
        .library(
            name: "TreasureDataEngage",
            targets: ["TreasureDataEngage"]),
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
                "TreasureDataEngage",
            ],
            sources: [
                "TreasureData",
                "TreasureDataInternal",
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        // The campaign-WebView / TDJSBridge layer. Depends on core TreasureData.
        // iOS-only in practice (WebKit); source is guarded with #if canImport(WebKit)
        // so it compiles to an empty module on tvOS rather than breaking the build.
        .target(
            name: "TreasureDataEngage",
            dependencies: [
                "TreasureData",
            ],
            path: "TreasureDataEngage",
            resources: [.copy("Popup/TDBridge.js")]
        ),
        // Engage unit tests. iOS-only (drives an offscreen WKWebView); run via
        // `xcodebuild test` against a simulator, not host `swift test`.
        .testTarget(
            name: "TreasureDataEngageTests",
            dependencies: [
                "TreasureDataEngage",
            ],
            path: "TreasureDataEngageTests"
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
