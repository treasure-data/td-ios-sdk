Pod::Spec.new do |s|
  s.name         = "TreasureData-iOS-SDK"
  s.version      = "0.0.1"
  s.summary      = "TreasureData SDK for iOS."
  s.license      = "Apache"
  s.author       = { "TreasureData" => "mitsu@treasure-data.com" }
  s.platform     = :ios
  s.homepage     = "https://github.com/treasure-data/td-ios-sdk"
  s.source       = { :git => "https://github.com/treasure-data/td-ios-sdk.git", :tag => "0.0.1" }
  s.source_files  = "TreasureData",
  s.public_header_files = "TreasureData/TreasureData.h"
  s.resources = 'Resources.bundle'
  s.requires_arc = true
  s.dependency "KeenClient", '= 3.2.7'
end
