// swift-tools-version: 5.9
//
// Swift Package Manager manifest for the CometChat Flutter Chat UI Kit.
//
// Flutter picks this up automatically when a host app has SPM enabled
// (`flutter config --enable-swift-package-manager`); apps still on CocoaPods
// keep building from ../cometchat_chat_uikit.podspec. Both build systems read
// the same sources under Sources/cometchat_chat_uikit, so there is one copy of
// the code and one copy of the privacy manifest.

import PackageDescription

let package = Package(
    name: "cometchat_chat_uikit",
    platforms: [
        // Matches `s.platform` in the podspec and the Flutter 3.38.9 floor
        // declared in ../../pubspec.yaml.
        .iOS("13.0")
    ],
    products: [
        .library(name: "cometchat-chat-uikit", targets: ["cometchat_chat_uikit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "cometchat_chat_uikit",
            resources: [
                // Apple privacy manifest. `.process` puts it at the root of the
                // target's resource bundle, which is where Xcode's privacy
                // report and App Store Connect's scan expect to find it.
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
