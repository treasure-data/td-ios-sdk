// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "TreasureData-iOS-SDK",
    platforms: [
        .iOS(.v12),
        .tvOS(.v12)
    ],
    products: [
        .library(
            name: "TreasureData-iOS-SDK",
            targets: ["TreasureData_iOS_SDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/treasure-data/KeenClient-iOS.git", .exact("4.1.1")),
        .package(url: "https://github.com/nicklockwood/GZIP.git", .exact("1.3.2"))
    ],
    targets: [
      .target(
            name: "TreasureData_iOS_SDK",
            dependencies: [
                .product(name: "KeenClientTD", package: "KeenClient-iOS"),
                "GZIP"
            ],
            path: ".",
            exclude: [
                "TreasureData.xcodeproj/",
                "Podfile",
                "Podfile.lock",
                "Gemfile",
                "Rakefile",
                "scripts/",
                "TestHost/",
                "TreasureData-iOS-SDK.podspec",
                "TreasureDataExample/",
                "TreasureDataExampleSwift/",
                "TreasureDataTests/"
            ],
            sources: [
                "TreasureData/",
                "TreasureDataInternal/",
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")],
            publicHeadersPath: "TreasureData",
            cxxSettings: [
                .headerSearchPath("TreasureData"),
                .headerSearchPath("TreasureDataInternal"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx1z
)
