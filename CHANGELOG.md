## 4.5.10

**New**
- Added a new prop `hideReceipt` to hide the receipt in the message bubble and conversation’s last message.

**Enhancements**
- Updated `cometchat_sdk` to version `4.0.18`.
- If `isIncludeBlockedUsers` is set to true in the `ConversationsRequestBuilder` and the logged-in user blocks another user, the conversation is not removed from the list.

**Fixes**
- Fixed an issue in a group conversation, where if it last message was an action message it was not being marked as read which prevented the unread count from decreasing.

**Deprecations**
- Deprecated `disableReceipt` prop from `CometChatMessageList` & `CometChatConversations` component.


## 4.5.9

**New**
- The sender of a message will now see a double tick on a group message to indicate that the message has been successfully delivered to all users within that group, and a double blue tick once it has been read by all participants in the group.

**Enhancements**
- Updated `cometchat_uikit_shared` to version `4.4.9`.
- Updated `cometchat_sdk` to version `4.0.17`.

**Fixes**
- Fixed an issue where launching `CometChatMessages` resulted in the same messages being appended multiple times, causing duplicate chats.
- Fixed an issue where the `hideTimestamp` prop of `CometChatMessageList` was not working.


## 4.5.8

**Fixes**
- Fixed an issue where a custom message composer view was hiding the messages at the bottom of the message list in `CometChatThreadedMessages`.
- Fixed an issue where `GroupMembersConfiguration` was not being applied to the `CometChatGroupMembers` component when accessed through `CometChatDetails`.

## 4.5.7

**Enhancements**
- Updated `cometchat_uikit_shared` to version `4.4.7`.

**Fixes**
- Fixed a missing `auxiliaryHeaderMenu` prop in the `CometChatMessages` component.
- Fixed an issue where the `showAvatar` prop of the `CometChatMessageList` component was not working, ensuring avatars are displayed in received messages in one-to-one conversations.
- Fixed an issue where a custom empty state view could not be set in the `CometChatMessageList` component.
- Fixed an issue in the `CometChatCreateGroup` component where the selected tab background was applied only to the text and not the entire tab.

**Removals**
- Removed unnecessary location permission.

## 4.5.6

**New**
- Unveiled the ability to customize `CometChatContacts`, offering a bespoke user experience.

**Enhancements**
- Updated `cometchat_uikit_shared` to version `4.4.6`.
- Updated `cometchat_sdk` to version `4.0.16`.

**Fixes**
- Perfected the indicator color of the tab bar in `CometChatContacts` for a sleek and polished look.
- Resolved an issue where component colors weren't applied to the safe area, ensuring seamless visual consistency.
- Addressed a privacy concern where users could see typing and online status of blocked contacts within the `CometChatMessages` and `CometChatConversations` components.
- Fixed an issue where passing `disableMention` as true did not disable the mentions feature
- Fixed an issue where if the conversation type was set to users and a message was received in a group, the group was visible in the conversations list in real time.

## 4.5.5

**Enhancements**
- Updated `cometchat_uikit_shared` to version `4.4.5`.

**Fixes**
- Resolved an issue where `border` and `border-radius` style were not being applied to the `CometChatConversations` component using the `ConversationsStyle` prop.
- Resolved an issue where `border` and `border-radius` style were not being applied to the `CometChatDetails` component using the `DetailsStyle` prop.
- Resolved an issue where `border` and `border-radius` style were not being applied to the `CometChatUsersWithMessages` component using the `UsersStyle` prop.
- Resolved an issue where `border`, `border-radius` & separator color style were not being applied to the `CometChatConversationsWithMessages` component using the `ConversationsStyle` prop.
- Resolved an issue in the `CometChatConversations` component where the default error view remained visible on iOS and Android, even after applying a custom error state view.

## 4.5.4

**Enhancements**
- Updated `cometchat_uikit_shared` to version `4.4.4`.
- Updated `cometchat_sdk` to version `4.0.14`.

