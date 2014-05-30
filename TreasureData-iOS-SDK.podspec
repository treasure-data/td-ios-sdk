#
#  Be sure to run `pod spec lint TreasureData.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name         = "TreasureData-iOS-SDK"
  s.version      = "0.0.1"
  s.summary      = "TreasureData SDK for iOS."
  s.license      = "Apache"
  s.author       = { "TreasureData" => "mitsu@treasure-data.com" }
  s.platform     = :ios

  # TODO: now it's closed project
  # s.homepage     = "https://github.com/treasure-data/td-ios-sdk"
  # s.source       = { :git => "https://github.com/treasure-data/td-ios-sdk.git", :tag => "0.0.1" }
  s.homepage     = "http://www.treasuredata.com/"
  s.source       = { :git => "git@github.com:treasure-data/td-ios-sdk.git", :tag => "0.0.1" }

  s.source_files  = "TreasureData",
  s.public_header_files = "TreasureData/TreasureData.h"
  s.requires_arc = true
  s.dependency "KeenClient", '= 3.2.7'
end
