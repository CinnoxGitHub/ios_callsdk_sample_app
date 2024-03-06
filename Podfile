# Uncomment the next line to define a global platform for your project
# platform :ios, '13.0'

source 'https://github.com/CocoaPods/Specs'

use_frameworks!

target 'CinnoxCallTester' do
  pod 'M800CallSDK', '4.3.0.63'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
        end
    end
end