**Fixes**
- Fixed an issue where the Back Button of the Message Header was not updating.
- Fixed an issue where `separatorColor` was not working in `CometChatGroups`.
- Fixed an issue where `separatorColor` was not working in `CometChatConversations`.

## 4.5.3

**Enhancements**
- Updated `cometchat_uikit_shared` to version `4.4.3`.
- Updated `cometchat_sdk` to version `4.0.13`.

**Fixes**
- Fixed an issue where the overriding onSendButtonTap function would fail to trigger upon tapping the send button after editing a message.

## 4.5.2
**New**
- Introduced real-time updates for the last message and unread count in conversations based on App setting configured via dashboard, ensuring up-to-date information is displayed.

**Enhancements**
- Updated `cometchat_uikit_shared` to version `4.4.2`.
- Updated `cometchat_sdk` to version `4.0.12`.

**Fixes**
- Fixed the issue where the textEditingController property  in `CometChatMessageComposer`  was causing UI  issues within `CometChatMessageList`.

## 4.5.1
**Enhancements**
- Enhanced the CometChatMessageComposer by exposing ‘TextEditingController’, thus improving customization options.

**Fixes**
- Fixed rendering flex issues that were encountered when opening message information for scheduler messages.

## 4.5.0
**Enhancements**
- Updated all 3rd-party plugins versions.
- Resolved all static Dart Analyser suggestions
- Added namespaces in build.gradle to avoid conflicts.

**Fixes**
- Resolved a functional problem where changes in scope were not altering options in the details page in real time.

## 4.4.0
**New**
- User Mention Support:
    - Added support for mentioning users in a conversation using the @ symbol in the message composer.
    - Mentioned users will be highlighted in the message composer, text bubble, and subtitle of conversations in the conversation list if the last message is a text message containing a mention.
  
**Enhancements**
- The `cometchat_sdk` dependency has been updated to version `4.0.10` for better performance.
- The `cometchat_uikit_shared` dependency has been updated to `4.3.0` for better performance
- Upgraded `CometChatMessageList`, `CometChatMessageComposer`, and `CometChatConversations` components to accept an array of `CometChatTextFormatter`, providing a flexible text formatting system based on various regex patterns. This will help in differentiating between user mentions and URLs within a message.

**Fixes**
- Fixed an issue that caused the app to crash when trying to open a thread while a message was still in the sending state.
- Resolved an issue where smart replies were visible in threaded messages even if the last message was not a text message.
- Real-Time Updates:
    - The `GroupsWithMessages` Component not updating when the logged-in user is added to a new group.
    - Members not being removed from the View Members list when kicked, leaving, or being banned from a group.
    - Ensured visibility of form messages received in real-time.
    - Updated the conversation list when a form message is received in real-time.

## 4.3.4
**Fixes**
- Addressed a usability issue by removing the View Profile button in User Profile for streamlined navigation.
- Rectified a functionality issue with the polls, where users were unable to swipe and remove answers.
- Corrected an issue with the threaded messages count being incremented improperly.

**Enhancements**
- Enhanced `ThreadedMessagesConfiguration` and `CometChatThreadedMessages` by adding `messageComposerView`, `messageListView` and `hideMessageComposer` for better configuration control.
- Updated the `CreatePoll` functionality by adding a suffix icon to allow users to easily remove answers.
- Updated `cometchat_uikit_shared` to version `4.2.10`.

## 4.3.3
**Fixes**
- Addressed an issue with duplicate messages appearing in CometChatMessageList when a media message was sent.
- Resolved an issue where smart replies did not disappear after sending or receiving messages.

**Enhancements**
- Upgraded `cometchat_uikit_shared` to version `4.2.9`
- Upgraded `cometchat_sdk` to version `4.0.8`

## 4.3.2
**Fixes**
- Resolved a padding issue with the `CometChatMessageHeader` to improve user experience.
- Corrected an issue where the user name was missing in the typing indicator for a group in the `CometChatConversations` Component.
- Fixed an issue where the user name was not displayed before the last message for a group in the `CometChatConversations` Component.

