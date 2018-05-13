require 'open-uri'
require 'json'

desc "Clean output directory"
task :clean do
  rm_rf('Podfile.lock')
  rm_rf('Pods')
  rm_rf('Output')
end

task :build_for_device do
  sh('xcodebuild -workspace TreasureData.xcworkspace -scheme TreasureData -configuration Release -sdk iphoneos SYMROOT=$(PWD)/Output OTHER_CFLAGS="-fembed-bitcode" CLANG_ENABLE_MODULE_DEBUGGING=NO GCC_PRECOMPILE_PREFIX_HEADER=NO DEBUG_INFORMATION_FORMAT="DWARF with dSYM"')
  sh('cd Output/Release-iphoneos && ln -s KeenClientTD/libKeenClientTD.a libKeenClientTD.a')
end

task :build_for_simulator do
  sh('xcodebuild -workspace TreasureData.xcworkspace -scheme TreasureData -configuration Release -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 6s" SYMROOT=$(PWD)/Output OTHER_CFLAGS="-fembed-bitcode" CLANG_ENABLE_MODULE_DEBUGGING=NO GCC_PRECOMPILE_PREFIX_HEADER=NO DEBUG_INFORMATION_FORMAT="DWARF with dSYM"')
  sh('cd Output/Release-iphonesimulator && ln -s KeenClientTD/libKeenClientTD.a libKeenClientTD.a')
end

task :pod_install do
  Rake::Task[:clean].invoke
  sh('pod install')
end

desc "Create static libraries"
task :build do
  Rake::Task[:pod_install].invoke
  Rake::Task[:build_for_device].invoke
  Rake::Task[:build_for_simulator].invoke
end

desc "Create static libraries for Unity"
task :unity_package do
  Rake::Task[:build].invoke
  output_file = File.expand_path("../Output/Unity/libTreasureData.a", __FILE__)
  mkdir_p(File.dirname(output_file))
  source_libs_dir = 'Output/Release-iphoneos'
  if ENV['universal'] and ENV['universal'] != 'false'
      source_libs_dir = 'Output/Universal'
      create_universal_library(source_libs_dir)
  end
  sh "libtool -static -o #{output_file} #{source_libs_dir}/libKeenClientTD.a #{source_libs_dir}/libTreasureData.a"
end

desc "Create package"
task :package do
  Rake::Task[:build].invoke

  output_dir = File.expand_path("../Output/TreasureData", __FILE__)
  create_universal_library(output_dir)
  copy_header_file(output_dir)

  cd File.expand_path("../Output", __FILE__)
  zipfile = 'TreasureData.zip'
  rm_f(zipfile)
  sh("zip -ry #{zipfile} TreasureData")
end

desc "Create framework"
task :framework do
  Rake::Task[:build].invoke

  framework_dir = File.expand_path("../Output/Framework/TreasureData-iOS-SDK.framework", __FILE__)
  rm_rf(framework_dir)

  version_base_dir = File.join(framework_dir, 'Versions')
  version_dir = File.join(version_base_dir, 'A')
  mkdir_p(version_dir)

  libs = create_universal_library(version_dir)
  sh "libtool -static -o #{File.join(version_dir, 'TreasureData-iOS-SDK')} #{libs.join(' ')}"
  libs.each do |f|
    rm_f(f)
  end

  header_dir = File.join(version_dir, 'Headers')
  mkdir_p(header_dir)
  copy_header_file(header_dir)

  resource_dir = File.join(version_dir, 'Resources')
  mkdir_p(resource_dir)
  info_plist = create_info_plist(resource_dir)

  cd framework_dir
  version_dir_in_fw = File.join('Versions', 'Current')
  ln_sf(File.join(version_dir_in_fw, 'TreasureData-iOS-SDK'), pwd)
  ln_sf(File.join(version_dir_in_fw, 'Headers'), pwd)
  ln_sf(File.join(version_dir_in_fw, 'Resources'), pwd)
  ln_sf(File.join(version_dir_in_fw, 'Resources', 'Info.plist'), pwd)

  cd 'Versions'
  ln_sf('A', 'Current')

  cd File.expand_path("../Output/Framework", __FILE__)
  zipfile = 'TreasureData-iOS-SDK.framework.zip'
  rm_f(zipfile)
  sh("zip -ry #{zipfile} TreasureData-iOS-SDK.framework")
end

def create_universal_library(output_dir)
  output_file_libkeen = File.join(output_dir, 'libKeenClientTD.a')
  output_file_libtd = File.join(output_dir, 'libTreasureData.a')
  mkdir_p(output_dir)
  sh("lipo -create Output/Release-*/libKeenClientTD.a -output #{output_file_libkeen}")
  sh("lipo -create Output/Release-*/libTreasureData.a -output #{output_file_libtd}")
  [output_file_libkeen, output_file_libtd]
end

def copy_header_file(output_dir)
  keen_header_dir = File.join(output_dir, 'KeenClientTD')
  mkdir_p(keen_header_dir)
  sh("cp -p Output/Release-iphoneos/include/TreasureData/* #{output_dir}")
  sh("cp -p Output/Release-iphoneos/KeenClientTD/*.h #{keen_header_dir}")
end

def create_info_plist(output_dir)
  output_file = File.join(output_dir, 'Info.plist')
  File.open(output_file, 'w') do |f|
    f.write(<<-EOF)
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleExecutable</key>
	<string>TreasureData</string>
	<key>CFBundleIconFile</key>
	<string></string>
	<key>CFBundleIdentifier</key>
	<string>com.treasuredata.TreasureData</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>TreasureData</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.8.0</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>1.8.0</string>
	<key>NSHumanReadableCopyright</key>
	<string>TreasureData. All rights reserved.</string>
	<key>NSPrincipalClass</key>
	<string></string>
</dict>
</plist>
EOF
  end
  output_file
end

