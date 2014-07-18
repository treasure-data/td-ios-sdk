require 'open-uri'
require 'json'

namespace :keen do
  desc "Fetch KeenClient project from github"
  task :fetch, :revision do |t, args|
    revision = args[:revision] ? args[:revision] : 'td'
    sh "git clone https://github.com/treasure-data/KeenClient-iOS.git keenclient" unless Dir.exist? 'keenclient'
    cd 'keenclient' do
      sh "git fetch"
      sh "git checkout #{revision}"
      sh "git pull"
    end
  end

  desc "Create the KeenClient static liabrary and header files"
  task :build, :path do |t, args|
    cd args[:path] do
      lib_dir = File.join(t.application.original_dir, 'Libraries')
      header_dir = File.join(t.application.original_dir, 'Headers', "KeenClient")
      sh "rm -rf build"
      sh "xcodebuild -sdk iphoneos"
      sh "xcodebuild -sdk iphonesimulator"

      sh "rm -rf #{lib_dir}"
      sh "mkdir -p #{lib_dir}"
      sh "cp -p build/Release-iphoneos/libKeenClient.a #{File.join(lib_dir, "libKeenClient-device.a")}"
      sh "cp -p build/Release-iphonesimulator/libKeenClient.a #{File.join(lib_dir, "libKeenClient-simulator.a")}"

      sh "rm -rf #{header_dir}"
      sh "mkdir -p #{header_dir}"
      sh "cp -p build/Release-iphoneos/usr/local/include/* #{header_dir}"
    end
  end

  desc "Fetch and Build KeenClient with default setting(revision=td)"
  task :make do
    Rake::Task['keen:fetch'].execute
    Rake::Task['keen:build'].execute(:path => 'keenclient')
  end
end

