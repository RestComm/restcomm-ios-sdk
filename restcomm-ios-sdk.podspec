#
# Be sure to run `pod lib lint RestCommClient.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'restcomm-ios-sdk'
  #s.version          = '0.9.1'
  s.version          = '1.0.0-beta.4.2'
  s.summary          = 'Restcomm iOS SDK'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
iOS Mobile SDK to easily integrate communication features (messaging, presence, voice, video, screensharing) based on RestComm into native Mobile Applications. More more information on Restcomm, please check http://www.restcomm.org/
                       DESC

  s.homepage         = 'https://github.com/RestComm/restcomm-ios-sdk'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = "AGPL version 3"
  s.author           = 'Telestax Inc.'
  #s.source           = { :git => 'https://github.com/RestComm/restcomm-ios-sdk.git', :tag => 'v1.0.0-beta.4.2' }
  s.source           = { :git => 'https://github.com/RestComm/restcomm-ios-sdk.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'RestCommClient/Classes/**/*'

  # Trying to add sofia and webrtc directly as vendored libs to restcomm sdk, to avoid the issue when sofia is separate pod
  #s.source_files = 'RestCommClient/Classes/**/*', 'dependencies/include/sofia-sip-1.12/**/*.h'
  #s.header_mappings_dir = 'dependencies/include/sofia-sip-1.12'
  #s.ios.vendored_frameworks = 'dependencies/WebRTC.framework'
  #s.ios.vendored_library = 'dependencies/lib/libsofia-sip-ua.a'
  
  # s.resource_bundles = {
  #   'RestCommClient' => ['RestCommClient/Assets/*.png']
  # }

  # Libraries this pod depends on. Notice the c++ dependency to be able to build .mm files
  s.libraries = 'c++', 'sqlite3', 'resolv'
  s.public_header_files = 'RestCommClient/Classes/RC*.h', 'RestCommClient/Classes/RestCommClient.h'
  #s.private_header_files = 'RestCommClient/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'

  #s.public_header_files = 'Libraries/include/sofia-sip-1.12/**/*.h'
  #s.public_header_files = 'Frameworks/WebRTC.framework/Headers/*.h'
  # Pods this pod depends on
  
  # This causes 'target has transitive dependencies that include static binaries'. Let's take it out for now and include it in the Podfile of the App instead
  #s.ios.dependency 'sofia-sip-library', '~> 1.12.11.2'
  s.ios.dependency 'sofia-sip-library'
  #s.ios.dependency 'BoringSSL'
  s.ios.dependency 'webrtc-framework'
  s.ios.dependency 'TestFairy'
  s.xcconfig = {
     'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/Headers/Public/sofia-sip-library/sofiasip"', 
     #'USER_HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/Headers/Public/sofia-sip-library/sofiasip"'
  }

end
