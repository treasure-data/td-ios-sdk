Pod::Spec.new do |s|
  s.name         = 'TreasureDataEngage'
  s.module_name  = 'TreasureDataEngage'
  s.version      = '2.0.0'
  s.summary      = 'TreasureData Engage — campaign WebView / TDJSBridge for iOS'
  s.description  = <<-DESC
    The campaign-WebView layer for the TreasureData iOS SDK: PopupWebView and the
    secure TDJSBridge WebView↔native channel. Ships as a separate pod (its own
    module) so tracking-only apps depend on TreasureData-iOS-SDK alone and never
    link WebKit. iOS-only (WebKit is unavailable on tvOS).
  DESC
  s.license      = 'Apache'
  s.authors      = {  'sondo': 'son.do@treasure.ai' }
  s.platform     = :ios, '12.0'
  s.swift_version = '5.7'
  s.homepage     = 'https://github.com/treasure-data/td-ios-sdk'
  s.source       = { git: 'https://github.com/treasure-data/td-ios-sdk.git', tag: s.version.to_s }
  s.requires_arc = true

  s.source_files = 'TreasureDataEngage/**/*.swift'
  s.resources    = 'TreasureDataEngage/**/*.js'
  s.frameworks   = 'WebKit'

  # Pinned to the exact core version — the two pods release in lockstep.
  s.dependency 'TreasureData-iOS-SDK', '= 2.0.0'
end
