#
# Be sure to run `pod lib lint sofia-sip-library.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'sofia-sip-library'
  s.version          = '1.12.11.5'
  s.summary          = 'Sofia SIP library.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Sofia SIP library built for iOS to create communication Apps powered by SIP.
                       DESC

  s.homepage         = 'http://sofia-sip.sourceforge.net/'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'LGPL', :file => 'LICENSE' }
  s.author           = 'Nokia Research Center'
  s.platform         = :ios
  #s.source           = { :git => 'https://github.com/<GITHUB_USERNAME>/sofia-sip-library.git', :tag => s.version.to_s }
  s.source           = { :http => 'https://github.com/RestComm/restcomm-ios-sdk/releases/download/v1.0.0-beta.4/sofia-sip-framework.zip' }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'
  #s.ios.vendored_library = 'Libraries/lib/libsofia-sip-ua.a'
  s.ios.vendored_frameworks = 'Frameworks/sofiasip.framework'

  #s.source_files = 'Libraries/include/sofia-sip-1.12/**/*.h'
  #s.header_mappings_dir = 'Libraries/include/sofia-sip-1.12'
  s.source_files = 'Frameworks/sofiasip.framework/Headers/*.h'
  s.public_header_files = 'Frameworks/sofiasip.framework/Headers/*.h'
  s.header_mappings_dir = 'Frameworks/sofiasip.framework/Headers'
  
  # s.resource_bundles = {
  #   'sofia-sip-library' => ['sofia-sip-library/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  #s.public_header_files = 'Libraries/include/sofia-sip-1.12/**/*.h'
  #s.public_header_files = 'Libraries/include/sofia-sip-1.12/sofia-resolv Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
