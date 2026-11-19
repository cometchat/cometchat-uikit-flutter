// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "cometchat_uikit_shared",
  platforms: [
    .iOS("12.0")
  ],
  products: [
    .library(name: "cometchat-uikit-shared", targets: ["cometchat_uikit_shared"])
  ],
  // FlutterFramework is intentionally not declared: the Flutter tool only
  // generates it from Flutter 3.41, and declaring it breaks SPM builds on
  // Flutter 3.24-3.40.
  dependencies: [],
  targets: [
    .target(
      name: "cometchat_uikit_shared"
    )
  ]
)
