require 'open-uri'
require 'json'

desc "Create the static library"
task :build do
  sh "xcodebuild -workspace TreasureData.xcworkspace -scheme TreasureData -configuration Release -sdk iphoneos SYMROOT=$(PWD)/Output"
end
