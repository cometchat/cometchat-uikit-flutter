## 5.1.0

## New
- None

## Enhancements
- Added Swift Package Manager support to the iOS plugin, used by default from Flutter 3.44 and available on Flutter 3.38 to 3.43 with `flutter config --enable-swift-package-manager`. CocoaPods remains supported and works unchanged. On Flutter 3.38 to 3.40, also add a `video_player_avfoundation: 2.9.7` dependency override.
- Updated `cometchat_sdk` to version `4.1.5`, `cometchat_calls_sdk` to version `4.2.3` and `cometchat_uikit_shared` to version `5.3.0`, which removes the Git LFS requirement for Swift Package Manager builds.

## Fixes
- Fixed Android build failures in apps that use Android Gradle Plugin 9, the default from Flutter 3.44, by raising `compileSdk` to 34.

## Breaking Changes
- Raised the minimum Flutter version from 2.5.0 to 3.38.0. **Apps must use Flutter 3.38 or later to update to this version.**

## 5.0.16 

## Enhancements
- Improved `CometChatCallButtons` customization support by applying `voiceCallButtonPadding` and `videoCallButtonPadding` styles directly to the underlying `IconButton` components.
- Enhanced the spacing between voice and video call actions in `CometChatCallButtons` by adding an 8px gap for improved visual separation and usability.

## 5.0.15

## Fixes
- Fixed an issue where call screens rendered behind system UI elements on devices with notches or edge insets because the underlying calling widget ignored external safe area constraints.
- Resolved a problem where applying `SafeArea`, `Padding`, or `MediaQuery` at the app level had no effect on call screens due to full-screen rendering behavior within the SDK.

## 5.0.14

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.2.3`
- Improved stability by safely handling API calls to avoid conflicts during UI rebuilds.
- Enhanced the handling in 1-on-1 calls ensuring calls close as expected when the other participant leaves.

## 5.0.13

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.2.1`.
- Improved iOS app lifecycle handling and added support for Flutter version `3.41`.
- Enhanced the Call Logs screen to refresh automatically after the internet connection is restored.

## 5.0.12

## Enhancements
- Updated `cometchat_sdk` to version `4.0.33`.
- Updated `cometchat_uikit_shared` to version `5.1.8`.
- Updated `cometchat_calls_sdk` to version `4.2.2`.

## Fixes
- Fixed the Retry button to reattempt network requests and refresh data when the internet connection is restored.

## 5.0.11

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.1.6`.

## 5.0.10

## Enhancements
- Updated `cometchat_sdk` to version `4.0.30`.
- Updated `cometchat_uikit_shared` to version `5.1.5`.

## 5.0.9

## Enhancements
- Updated `cometchat_sdk` to version `4.0.29`.
- Updated `cometchat_uikit_shared` to version `5.1.4`.

## 5.0.8

## Enhancements
- Updated `cometchat_sdk` to version `4.0.28`.
- Updated `cometchat_uikit_shared` to version `5.1.3`.
- Updated `cometchat_calls_sdk` to version `4.2.0`.

## 5.0.7

## Enhancements
- Updated `cometchat_sdk` to version `4.0.27`.
- Updated `cometchat_uikit_shared` to version `5.1.2`.
- Updated `cometchat_calls_sdk` to version `4.1.2`.

## Fixes
- Fixed the `onLoad` callback in the `CometChatCallLogs` widget not being triggered when call logs were loaded.

## 5.0.6

## Enhancements
- Updated `cometchat_sdk` to version `4.0.26`.
- Updated `cometchat_uikit_shared` to version `5.1.1`.

## Fixes
- Resolved a multi-device issue where incoming call screens appeared on all devices despite the call being accepted on one.
- Fixed video call functionality in landscape mode for reliable video communication.

## 5.0.5

## Enhancements
- Updated `cometchat_sdk` to version `4.0.24`.
- Updated `cometchat_uikit_shared` to version `5.0.5`.

## Fixes
- Fixed an issue in the where initiating a default group call failed due to a missing asset reference.
- Corrected the display of icons for incoming and missed calls in call logs and chat lists to ensure accuracy.

## 5.0.4

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.0.4`.

## Fixes
- Updated call icons in the Call tab to distinguish between incoming and missed calls more clearly.
- Resolved an issue where the app was rejected due to the use of deprecated media permissions. The permissions have been updated to comply with current platform requirements.

