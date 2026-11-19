#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cometchat_uikit_shared.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cometchat_uikit_shared'
  s.version          = '5.3.0'
  s.summary          = 'This package contains shared resources for CometChat Chat and Calling UIKits'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'https://cometchat.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CometChat' => 'help@cometchat.com' }
  s.source           = { :path => '.' }
  # Sources live under the Swift Package Manager layout so the plugin builds
  # under both CocoaPods and SPM.
  s.source_files = 'cometchat_uikit_shared/Sources/cometchat_uikit_shared/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
