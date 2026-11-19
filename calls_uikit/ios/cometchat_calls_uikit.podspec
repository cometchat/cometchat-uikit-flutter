#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cometchat_calls_uikit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cometchat_calls_uikit'
  s.version          = '5.1.0'
  s.summary          = 'Flutter plugin featuring custom audio and video call widgets. Integrate seamlessly with Cometchat Chat UI Kit or use independently for streamlined development.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'https://cometchat.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CometChat' => 'help@cometchat.com' }
  s.source           = { :path => '.' }
  # Sources live under the Swift Package Manager layout so the plugin builds
  # under both CocoaPods and SPM.
  s.source_files = 'cometchat_calls_uikit/Sources/cometchat_calls_uikit/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
