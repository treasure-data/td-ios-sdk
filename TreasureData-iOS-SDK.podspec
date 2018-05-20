Pod::Spec.new do |s|
  s.name         = "TreasureData-iOS-SDK"
  s.version      = "0.1.27"
  s.summary      = "TreasureData SDK for iOS."
  s.license      = "Apache"
  s.author       = { "TreasureData" => "mitsu@treasure-data.com" }
  s.platforms    = { :ios => "7.0", :tvos => "9.0" }
  s.homepage     = "https://github.com/treasure-data/td-ios-sdk"
  s.source       = { :git => "https://github.com/treasure-data/td-ios-sdk.git", :tag => s.version.to_s  }
  s.source_files  = 'TreasureData'
  s.library      = 'z'
  s.frameworks   = ['Security']
  s.public_header_files = ["TreasureData/TreasureData.h", "TreasureData/TDClient.h"]
  s.dependency "KeenClientTD", '= 3.2.33'
  s.requires_arc = true
end