**Enhancements**
- Upgraded `cometchat_uikit_shared` to version `4.2.8`

## 4.3.1
**Fixes**
- Addressed an issue with user presence not updating correctly in `CometChatConversations` and `CometChatConversationsWithMessages`, ensuring accurate user status.
- Resolved render flex overflow issue in the `headerView` of `CometChatMessageBubble` in `CometChatMessageList` for smoother UI experience.

**Enhancements**
- Upgraded `cometchat_uikit_shared` to version `4.2.7`

## 4.3.0
**New**
- support for the new `Reaction` feature from `cometchat_sdk: ^4.0.7`
- `CometChatReactions` will be displayed on `CometChatMessageBubble` using `reactions` property of `TextMessage`, `MediaMessage` and `CustomMessage` in `CometChatMessageList`.
- `CometChatReactionList` can be accessed on long pressing on `CometChatReactions` from `CometChatMessageList`.

**Enhancements**
- Upgraded `cometchat_sdk` to version `4.0.7`
- Upgraded `cometchat_uikit_shared` to version `4.2.6`

**Fixes**
- Added spacing between `leadingView` and `contentView` of `CometChatMessageBubble` constructed in `CometChatMessageList`.
- Issue of member count not updating when we are performing Group related actions like adding, banning or removing a `GroupMember` or trying to transfer ownership to another group member.
- Fixed pixelation of AI features icon shown in `CometChatMessageComposer`

## 4.2.3
**Fixes**
- Duplication issue in `CometChatConversations`, `CometChatUsers`, and `CometChatGroups`. 
- Real time message receiving when filtering categories and types from `messageRequestBuilder` in `CometChatMessageList`.

## 4.2.2
**Fixes**
- `bubbleView` alignment issue fixed in `CometChatMessageList`
- Missing configurations `hideAppBar`, `submitIcon`, `selectionIcon` forwarded from `CometChatUsersWithMessages`, `CometChatGroupsWithMessages`, `CometChatConversationsWithMessages` to `CometChatUsers`, `CometChatGroups`, `CometChatConversations` respectively.


## 4.2.1
**Added**
- onSchedulerMessageReceived listeners implemented  in `CometChatMessageList`,`CometChatThreadedMessages`,`SmartReplyExtension`, `AIConversationStarter` , `AIConversationSummary` and `AiSmartReplyExtension`.
- `hideAppBar` property added in `CometChatConversations`

