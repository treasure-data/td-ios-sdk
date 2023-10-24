Pod::Spec.new do |s|
  s.name         = "TreasureData-iOS-SDK"
  s.version      = "1.0.1"
  s.summary      = "TreasureData SDK for iOS."
  s.license      = "Apache"
  s.authors      = { "mitsu" => "mitsu@treasure-data.com",
                      "huylenq" => "huy.lenq@gmail.com",
                      "tung-vu-td" => "tung.vu@treasure-data.com" }
  s.platforms    = { :ios => "12.0", :tvos => "12.0" }
  s.homepage     = "https://github.com/treasure-data/td-ios-sdk"
  s.source       = { :git => "https://github.com/treasure-data/td-ios-sdk.git", :tag => s.version.to_s  }
  s.source_files = ['TreasureData', "TreasureDataInternal"]
  s.resources    = "PrivacyInfo.xcprivacy"
  s.library      = 'z'
  s.frameworks   = 'Security', 'StoreKit'
  s.public_header_files = ["TreasureData/TreasureData.h", "TreasureData/TDClient.h", "TreasureData/TDRequestOptionsKey.h"]
  s.dependency "KeenClientTD", '= 4.1.0'
  s.dependency "GZIP", '= 1.3.0'
  s.requires_arc = true
end
