#
# Be sure to run `pod lib lint webrtc-framework.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'webrtc-framework'
  s.version          = '14493.4'
  s.summary          = 'WebRTC iOS framework.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
WebRTC framework for iOS built using Google\'s sources at https://chromium.googlesource.com/external/webrtc.
                       DESC

  s.homepage         = 'https://webrtc.org/'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'WebRTC License', :file => 'LICENSE' }
  s.author           = 'Google'
  s.platform         = :ios
  #s.source           = { :git => 'https://github.com/<GITHUB_USERNAME>/webrtc-framework.git', :tag => s.version.to_s }
  s.source           = { :http => 'https://github.com/RestComm/restcomm-ios-sdk/releases/download/v1.0.0-beta.4/webrtc-framework.zip' }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'
  s.ios.vendored_frameworks = 'Frameworks/WebRTC.framework'

  s.source_files = 'Frameworks/WebRTC.framework/Headers/*.h'
  #s.header_mappings_dir = 'Frameworks/WebRTC.framework'
  
  # s.resource_bundles = {
  #   'webrtc-framework' => ['webrtc-framework/Assets/*.png']
  # }

  s.public_header_files = 'Frameworks/WebRTC.framework/Headers/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
