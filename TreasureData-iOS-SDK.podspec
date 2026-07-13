Pod::Spec.new do |s|
  s.name         = 'TreasureData-iOS-SDK'
  # The Swift module is `TreasureData` (v2), so consumers `import TreasureData`
  # while the pod name / Podfile entry stays 'TreasureData-iOS-SDK'.
  s.module_name  = 'TreasureData'
  s.version      = '2.0.0'
  s.summary      = 'TreasureData SDK for iOS'
  s.license      = 'Apache'
  s.authors      = {  'mitsu': 'mitsu@treasure-data.com',
                      'huylenq': 'huy.lenq@gmail.com',
                      'tung-vu-td': 'tung.vu@treasure-data.com' }
  s.platforms    = { ios: '12.0', tvos: '12.0' }
  s.swift_version = '5.7'
  s.homepage     = 'https://github.com/treasure-data/td-ios-sdk'
  s.source       = { git: 'https://github.com/treasure-data/td-ios-sdk.git', tag: s.version.to_s }
  # The public API is Swift; the only Objective-C is the internal
  # KeenClient (TDOverride) category (in TreasureDataObjC) that lets the Swift
  # TDClient subclass override KeenClient's private sendEvents:. The Xcode-only
  # bridging header under Support/ is excluded — CocoaPods compiles the ObjC and
  # Swift together in one module, so no bridging header is needed.
  s.source_files = 'TreasureData/**/*.swift',
                   'TreasureDataInternal/**/*.swift',
                   'TreasureDataObjC/**/*.{h,m}'
  s.resources    = 'PrivacyInfo.xcprivacy'
  s.library      = 'z'
  s.frameworks   = 'Security'
  s.dependency 'KeenClientTD', '= 4.1.1'
  s.dependency 'GZIP', '= 1.3.2'
  s.requires_arc = true
end
