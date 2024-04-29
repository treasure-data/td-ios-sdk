platform :ios, '12.0'
use_frameworks!

target 'TreasureData' do
  pod 'KeenClientTD', '= 4.1.1'
  pod 'GZIP', '= 1.3.2'
end

target 'TreasureDataTests' do
end

post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      end
    end
  end
end
