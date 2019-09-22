#
# Be sure to run `pod lib lint ZPayManager.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s| 
  s.name             = 'ZPayManager'
  s.version          = '0.1.1'
  s.summary          = 'ZPayManager 支付宝、微信支付 简便的管理类'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

    s.homepage         = 'https://github.com/zhwx600/ZPayManager'
    # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'zhwx600' => 'zhwx600@qq.com' }
    s.source           = { :git => 'https://github.com/zhwx600/ZPayManager.git', :tag => s.version.to_s }
    # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

    s.ios.deployment_target = '8.0'

    s.source_files = 'ZPayManager.{h,m}'
    s.public_header_files = 'ZPayManager.h'

s.subspec 'OpenSSL' do |ss|
ss.source_files = 'OpenSSL/**/*.h'
ss.public_header_files = 'OpenSSL/**/*.h'
ss.header_dir          = 'openssl'
ss.preserve_paths      = 'OpenSSL/libcrypto.a', 'OpenSSL/libssl.a'
ss.vendored_libraries  = 'OpenSSL/libcrypto.a', 'OpenSSL/libssl.a'
end

s.subspec 'ZWeChat' do |ss|
ss.source_files = 'ZWeChat/*.h'
ss.public_header_files = 'ZWeChat/*.h'
ss.frameworks = "Foundation", "UIKit", "SystemConfiguration", "Security", "CoreTelephony", "CFNetwork"
ss.libraries = "z", "sqlite3.0", "c++"
ss.requires_arc = true
ss.vendored_libraries  = 'ZWeChat/libWeChatSDK.a'
end

s.subspec 'ZAlipay' do |ss|
    ss.resources = 'ZAlipay/AlipaySDK.bundle'
    ss.vendored_frameworks = "ZAlipay/AlipaySDK.framework"
    ss.frameworks          = "SystemConfiguration", "CoreTelephony", "QuartzCore", "CoreText", "CoreGraphics", "UIKit", "Foundation", "CFNetwork", "CoreMotion"
    ss.libraries = "z", "c++"
    ss.requires_arc = true

    ss.subspec 'Model' do |s3|
    s3.source_files = 'ZAlipay/Model/**/*'
    s3.public_header_files = 'ZAlipay/Model/**/*.h'
    end

    ss.subspec 'Utils' do |s3|
    s3.source_files = 'ZAlipay/Utils/**/*'
    s3.public_header_files = 'ZAlipay/Utils/**/*.h'
    s3.dependency 'ZPayManager/OpenSSL'
    end

end

  
  # s.resource_bundles = {
  #   'ZPayManager' => ['ZPayManager/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
