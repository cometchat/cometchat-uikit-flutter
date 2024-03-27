#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cometchat_chat_uikit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cometchat_chat_uikit'
  s.version          = '4.3.0'
  s.summary          = 'CometChat Flutter UI KIt'
  s.description      = <<-DESC
CometChat Flutter UI KIt
                       DESC
  s.homepage         = 'https://www.cometchat.com/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'shantanu.khare@cometchat.com'  }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
