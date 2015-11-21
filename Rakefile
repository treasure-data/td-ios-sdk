require 'open-uri'
require 'json'

desc "Create the static library"
task :build do
  sh "xcodebuild -workspace TreasureData.xcworkspace -scheme TreasureData -configuration Release -sdk iphoneos SYMROOT=$(PWD)/Output"
  sh "xcodebuild -workspace TreasureData.xcworkspace -scheme TreasureData -configuration Release -sdk iphonesimulator SYMROOT=$(PWD)/Output"
  sh "mkdir -p Output/TreasureData"
  sh "lipo -create Output/Release-*/libTreasureData.a  -output Output/TreasureData/libTreasureData.a"
  sh "lipo -create Output/Release-*/libKeenClientTD.a -output Output/TreasureData/libKeenClientTD.a"
  sh "cp -p Output/Release-iphoneos/*.h Output/Release-iphoneos/include/TreasureData/* Output/TreasureData/"
end