**Changed**
- [CometChat Chat SDK](https://pub.dev/packages/cometchat_sdk) dependency upgraded to `cometchat_sdk: ^4.0.5`
- [cometchat_uikit_shared](https://pub.dev/packages/cometchat_uikit_shared) dependency upgraded to `cometchat_uikit_shared: ^4.2.1`


## 4.1.0
**Added**
- Components `AIAssistBot` and `AIConversationSummary`
- DateSeparatorStyle in CometChatMessageList
- ApiConfiguration in `AIAssistBot`, `AIConversationStarter`, `AIConversationSummary` and `AISmartReplies`
- Support for customizing the AI option in `CometChatMessageComposer` using the properties: `aiIcon`, `aiIconURL`, `aiIconPackageName` and `aiOptionStyle`

**Changed**
- [CometChat Chat SDK](https://pub.dev/packages/cometchat_sdk) dependency upgraded to `cometchat_sdk: ^4.0.4`
- [cometchat_uikit_shared](https://pub.dev/packages/cometchat_uikit_shared) dependency upgraded to `cometchat_uikit_shared: ^4.0.7`

## 4.0.5
**Fixes**
- removed permission.MANAGE_EXTERNAL_STORAGE

**Changed**
- [cometchat_uikit_shared](https://pub.dev/packages/cometchat_uikit_shared) dependency upgraded to `cometchat_uikit_shared: ^4.0.5`

## 4.0.4
**Added**
- Support for Interactive Messages i.e Form Message and Card Message
- Support for modifying margin and padding in CometchatListItem

**Changed**
- [CometChat Chat SDK](https://pub.dev/packages/cometchat_sdk) dependency upgraded to `cometchat_sdk: ^4.0.3`
- [cometchat_uikit_shared](https://pub.dev/packages/cometchat_uikit_shared) dependency upgraded to `cometchat_uikit_shared: ^4.0.4`

## 4.0.3
**Fixes**
- Emoji keyboard interferes with the virtual home button on iPhone

**Changed**
- [cometchat_uikit_shared](https://pub.dev/packages/cometchat_uikit_shared) dependency upgraded to `cometchat_uikit_shared: ^4.0.3`
- Class name AiExtension changed to  AiExtension
- Changed `smartReplyView` and `conversationStarterView` properties to `customView`

## 4.0.2
**Added**
- Support for modifying the color of the voice recording button in `CometChatMessageComposer` using `voiceRecordingIconTint` property of `MessageComposerStyle`.
- Support for custom attachment options, sound and ability to disable read receipts in `CometChatThreadedMessages`.

**Fixes**
- Import issues of `AiConversationStarter`.
- Theme issues in `CometChatThreadedMessages`.

**Removed**
- Unnecessary logs

## 4.0.1
**Added**
- Support for ai features: `AiSmartReply` and `AiConversationStarter`
- `AiSmartReply` provides a list of replies generated using AI for a received message in a conversation
- `AiConversationStarter` gives a list of opening messages generated using AI for starting a conversation when no messages have been exchanged between the participants in a conversation
- Button has been added in `CometChatMessageComposer` tapping on which will list the enabled ai features

**Changed**
- [CometChat Chat SDK](https://pub.dev/packages/cometchat_sdk) dependency upgraded to `cometchat_sdk: ^4.0.2`
- [cometchat_uikit_shared](https://pub.dev/packages/cometchat_uikit_shared) dependency upgraded to `cometchat_uikit_shared: ^4.0.2`

## 4.0.0
**Added**
- Support for handling events received when disconnected websocket connection is reestablished in `CometChatUsers`, `CometChatGroups`, `CometChatConversations` and `CometChatMessageList`.
- Support for handling calling events received in `CometChatConversations` 
- All Extension classes conform to the updated `ExtensionsDataSource` class by implementing new methods `addExtension` and `getExtensionId`.
- Properties to configure color of the sticker icon shown in `CometChatMessageComposer`.

**Changed**
- [CometChat Chat SDK](https://pub.dev/packages/cometchat_sdk) dependency upgraded to `cometchat_sdk: ^4.0.1`
- [cometchat_uikit_shared](https://pub.dev/packages/cometchat_uikit_shared) dependency upgraded to `cometchat_uikit_shared: ^4.0.1`
- Order of options shown for a message in `CometChatMessageList`
- Replaced implementation of `SoundManager` with `CometChatUIKit.soundManager`.
- Replaced implementation of `ChatConfigurator.getDataSource()` with `CometChatUIKit.getDataSource()`.

**Removed**
- property `hideCreateGroup` from `CometChatGroupsWithMessages`
- Emoji and `emojiIconTint` from `CometChatMessageComposer`
- Unused assets
- Dead code

**Fixes**
- Background color of message reactions

## 4.0.0-beta.2
**Added**
- Support for audio and video calling through CometChat's call ui kit plugin.
- Messages information for sent messages.
- Send audio recordings through CometChatMessageComposer.
- Share messages to other applications on the device.

**Changed**
- Upgrade kotlin version for native code: 1.7.10.
- Callback function signature for onMessageSend parameter in ComeChatMessageComposer.

**Removed**
- Shared module moved to a different package [cometchat_uikit_shared](https://pub.dev/packages/cometchat_uikit_shared).

## 4.0.0-beta.1
- 🎉 First release!