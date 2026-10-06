# The iOS plugin

```
ios/
├── cometchat_chat_uikit.podspec        CocoaPods entry point
└── cometchat_chat_uikit/
    ├── Package.swift                   Swift Package Manager entry point
    └── Sources/cometchat_chat_uikit/
        ├── SwiftCometchatChatUikitPlugin.swift
        ├── AudioRecorder.swift
        ├── Toast.swift
        └── PrivacyInfo.xcprivacy
```

Both build systems compile the same three Swift files and ship the same privacy
manifest. There is no second copy of anything.

## Why the nested directory

Flutter discovers a plugin's Swift package at
`ios/<plugin_name>/Package.swift`, and the package, its target and the source
directory must all be named for the plugin. That is why the path repeats
`cometchat_chat_uikit`. The sources used to sit in `ios/Classes/`; they moved
here so that SPM could find them without CocoaPods losing them.

## Which one a host app uses

Nothing to configure. Apps with Swift Package Manager enabled
(`flutter config --enable-swift-package-manager`) resolve `Package.swift`; every
other app keeps resolving the podspec. Flutter chooses per app, and the Kit
supports both for as long as Flutter does.

## Changing the sources

Add or rename a `.swift` file under `Sources/cometchat_chat_uikit/` and both
build systems pick it up — the podspec globs
`cometchat_chat_uikit/Sources/cometchat_chat_uikit/**/*.swift` and SPM takes the
whole target directory. The glob deliberately starts at `Sources/` so that
`Package.swift` is not swept in as a source file.

Adding a **resource** needs both sides updated: a `.process(…)` entry in
`Package.swift` and an `s.resource_bundles` entry in the podspec. The privacy
manifest is the worked example.

## Verifying a change

```bash
swift package --package-path chat_uikit/ios/cometchat_chat_uikit dump-package
```

```bash
plutil -lint chat_uikit/ios/cometchat_chat_uikit/Sources/cometchat_chat_uikit/PrivacyInfo.xcprivacy
```

Neither proves a build. The real check is an app that embeds the Kit building
and archiving both ways — see [PRIVACY.md](PRIVACY.md) for the App Store Connect
half of it.
