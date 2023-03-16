<div style="width:100%">
	<div style="width:50%; display:inline-block">
		<p align="center">
         <img align="center" src="https://avatars2.githubusercontent.com/u/45484907?s=200&v=4"/>
		</p>
	</div>
</div>
<br></br><br></br>

# Flutter Chat UI Kit

CometChat Flutter UI Kit is a collection of custom UI Components designed to build text , chat  features in your application.
The UI Kit is developed to keep developers in mind and aims to reduce development efforts significantly<br/><br/>

[![Platform](https://img.shields.io/badge/Platform-Flutter-brightgreen.svg)](#)
[![Platform](https://img.shields.io/badge/Language-dart-yellowgreen.svg)](#)
![Version](https://shields.io/badge/version-v3.0.3--pluto.alpha.1-orange)
![Twitter Follow](https://img.shields.io/twitter/follow/cometchat?style=social)

<img align="center" src="https://files.readme.io/b81d92b-UI_Kit__2.png"/>

<hr/>

## Prerequisites :star:
Before you begin, ensure you have met the following requirements:<br/>
✅ &nbsp; You have `Android Studio` or  `Xcode` installed in your machine.<br/>
✅ &nbsp; You have a `Android Device or Emulator` with Android Version 5.0 or above.<br/>
✅ &nbsp; You have a `IOS Device or Emulator` with IOS 11.0 or above.<br/>
✅ &nbsp; You have read [CometChat Key Concepts](https://www.cometchat.com/docs/flutter-chat-sdk/key-concepts).<br/>

<hr/>

## Installing CometChat Flutter UI kit
## Setup :wrench:

To setup Flutter Chat UI Kit, you  need to first register on CometChat Dashboard. [Click here to sign up](https://app.cometchat.com/signup).

### i. Get your Application Keys :key:

1. Create a new app: Click **Add App** option available  →  Enter App Name & other information  → Create App
2. You will find `APP_ID`, `AUTH_KEY` and `REGION` key at top in **QuickStart** section or else go to "API & Auth Keys" section and copy the `APP_ID`, `AUTH_KEY` and `REGION` key from the "Auth Only API Key" tab.
   <img align="center" src="https://files.readme.io/4b771c5-qs_copy.jpg"/>


### ii. Add the CometChat UI Kit Dependency

**Step 1 -** To use this plugin, add flutter_chat_ui_kit as a dependency in your pubspec.yaml file.

<table><td>

```groovy
    flutter_chat_ui_kit:
```

</td></table>

**Step 2-** add the following code  to podfile inside IOS section of your app<br/>

<table><td>

```groovy
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    <COPY FROM HERE------------>
    target.build_configurations.each do |build_configuration|
    build_configuration.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64 i386'
    build_configuration.build_settings['ENABLE_BITCODE'] = 'NO'
    end
    <COPY TILL HERE------------>
  end
end
```

</td></table>

**Step 3-** Open app/build.gradle file and change min SDk version to 33 <br/>

<table><td>

```groovy
        defaultConfig {
            // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
            applicationId <YOUR_PACKAGE_NAME>
            minSdkVersion 33
            targetSdkVersion <TARGET_SDK_Version>
            versionCode flutterVersionCode.toInteger()
            versionName flutterVersionName
            }

lintOptions {
    disable 'InvalidPackage'
    disable "Instantiatable"
    checkReleaseBuilds false
    abortOnError false
  }
```


</td></table>

**Step 4-** For IOS change ios deployment target to 11 or higher <br/>

**Step 5-** For Ios navigate to your IOS folder in terminal or CMD and do `pod install` . For apple chip system use rositta terminal. <br/>

**Step 5-** To import use <br/>
```dart
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

```


<hr/>

## Configure CometChat UI kit

### i. Initialize CometChat 🌟
The init() method initializes the settings required for CometChat. We suggest calling the init() method on app startup, preferably in the init() method of the Home class.

<table><td>

```dart

import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';


String appID = "APP_ID"; // Replace with your App ID
String region = "REGION"; // Replace with your App Region ("eu" or "us")
static const String authKey = "Auth key"; //Replace  with your auth key

 UIKitSettings authSettings = (UIKitSettingsBuilder()
          ..subscriptionType = CometChatSubscriptionType.allUsers
          ..region = region
          ..autoEstablishSocketConnection = true
          ..appId = appID
          ..apiKey = authKey)
        .build();

    CometChatUIKit.init(
            authSettings: authSettings,
            onSuccess: (String successMessage){
              debugPrint("Initialization completed successfully  $successMessage");
            },
            onError: (CometChatException e) {
              debugPrint("Initialization failed with exception: ${e.message}");
            }
     );
```

</td></table>

| :information_source: &nbsp; <b> Note: Make sure to replace `region`, `appID` and `authKey` with your credentials.</b> |
|------------------------------------------------------------------------------------------------------------|

### ii. Create User 👤
Once initialisation is successful, you will need to create a user. You need to user createUser() method to create user on the fly.
<table><td>

```dart
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';


User user = User(uid: "usr1", name: "Kevin");

CometChatUIKit.createUser(user, onSuccess: (User user) {
   debugPrint("Create User succesfull ${user}");
}, onError: (CometChatException e) {
   debugPrint("Create User Failed with exception ${e.message}");
});

```

</td></table>
| :information_source: &nbsp; <b>Note -  Make sure that UID and name are specified as these are mandatory fields to create a user.</b> |
|------------------------------------------------------------------------------------------------------------|


### iii. Login User 👤
Once you have created the user successfully, you will need to log the user into CometChat using the login() method.

<table><td>

```dart
String UID = "user_id"; // Replace with the UID of the user to login

final user = await CometChat.getLoggedInUser();//checking if already logged in
if (user == null) {

  await CometChatUIKit.login(UID, onSuccess: (User loggedInUser) {
         debugPrint("Login Successful : $user" );
       }, onError: (CometChatException e) {
         debugPrint("Login failed with exception:  ${e.message}");
       });
}else{
//Already logged in
}
```

</td></table>

| :information_source: &nbsp; <b>Note - The login() method needs to be called only once. Use this method while development </b> |
|------------------------------------------------------------------------------------------------------------|

<hr/>

📝 Please refer to our [Developer Documentation](https://www.cometchat.com/docs/flutter-chat-sdk/overview) for more information on how to configure the CometChat Pro SDK and implement various features using the same.

<hr/>


## Troubleshooting

- To read the full documentation on Flutter UI Kit integration visit our [Documentation](https://www.cometchat.com/docs/flutter-uikit-beta/overview)  .

- Facing any issues while integrating or installing the UI Kit please <a href="https://app.cometchat.com/"> connect with us via real time support present in CometChat Dashboard.</a>.

---


## Contributors

Thanks to the following people who have contributed to this project:

[⚔️ @shantanukhare 🛡](https://github.com/Shantanu-CometChat) <br>
[⚔️ @nabhodiptagarai 🛡](https://github.com/nabhodiptagarai) <br>

---

## :mailbox: Contact

Contact us via real time support present in [CometChat Dashboard.](https://app.cometchat.com/)

---

