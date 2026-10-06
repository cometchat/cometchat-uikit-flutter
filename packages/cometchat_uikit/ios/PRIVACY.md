# Apple privacy manifest — what this Kit declares

`cometchat_chat_uikit/Sources/cometchat_chat_uikit/PrivacyInfo.xcprivacy` ships
with the Kit under both build systems — as a resource bundle
(`cometchat_chat_uikit_privacy`) under CocoaPods, and as a target resource under
Swift Package Manager. Xcode folds it into your app's privacy report
automatically; you do not need to copy anything.

## What the Kit declares

| Key | Value | Why |
| --- | --- | --- |
| `NSPrivacyTracking` | `false` | The Kit does no tracking and defines no tracking domains. |
| `NSPrivacyCollectedDataTypes` | empty | The Kit renders data your app has already given the CometChat SDK. It collects nothing on its own behalf. |
| `NSPrivacyAccessedAPITypes` | `FileTimestamp` / `C617.1` | Attachments and voice notes are staged in the app's own container and their existence and size are read back before rendering or export. |

## What it deliberately does not declare

- **`UserDefaults` (`CA92.1`)** — the Kit's iOS plugin contains no `UserDefaults`
  access and the package does not depend on `shared_preferences`. Declaring the
  category here would be a false declaration. If your app or another SDK uses
  `UserDefaults`, declare it in that manifest.
- **Disk space, system boot time, active keyboards** — not used.
- **Collected data types** — the CometChat Chat and Calls SDKs declare their own
  collection, and your app declares what it collects from your users.

## What you still have to do

The Kit's Dart layer, and the Dart packages it depends on, are ahead-of-time
compiled into **your** app binary (`App.framework`), not into this pod. A
manifest in a pod cannot cover code that lands in your binary. So if your app
does not already declare it, add `FileTimestamp` / `C617.1` to your app-level
`PrivacyInfo.xcprivacy` as well.

Flutter's own engine (`Flutter.framework`) ships a manifest covering the
`dart:io` primitives, so in most projects this is already satisfied. Verify
rather than assume: in Xcode, **Product → Archive**, then right-click the
archive → **Generate Privacy Report**.

## Verifying a change to this file

```bash
plutil -lint chat_uikit/ios/cometchat_chat_uikit/Sources/cometchat_chat_uikit/PrivacyInfo.xcprivacy
```

The end-to-end check is the one that counts: archive a test app that embeds the
Kit and upload it to App Store Connect. A missing or wrong declaration comes
back as **ITMS-91053 (missing API declaration)** or **ITMS-91061 (missing
privacy manifest)** in the post-upload email.
