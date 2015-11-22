require 'open-uri'
require 'json'

desc "Clean output directory"
task :clean do
  sh "rm -rf Output"
end

desc "Create static libraries"
task :build do
  sh "xcodebuild -workspace TreasureData.xcworkspace -scheme TreasureData -configuration Release -sdk iphoneos SYMROOT=$(PWD)/Output"
  sh "xcodebuild -workspace TreasureData.xcworkspace -scheme TreasureData -configuration Release -sdk iphonesimulator SYMROOT=$(PWD)/Output"
end

desc "Create package"
task :package do
  sh "rm -f Output/TreasureData.zip"
  Rake::Task[:build].invoke
  sh "mkdir -p Output/TreasureData"
  sh "lipo -create Output/Release-*/libTreasureData.a  -output Output/TreasureData/libTreasureData.a"
  sh "lipo -create Output/Release-*/libKeenClientTD.a -output Output/TreasureData/libKeenClientTD.a"
  sh "cp -p Output/Release-iphoneos/*.h Output/Release-iphoneos/include/TreasureData/* Output/TreasureData/"
  sh "zip -r Output/TreasureData.zip Output/TreasureData"
end
