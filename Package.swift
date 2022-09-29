// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "TreasureData-iOS-SDK",
    platforms: [
        .iOS(.v12),
        .tvOS(.v9)
    ],
    products: [
        .library(
            name: "TreasureData-iOS-SDK",
            targets: ["TreasureData_iOS_SDK"]),
    ],
    dependencies: [
        .package(url: "git@github.com:treasure-data/KeenClient-iOS.git", .exact("3.9.0"))
    ],
    targets: [
      .target(
            name: "TreasureData_iOS_SDK",
            dependencies: [
                "KeenClientTD"
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
            publicHeadersPath: "TreasureData",
            cxxSettings: [
                .headerSearchPath("TreasureData"),
                .headerSearchPath("TreasureDataInternal"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx1z
)
