<p align="center">
  <img alt="CometChat" src="https://assets.cometchat.io/website/images/logos/banner.png">
</p>

# CometChat UIKit for Flutter

CometChat UIKit for Flutter provides pre-built UI components to quickly add chat, voice, and video calling features to your Flutter application.

<p align="center">
  <img src="images/overview_cometchat_screens.png" alt="CometChat UIKit Screens">
</p>

## Repository Structure

| Directory | Description |
|-----------|-------------|
| [packages/cometchat_uikit](packages/cometchat_uikit#readme) | The open source UIKit package (local setup, structure, tests) |
| [packages/cometchat_uikit/skills](packages/cometchat_uikit/skills#readme) | Kiro AI skills for consumers and contributors |
| [examples/sample_app](examples/sample_app#readme) | Sample app demonstrating UIKit usage |
| [examples/ai_sample_app](examples/ai_sample_app#readme) | AI-powered sample app with CometChat AI agents |

## Prerequisites

- Flutter SDK >= 3.38.9
- Dart SDK >= 3.10.8
- iOS 16.0+ / Android 5.0+
- A [CometChat](https://app.cometchat.com/) account with App ID and Auth Key

## Getting Started

1. Sign up at the [CometChat Dashboard](https://app.cometchat.com/) and create a new app.
2. Note your App ID, Region, and Auth Key from the dashboard.
3. Clone this repository and navigate to the sample app:

```bash
git clone https://github.com/cometchat/cometchat-uikit-flutter.git
cd cometchat-uikit-flutter/examples/sample_app
flutter pub get
flutter run
```

4. On first launch, enter your App ID, Region, and Auth Key in the credentials screen.

## Installation

Add the UIKit to your project's `pubspec.yaml`:

```yaml
dependencies:
  cometchat_chat_uikit: ^6.1.0
```

Then run:

```bash
flutter pub get
```

## Documentation

Refer to our [official documentation](https://www.cometchat.com/docs/ui-kit/flutter/v6/overview) for detailed setup and usage guides.

## Help and Support

For bugs and feature requests in the UIKit itself, open an issue on this repository.

For account, billing, or integration questions, consult our [documentation](https://www.cometchat.com/docs/ui-kit/flutter/v6/overview), create a [support ticket](https://help.cometchat.com/hc/en-us), or seek real-time support via the [CometChat Dashboard](https://app.cometchat.com/).

## Security

To report a security vulnerability, email security@cometchat.com. Please do not open a public issue for security reports.

## License

This project is licensed under the terms of the [LICENSE](LICENSE) file.
