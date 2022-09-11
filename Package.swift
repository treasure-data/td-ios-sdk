// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "TreasureData-iOS-SDK",
    platforms: [
        .macOS(.v10_10),
        .iOS(.v11),
        .tvOS(.v9),
        .watchOS(.v2)
    ],
    products: [
        .library(
            name: "TreasureData-iOS-SDK",
            targets: ["TreasureData"]),
    ],
    dependencies: [
        // Dependencies
        // https://developer.apple.com/documentation/packagedescription/package/dependency
        // FIXME: Use real KeenClient-iOS library from Treasure Data official repository
        .package(url: "git@github.com:nacho4d/KeenClient-iOS.git", .exact("13.3.0")),
        // For development purposes you can set a path to refer to a local package
        //.package(path: "../KeenClient-iOS")
    ],
    targets: [
      .target(
            name: "TreasureData",
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
                "TreasureDataTest/"
            ],
            sources: [
                "TreasureData/",
                "TreasureDataInternal/",
            ],
            publicHeadersPath: "TreasureData",
            cSettings: [
                .define("TD_SWIFT_PACKAGE")
            ],
            cxxSettings: [
                .headerSearchPath("TreasureData"),
                .headerSearchPath("TreasureDataInternal"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx1z
)