## 5.0.3

## Enhancements
- Updated `cometchat_sdk` to version `4.0.23`.
- Updated `cometchat_uikit_shared` to version `5.0.3`.

## Fixes
- Fixed an issue where the ringtone continued ringing even after the call had ended following a single ring.

## 5.0.2

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.0.2`.

## Fixes
- Resolved a crash that occurred when users double-tapped the "End Call" button and then immediately initiated a new call.

## 5.0.1

## Enhancements
- Updated `cometchat_sdk` to version `4.0.22`.
- Updated `cometchat_uikit_shared` to version `5.0.1`.
- Updated `cometchat_calls_sdk` to version `4.1.0`.

## Fixes
- Addressed an issue preventing call initiation after the app was force-closed during an ongoing call.
- Fixed a bug where the call screen remained visible after the device screen was turned off.

## 5.0.0

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.0.0`.
- Updated properties for all components to improve flexibility, customization, and overall usability.
- Enhanced the **Call Logs Component** with refined properties for better filtering and call log management.
- Improved the **Incoming Call Component** by introducing configurable properties for handling call notifications.
- Optimized the **Call Buttons Component**, allowing better control over button actions and styles.
- Upgraded the **Outgoing Call Component** with new properties to support call customization.

## 5.0.0-beta.2

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.0.0-beta.2`.
- Updated properties for all components to improve flexibility, customization, and overall usability.
- Enhanced the **Call Logs Component** with refined properties for better filtering and call log management.
- Improved the **Incoming Call Component** by introducing configurable properties for handling call notifications.
- Optimized the **Call Buttons Component**, allowing better control over button actions and styles.
- Upgraded the **Outgoing Call Component** with new properties to support call customization.

## Fixes
- **Call Icon Behavior**: Fixed an issue where tapping the call icon displayed call details instead of initiating a call.

## 5.0.0-beta.1

## New
- **Revamped UI**: Experience a fresh, modern design for improved visual appeal and consistency. The updated look enhances usability and engagement.
- **Restructured Components**: Enjoy a redesigned component architecture that improves scalability, making it easier to build and maintain modular designs.

## Enhancements
- **Optimized User Experience**: Interactions have been streamlined to provide a smoother, more intuitive experience, reducing friction during use.
- **Advanced Styling and Theming**: Gain greater flexibility with enhanced customization options, allowing you to tailor appearances to suit your brand effortlessly.
- **Simplified Integration**: Set up faster and with ease thanks to a more intuitive, streamlined integration process.

## Fixes
- None

## Removals
- **Style Props Removed**: Style-specific props have been deprecated to encourage the use of modern theming practices, which offer more robust and scalable customization options.

## 5.0.0-alpha.1

## New
- **Revamped UI**: Experience a fresh, modern design for improved visual appeal and consistency. The updated look enhances usability and engagement.
- **Restructured Components**: Enjoy a redesigned component architecture that improves scalability, making it easier to build and maintain modular designs.

## Enhancements
- **Optimized User Experience**: Interactions have been streamlined to provide a smoother, more intuitive experience, reducing friction during use.
- **Advanced Styling and Theming**: Gain greater flexibility with enhanced customization options, allowing you to tailor appearances to suit your brand effortlessly.
- **Simplified Integration**: Set up faster and with ease thanks to a more intuitive, streamlined integration process.

## Fixes
- None

## Removals
- **Style Props Removed**: Style-specific props have been deprecated to encourage the use of modern theming practices, which offer more robust and scalable customization options.

## 4.3.4

**Enhancements**
- Added a check to ensure users cannot navigate back from the group call screen, preventing multiple views of the same user when trying to rejoin the call after going back to Message List.
- Updated `cometchat_uikit_shared` to version `4.4.9`.
- Updated `cometchat_sdk` to version `4.0.17`.


## 4.3.3
**Enhancements**
- Updated `cometchat_uikit_shared` to version `4.4.4`.
- Updated `cometchat_sdk` to version `4.0.14`.

**Fixes**
- Added logic to manually clear active call object using `CometChat.clearActiveCall()` when a call ends unexpectedly, allowing subsequent call initiation.

## 4.3.2
**New**
- Introduced real-time updates for the last message and unread count in conversations based on App setting configured via dashboard, ensuring up-to-date information is displayed.

**Enhancements**
- Updated `cometchat_uikit_shared` to version `4.4.2`.
- Updated `cometchat_sdk` to version `4.0.12`.

## 4.3.1

**Enhancements**
- The `cometchat_uikit_shared` dependency has been updated to `4.4.1` for better performance

**Fixes**
- Solved an error popup issue that occurred when the receiver clicks the accept button multiple times when an incoming call is received.

## 4.3.0
**Enhancements**
- Updated all 3rd-party plugins versions.
- Resolved all static Dart Analyser suggestions
- Added namespaces in build.gradle to avoid conflicts.

## 4.2.1
**Enhancements**
- `cometchat_sdk` dependency has been updated to version `4.0.10` for better performance.
- `cometchat_uikit_shared` dependency has been updated to `4.3.0` for better performance
- `contentView` property of `CometChatMessageTemplate` now accepts an optional `AdditionalConfigurations` object as argument to support formatting of text shown in message bubbles.

## 4.2.0
**Enhancements**
- Updated `cometchat_sdk` to version `4.0.8`
- Updated `cometchat_uikit_shared` to version `4.2.9`
- Updated `cometchat_calls_sdk` to version `4.0.4`

## 4.1.1
**New**
- Added `voiceCallIcon` property in `CometChatCallButtons` and `CallButtonsConfiguration`. This property should be used instead of `voiceCallIconURL` and `voiceCallIconPackage` which have been deprecated and should not be used
- Added `videoCallIcon` property in `CometChatCallButtons` and `CallButtonsConfiguration`. This property should be used instead of `videoCallIconURL` and `videoCallIconPackage` which have been deprecated and should not be used

**Enhancements**
- Upgraded `cometchat_sdk` to version `4.0.7`
- Upgraded `cometchat_uikit_shared` to version `4.2.6`
- Upgraded `cometchat_calls_sdk` to version `4.0.3`

**Fixes**
- Removed excess space between the voice call icon and video call icon in `CometChatCallButtons`

## 4.1.0
**Added**
- New components : `CometChatCallLogs`, `CometChatCallLogsWithDetails`, `CometChatCallLogRecordings`, `CometChatCallLogParticipants`, `CometChatCallLogHistory` , `CometChatCallLogDetails`
- Models: `CometChatCallLogDetailsOption`, `CometChatCallLogDetailsTemplate`

**Changed**
- [cometchat_calls_sdk](https://pub.dev/packages/cometchat_calls_sdk) dependency upgraded to `cometchat_calls_sdk: ^4.0.2`
- [cometchat_sdk](https://pub.dev/packages/cometchat_sdk) dependency upgraded to `cometchat_sdk: ^4.0.4`
- [cometchat_uikit_shared](https://pub.dev/packages/cometchat_uikit_shared) dependency upgraded to `cometchat_uikit_shared: ^4.1.0`

## 4.0.1
**Fixes**
- Issue with ending a user to user call

**Changed**
- [cometchat_calls_sdk](https://pub.dev/packages/cometchat_calls_sdk) dependency upgraded to `cometchat_calls_sdk: ^4.0.1`
- [cometchat_sdk](https://pub.dev/packages/cometchat_sdk) dependency upgraded to `cometchat_sdk: ^4.0.2`
- [cometchat_uikit_shared](https://pub.dev/packages/cometchat_uikit_shared) dependency upgraded to `cometchat_uikit_shared: ^4.0.2`

## 4.0.0
**Added**
- `CometChatCallingExtension` conforms to the updated `ExtensionsDataSource` class by implementing new methods `addExtension` and `getExtensionId`.
- Properties introduced in `CallBubbleStyle` to configure height, width, background color, border and border radius and join call button background of `CometChatCallBubble`

**Changed**
- [cometchat_sdk](https://pub.dev/packages/cometchat_sdk) dependency upgraded to `cometchat_sdk: ^4.0.1`
- [cometchat_uikit_shared](https://pub.dev/packages/cometchat_uikit_shared) dependency upgraded to `cometchat_uikit_shared: ^4.0.1`
- [GetX](https://pub.dev/packages/get) dependency upgraded to `get: ^4.6.5`
- Replaced implementation of `SoundManager` with `CometChatUIKit.soundManager`.
- End call flow of `CometChatOngoingCall` updated
- `CometChatIncomingCall` will now display if the call is a audio call or video call

**Removed**
- Unused imports
- Dead code

## 4.0.0-beta.1
- 🎉 First release!

