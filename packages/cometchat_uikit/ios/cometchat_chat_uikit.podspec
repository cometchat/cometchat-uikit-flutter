#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cometchat_chat_uikit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cometchat_chat_uikit'
  # Keep in step with `version:` in ../pubspec.yaml.
  s.version          = '6.2.0'
  s.summary          = 'CometChat Flutter UI KIt'
  s.description      = <<-DESC
CometChat Flutter UI KIt
                       DESC
  s.homepage         = 'https://www.cometchat.com/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CometChat' => 'help@cometchat.com'  }
  s.source           = { :path => '.' }
  # Same sources Package.swift compiles, so CocoaPods and SPM never diverge.
  # Scoped to Sources/ so Package.swift itself is not swept in as a source file.
  s.source_files = 'cometchat_chat_uikit/Sources/cometchat_chat_uikit/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Apple privacy manifest. Ships as its own bundle so it is picked up by
  # Xcode's privacy report and by App Store Connect's manifest scan. Under SPM
  # the same file is declared as a target resource in Package.swift.
  s.resource_bundles = {'cometchat_chat_uikit_privacy' => ['cometchat_chat_uikit/Sources/cometchat_chat_uikit/PrivacyInfo.xcprivacy']}

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
