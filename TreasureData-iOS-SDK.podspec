Pod::Spec.new do |s|
  s.name         = "TreasureData-iOS-SDK"
  s.version      = "0.8.1"
  s.summary      = "TreasureData SDK for iOS."
  s.license      = "Apache"
  s.authors      = { "mitsu" => "mitsu@treasure-data.com",
                      "huylenq" => "huy.lenq@gmail.com",
                      "tung-vu-td" => "tung.vu@treasure-data.com" }
  s.platforms    = { :ios => "7.0", :tvos => "9.0" }
  s.homepage     = "https://github.com/treasure-data/td-ios-sdk"
  s.source       = { :git => "https://github.com/treasure-data/td-ios-sdk.git", :tag => s.version.to_s  }
  s.source_files = 'TreasureData'
  s.library      = 'z'
  s.frameworks   = 'Security', 'StoreKit'
  s.public_header_files = ["TreasureData/TreasureData.h", "TreasureData/TDClient.h", "TreasureData/TDRequestOptionsKey.h"]
  s.dependency "KeenClientTD", '= 3.3.0'
  s.requires_arc = true
end
