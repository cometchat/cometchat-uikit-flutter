# v6.2.0

## New

- Added Swift Package Manager support for iOS, alongside CocoaPods, with both using the same source files.
- Added an Apple privacy manifest (`PrivacyInfo.xcprivacy`) for improved iOS privacy compliance.
- Added `MessageSendStatus` and `CometChatInteractiveCardMessage` aliases to make existing SDK types accessible through the public API.
- Added text-scaling utilities, including `scaledMaxLines`, `scaledDimension` and `currentTextScale`, for building accessible custom views.
- Exported previously inaccessible public API types, including formatters, audio states, user use cases and repositories.
- Added a published API baseline and deprecation policy for the v6 release line.
- Added message translation support with a Translate option, customizable translation styles and `hideTranslateMessageOption`.
- Added `setOptions` and `addOptions` to `CometChatUsers` for customizing long-press menus.
- Added sticker icon and keyboard customization through `CometChatMessageComposer` and `CometChatStickerKeyboardStyle`.
- Added `itemStyle` to `CometChatConversationsStyle` for customizing conversation rows.
- Added `AdditionalConfigurations.copyWith` for per-message bubble styles.

## Enhancements

- Improved accessibility and large-text support across conversations, groups, calls, attachments and composer components, including text wrapping at increased system text sizes.
- Added optional BLoC parameters to eight components, allowing applications to provide and manage their own BLoC instances.
- Improved screen reader support with localized labels for icon-only controls and clearer semantics for list items, message bubbles and decorative elements.
- Improved logging with a release-safe internal logger to prevent UI Kit logs from appearing in production device logs.
- Removed the unnecessary `flutter: generate: true` setting from the package configuration.

## Fixes

- Fixed interactive element parsing issues involving `DateTimeElement`, `CheckBoxElement`, `CustomAction` and `URLNavigationAction`, including missing defaults and incorrect type handling.
- Fixed layout and overflow issues across message bubbles, conversation lists, group members, incoming calls and other components, particularly at larger text sizes.
- Fixed numerous styling and customization properties that were not being applied across messages, conversations, groups, search, reactions, calls and attachments.
- Fixed message and conversation list alignment, selection, status indicators, timestamps, empty states and error handling.
- Fixed list callbacks, including `onLoad`, `onEmpty`, `onError`, `onMessagesLoad` and `onConversationsLoad`, to report state changes correctly.
- Fixed `setOptions` and `addOptions` on `CometChatConversations` and `CometChatGroups`, restoring custom long-press menus.
- Fixed BLoC integration issues by exporting previously inaccessible events, states, repositories and use cases.
- Fixed message formatting and previews, including captions, mentions, text styles, voice notes and quoted messages.
- Fixed incoming-message sounds and custom sound configurations in conversations and message lists.
- Fixed sticker keyboard behavior, including unresponsive buttons, missing empty states and incorrect panel visibility.
- Fixed thread-specific panels, subscriptions and headers to maintain the correct state when switching conversations or threads.
- Fixed attachment handling, including MIME type detection, preview consistency and download caching.
- Fixed AI conversation starters and suggested messages not appearing or being applied correctly.
- Fixed collaborative web views reloading unnecessarily and collaborative bubbles clipping their content.
- Fixed message bubble customization options not reaching polls, stickers, collaborative content and link previews.
- Fixed request builder handling and pagination in users, groups and conversations, including search clearing and custom limits.
- Fixed pinned and saved message handling, including incorrect conversation matching and icon customization.
- Fixed scheduling time-zone handling and removed approximately 970 KB of unused time-zone data.
- Fixed call-related issues involving navigation, logging, notifications and call state.
- Fixed package compatibility with Dart 3.13 and corrected the iOS podspec version.
- Fixed various iOS configuration, rendering and styling issues, including incorrect shadows and missing formatter styles.

## Deprecations

- Deprecated unused extension configuration classes and interactive element styles, including `StickerConfiguration`, `PollsConfiguration`, `MessageTranslationConfiguration`, and `CheckBoxElementStyle`.
- Deprecated `CometChatExceptionStyle` and `exceptionStyle` on `CometChatOutgoingMessageBubbleStyle`.
- Deprecated `aiIcon`, `aiIconURL`, and `aiIconPackageName` on `CometChatMessageComposer`.
- Deprecated `groupsProtocol` and `controllerTag` on `CometChatGroups`.
- Deprecated `controllerTag` on `CometChatConversations`.
- Deprecated `options` on `CometChatListItem`.
- Deprecated five `AdditionalConfigurations` properties: `callButtonsStyle`, `hideVoiceCallButton`, `hideVideoCallButton`, `hideStickersButton`, and `hideReactionOption`.
- Deprecated unused layout and data properties on `CometChatAudioPlayer`, `CometchatMessageOptionSheet`, `CometChatStreamBubble`, `CometChatDeletedBubble`, `CometChatVideoBubble`, and `VideoBubbleFactory`.
- Deprecated `messageBubbleAvatarStyle` and `messageBubbleBackgroundImage` on `CometChatAIAssistantBubbleStyle`. 
- Deprecated `height` and `width` on `CometChatMessageBubble`.
- Deprecated `subtitle` and `fileMimeType` on `CometChatVoiceNoteBubble`, and `handleSafeArea` on `CometChatAnimatedMessageList`.
- Deprecated `onAdd` and `onSend` on `CometChatAttachmentTray`. 
- Deprecated `onEnterPressed` on `CometChatMessageInput`.

## Breaking Changes

- Updated the declared iOS deployment target from iOS 9 to iOS 13. This does not change practical iOS support, as the existing Flutter requirement already requires iOS 13 or later.

# 6.1.1

## New
- Added pinned and saved messages, making it easier to highlight important messages and save messages for later.
- Added thread subscriptions, allowing users to manage notifications for specific conversation threads.
- Added conversation pinning to help keep important conversations easily accessible.

## Enhancements
- Improved the conversation action menu for a better and more consistent experience.

## Fixes
- Fixed an issue where the call screen remained open after the other participant ended the call.
- Fixed an issue where one-to-one calls could remain active when the other participant unexpectedly left the app.
- Fixed an issue where some components did not update correctly when switching between light and dark themes.

# 6.1.0

## New
- Added support for sending multiple attachments in a single message. Files that are picked, pasted or dropped are staged in an attachment tray, where each tile reports its own upload progress and can be removed or retried, and the whole batch can be captioned before sending.
- Added per-type gallery bubbles for multi-attachment messages — `CometChatImagesBubble`, `CometChatVideosBubble`, `CometChatAudiosBubble` and `CometChatFilesBubble` — together with `CometChatMediaViewer` for paging through a message's media full screen.
- Added `enableMultipleAttachments` to `CometChatMessageComposer` and `CometChatMessageList`, defaulting to `true`. Set it to `false` to keep the previous single-attachment bubbles.
- Added `CometChatAttachmentTrayStyle`, applied through `CometChatMessageComposerStyle.attachmentTrayStyle`, and `CometChatAttachmentErrorAlertStyle` for styling the tray and its error alerts.
- Added drag-and-drop and clipboard paste of files into the composer on the platforms that support them.

## Enhancements
- Added caption editing for media messages, and media messages edited this way now show the "Edited" tag that text messages already displayed.
- Changed the image attachment option on Android to open the system photo picker instead of the document browser.

## Fixes
- None

## Deprecations
- Renamed `CometChatAudioBubble` to `CometChatVoiceNoteBubble`, keeping the previous name as a deprecated alias. The new name matches what the class renders: voice notes always use it, on both values of `enableMultipleAttachments`, while audio files use `CometChatAudiosBubble` when the flag is `true`. The previous deprecation recommended `CometChatAudiosBubble`, which voice notes never route to.
- Renamed `CometChatAudioBubbleStyle` to `CometChatVoiceNoteBubbleStyle`, keeping the previous name as a deprecated alias. Both names share one runtime type, so a `ThemeExtension` registered under either resolves the same instance and existing themes need no change.
- Renamed `CometChatAudioBubbleV2` to `CometChatAudioPlayer`, keeping the previous name as a deprecated alias.
- Deprecated the `audioBubbleStyle` property on `AdditionalConfigurations`, `CometChatIncomingMessageBubbleStyle` and `CometChatOutgoingMessageBubbleStyle` in favour of `voiceNoteBubbleStyle`. Both are honoured and `voiceNoteBubbleStyle` takes precedence, so existing styling continues to apply. `audioBubbleStyle` will be removed in the next major release.
- Deprecated `CometChatImageBubble`, `CometChatVideoBubble` and `CometChatFileBubble` in favour of the gallery bubbles. They continue to render the `enableMultipleAttachments: false` path.

## Breaking Changes
- Updated `flutter_bloc` to 9.x, `permission_handler` to 12.x and `diffutil_dart` to 5.x, and constrained `intl` to `^0.20.2`. **Applications that depend on any of these packages directly must upgrade them alongside the UI Kit.**
- Declared a minimum supported toolchain of Flutter 3.38.9 and Dart 3.10.8. Earlier releases declared `flutter: ">=2.5.0"` but could not resolve below 3.38.9 in practice, so upgrading from 6.0.5 requires no toolchain change.
- Changed the value `runtimeType` reports for `CometChatAudioBubble` and `CometChatAudioBubbleStyle` to their new names. Type checks, casts, subclassing and constructor calls are unaffected; only code comparing `runtimeType.toString()` to a literal old name needs updating.

# 6.0.5

## New
- Added support for AI agents in group conversations, `CometChatStreamBubble`, and native card message rendering with `CometChatCardBubble`.
- Added card messages to search results, AI agents to the add-members picker, and a localized `aiAgentMessage` label.

## Enhancements
- Improved AI conversations with responsive card layouts, quoted replies, better card message search, refined chat history, and real-time conversation updates for card and agent replies.

## Fixes
- Fixed issues with @mention and AI suggestion lists not appearing or reappearing correctly.

# 6.0.4

## New
- Added `CometChatCardBubble` for rendering developer card messages (category `card`).
- Added support for rendering agent card messages within the AI Assistant bubble.
- Added streaming support for cards that arrive during a streamed agent response.
- Added the `ccCardActionClicked` event, which forwards raw card actions to the app layer for both developer and agent cards.
- Added `MessageCategoryConstants.card` for card messages.

## Enhancements
- Enhanced the AI Assistant bubble to render ordered text and card blocks, falling back to `getText()` for older messages.
- Enhanced conversation previews for developer card messages to show `getText()` when available, or `Card Message` otherwise.
- Updated developer card options to exclude `edit` and `copy`.

## Fixes
- None

# 6.0.3

## New
- None

## Enhancements
- Improved the sample app for web by adding responsive navigation optimized for desktop layouts.

## Fixes
- None

# 6.0.2

## New
- Added the `CometChatNotificationFeed` component, providing a full-screen notification feed for displaying campaign and promotional notifications.
- Added support for customizable feed behavior through props such as `notificationFeedRequestBuilder`, `notificationCategoriesRequestBuilder`, `onItemClick`, and `onActionClick`.
- Added customizable UI support with `HeaderView`, `EmptyView`, `ErrorView`, `LoadingView`, `style`, `cardThemeMode`, and `cardThemeOverride` props for advanced theming and layout control.
- Added category-based filtering with unread badge counts, allowing users to quickly navigate notifications by category.

## Enhancements
- None

## Fixes
- None

# 5.2.16

## New
- None

## Enhancements
- Enhanced the Edit Message composer UI in the Hybrid iOS sample application to better align with the latest Figma design specifications.
- Improved the Call Detail screen in the Hybrid iOS sample application by adding dedicated voice and video calling options for easier call initiation.
- Updated the Create Group modal UI in the Hybrid Mobile sample application to better match the latest Figma-based design guidelines.
- Enhanced the bottom navigation menu in the Hybrid iOS sample application for improved consistency with the latest UI specifications.
- Improved the App Credentials screen in the Hybrid iOS sample application to better align with the latest Figma design patterns.
- Updated the Social Login screen UI in the Hybrid Mobile sample application to match the latest design specifications and improve visual consistency.
- Enhanced the Chat List profile context menu in the Hybrid Mobile sample application to align with the latest design system updates.
- Improved the Login screen UI in the Hybrid Mobile sample application to better match the latest Figma specifications and onboarding experience.

## Fixes
- None

# 6.0.1

## New
- AI Assistant Chat History component for viewing past AI conversations
- AI-specific message configuration (smart replies, conversation starters)
- New Chat and Chat History buttons in AI message header
- Public group auto-rejoin on tap (for kicked users)
- Blocked user and kicked/banned banners in messages screen
- Search with thread reply navigation support
- AppCredentials screen with SharedPreferences persistence

## Enhancements
- Updated CometChat SDK to 5.0.1
- Updated Calls SDK to 5.0.2
- Migrated sample apps from GetX to plain setState architecture
- Fixed stale user/group objects bug in messages screen (using mutable local copies)
- Improved message list with markdown formatting support
- Enhanced login screen with dotted background pattern and user grid

## Fixes
- Messages screen now passes mutable `_user`/`_group` to UIKit components instead of stale `widget.user`/`widget.group`
- Guard screen properly re-initializes Calls SDK on cached session restore
- Protected group join flow from conversations and groups tabs

# 5.2.15

## New
- None

## Enhancement
- None

## Fixes
- Fixed an issue where favicons were missing in URL preview messages for shared links.
- Fixed an issue where the "See More" button in the search component did not behave correctly while loading additional search results.
- Fixed an issue where received `.m4a` audio files were not immediately playable and their duration was not displayed correctly after receipt.
- Fixed an issue where `MessagesRequestBuilder` usage caused inconsistent message retrieval behavior under certain filtering and pagination scenarios.

# v6.0.0

## New
- Added message flagging and reporting support, along with translations for 20 locales, allowing users to moderate conversations in their preferred language.
- Added the `CometChatComposerLayout` component with both single-line and double-line layout options for greater flexibility when customizing the message composer experience.
- Added a keyboard diagnostics utility to simplify troubleshooting and validation of keyboard-related behaviors across chat interfaces.
- Added a thumbnail extraction utility to generate preview images from supported media content more efficiently.
- Added an in-chat image viewer, allowing users to open and preview shared images directly within conversations.
- Added Firebase configuration support to the sample application to simplify setup for push notifications and related integrations.

## Enhancements
- Improved the composer layout rendering pipeline to provide more consistent behavior and easier customization across composer variants.
- Enhanced the rich-text messaging flow to use a dedicated WYSIWYG-only rendering path for more predictable formatting behavior.
- Improved image message bubbles to provide a more polished and consistent media viewing experience in conversations.
- Expanded the conversation preview utility to support additional conversation and message preview scenarios.
- Refreshed BLoC implementations across conversations, groups, users, message actions, call buttons, and ongoing call flows to improve consistency and maintainability across the SDK experience.
- Updated sample application screens to better reflect the latest UI components, layouts, and interaction patterns.
- Reorganized the Skills directory structure and added `.claude-plugin` manifest support to improve plugin discovery and project organization.

## Fixes
- Fixed an issue where long-press actions on formatted mentions could produce incorrect formatter behavior in certain message interaction flows.
- Fixed an issue where calling functionality could stop working after a user logged out and logged back in, ensuring calls continue to work reliably across session changes.
- Fixed an issue where Android audio message recording could become stuck after the microphone permission prompt, restoring smooth voice message recording.

# 5.2.14

## New
- None

## Enhancements
- None

## Fixes
- Added `textFormatters` parameter to `CometChatThreadedHeader` to allow passing custom text formatters from the consumer app, enabling mention style customization (e.g., text color, background color) in the threaded header bubble.

# 5.2.13

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.2.3`.

## Fixes
- Resolved an issue where the AI thinking bubble was not displaying and `StreamMessage` was rendering as an unsupported message type in `CometChatMessageList`.
- Fixed a double-notification issue in the message composer, where both `RichTextEditingController` listener and `TextField.onChanged` were firing simultaneously, causing stale suggestion handling.
- Corrected an issue where custom `CometChatMentionsFormatter` subclasses were being silently overwritten during controller updates. Custom formatter implementations are now preserved.

# 5.2.12

## New
- Introduced the `CometChatCompactMessageComposer` component, a streamlined, single-line message composer for a more efficient message composition experience.
- Added the `showTextSelectionMenuItems` prop, enabling the display of text formatting options (e.g., bold, italic) in the native text selection menu when users select text within the composer.
- Added the `hideRichTextFormattingOptions` prop to hide the fixed formatting toolbar above the message composer, providing a cleaner interface.
- Introduced the `enableRichTextEditor` master prop to control all rich text functionality. When disabled:
- Both the selection menu items and fixed formatting toolbar are hidden, regardless of other settings.

# 5.2.11

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.2.1`.
- Improved iOS app lifecycle handling and added support for Flutter version `3.41`.
- Added validation for unsupported file types in chat and displayed an error message in the message bubble when users attempt to send a restricted file format.

## Fixes
- Resolved a problem where the message screen and other screens did not refresh automatically after the internet connection was restored, preventing newly received messages from appearing until the screen was reloaded.
- Fixed an issue where an incorrect error message indicated that a file exceeded the 100 MB upload limit when attempting to upload a much smaller file under unstable or slow internet conditions.

# 5.2.10

## New
- Introduced badge count support in the Flutter Sample App, enabling the app icon to display unread message counts for improved visibility of new activity.
- Integrated badge functionality using a reliable badge management dependency to ensure accurate and consistent badge updates across supported platforms.

## Enhancements
- Improved notification experience by automatically updating the app icon badge count based on unread messages.
- Ensured seamless badge synchronization when messages are received, read, or cleared.

## Fixes
- Fixed an issue where the group call events were missing in `CometChatMessageListController`.

## 5.2.9

## New
- Added the "Mark as Unread" option, allowing users to mark previously read messages as unread for better message management.
- Introduced a new message indicator UI that visually separates unread messages from read ones, improving the user experience and making unread messages more noticeable.

## Enhancements
- Implemented the `setStartFromUnread` property, enabling the message list to start from the unread messages when set to `true`. This feature provides a more seamless experience for users who want to focus on new messages.

## Fixes
- None

## Deprecations
- None

## Removals
- None


## 5.2.8

## New
- **Global Conversation and Message Search:** Introduced a new feature that allows users to easily search across all conversations and messages for quick access to specific content.
- **Quoted Replies:** Users can now swipe to a message and reply directly to it, creating a quoted reply for improved context in conversations.

## 5.2.7

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.1.8`.
- Updated `cometchat_sdk` to version `4.0.33`.

## Fixes
- Fixed the Retry button to reattempt network requests and refresh data when the internet connection is restored.

## 5.2.6

## New
- Added a new feature that allows users to report a specific message for moderation purposes.
- Added `hideFlagMessageOption` — to hide the **Flag Message** option from the message actions menu.
- Added `hideFlagRemarkField` — to hide the remark text area in the flag dialog.

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.1.7`.
- Updated `cometchat_sdk` to version `4.0.32`.

## Fixes
- Fixed a bug where users who had not logged in at least once were not shown as "Offline". Presence status now correctly reflects the state of such users.

## 5.2.5

## New
- Added the ability to enable or disable the "mention all" feature, along with custom labels for specific IDs in both `CometChatMessageComposer`, `CometChatMessageList` and `CometChatConversations`.
- Introducing new methods like `disableMentionAll`, `mentionAllLabelId` and `mentionAllLabel`, giving developers greater flexibility in managing mentions.

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.1.6`.

## Fixes
- Fixed a bug where users who had not logged in at least once were not shown as "Offline".

## 5.2.4

## Enhancements
- Updated `cometchat_sdk` to version `4.0.30`.
- Updated `cometchat_uikit_shared` to version `5.1.5`.

## Fixes
- Resolved an issue where the status of blocked users was still visible in the user information section, even after being blocked.
- Fixed a bug that caused an odd message bubble to appear when deleting a call message.
- Addressed an issue where "Unknown" was displayed instead of the actual user name while typing in the Whiteboard.
- Addressed the issue where the option in the poll feature did not get removed when it is empty.

## 5.2.3

## New
- Added a **Exception View** in the bottom view of the message bubble. This view appears for messages whose file size exceeds the limit.

## Enhancements
- Updated `cometchat_sdk` to version `4.0.29`.
- Updated `cometchat_uikit_shared` to version `5.1.4`.

## 5.2.2

## Enhancements
- Updated `cometchat_sdk` to version `4.0.28`.
- Updated `cometchat_uikit_shared` to version `5.1.3`.

## Fixes
- Resolved error occurred in console while using Thumbnail Generation.
- Fixed issue where calls failed to join when the device was locked.

## 5.2.1

## Fixes
- Fixed an issue where the group conversation header would grey out when a user started typing, and ensured the typing status is displayed correctly.

## 5.2.0

## New
- Introduced **CometChatAIAssistantChat**, a composite component that combines a message header, message list, and composer to deliver an interactive AI agent chat experience.
    - Added **CometChatStreamBubble**, allowing messages from the AI agent to appear in real time for a more natural conversation flow.
    - Added **CometChatAIAssistantBubble** with Markdown support, enabling clear and formatted rendering of AI Agent messages for improved readability and user experience.
    - Provided **quick starter suggestions** in the empty state to help users begin interactions with the AI agent faster.
    - Added **"New Chat"** button to reset conversation context and **chat history** for easy access to previous sessions.
    - Enabled full customization through props, including:
    - Streaming speed adjustments.
    - Custom header, empty state, and error views.
    - Visibility toggles for suggestions, history, and new chat buttons.

## Enhancements
- Updated `cometchat_sdk` to version `4.0.27`.
- Updated `cometchat_uikit_shared` to version `5.1.2`.

## Fixes
- Resolved a bug causing the `onMessagesRead()` real-time event to trigger twice instead of once when a message is marked as read.
- Fixed the last seen status message to display as a marquee for better visibility when truncated.
- Fixed an issue where users were unable to use the Conversation Starter feature to start a conversation.
- Resolved a bug causing the Read Receipt option to appear incorrectly within thread messages. The read receipt should now only be visible in main conversation messages.
- Fixed a problem where User Presence (online/offline status) was still visible in the group member list, even when the presence toggle was turned off in settings.

## 5.1.1

## Enhancements
- Updated `cometchat_sdk` to version `4.0.26`.
- Updated `cometchat_uikit_shared` to version `5.1.1`.

## Fixes
- Resolved an issue where image thumbnails were not visible, improving media preview functionality.
- Corrected the display of moderation indicators in messages for accurate moderation visibility.
- Addressed an issue on some devices where images could not be attached, restoring proper attachment functionality.
- Fixed extra spacing in the last message of group conversations after sending a media message, ensuring consistent layout.
- Added the missing `hideStickyDate` prop in `CometChatMessageList` to allow better control over message list display.
- Resolved an issue where typed chat text was cleared when uploading an image.
- Fixed sticky date overlapping on the message list header for a cleaner interface.
- Fixed a problem on Android where incoming call notifications were not received when the app was killed and the screen was off.

## 5.1.0

## New
- Added a **Moderation View** in the default bottom view of the message bubble. This view appears for messages that are disapproved based on their moderation status.
- Introduced a new prop `hideModerationView` in the **CometChatMessageList** component, allowing developers to hide the Moderation View when needed.

## Enhancements
- Updated `cometchat_sdk` to version `4.0.25`.
- Updated `cometchat_uikit_shared` to version `5.1.0`.

## 5.0.5

## Enhancements
- Updated `cometchat_sdk` to version `4.0.24`.
- Updated `cometchat_uikit_shared` to version `5.0.5`.
- Adjusted font size in message bubbles to respect system font scaling preferences, improving accessibility.
- Enhanced poll screen behavior to now fully expand or collapse on scroll for a smoother user experience.

## Fixes
- Resolved an issue where starting an audio call through push notifications incorrectly triggered a video call instead.
- Fixed a bug where declining a call did not end the call on the sender’s side, causing it to continue indefinitely.
- Addressed a permission-handling issue where users were redirected to system settings instead of seeing an error message when permissions (camera, mic, attachments) were denied.
- Fixed a problem where default calling functionality failed in the sample app due to asset-related issues.
- Resolved a bug where the search keyword was cleared after pressing the “Done” button on the keyboard in various search views.
- Prevented crashes when accepting incoming calls via push notifications in the sample app.
- Fixed an issue where the message input was not cleared after cancelling a composed message.
- Resolved a bug where the incoming call dialog did not close after the caller ended the call.
- Prevented messages from being sent when the message input only contains white spaces.
- Fixed an issue where users could reply to messages from blocked users in thread view.
- Standardized date separator formats across platforms for consistent user experience.
- Corrected the Save button display logic when a group role remains unchanged.
- Fixed a real-time sync issue where the `ban/kick` group actions were not reflected immediately for users.
- Prevented call ringing for users already on another active call (busy state not respected).
- Fixed a blank info screen that appeared after sending a message and tapping the message info icon.
- Addressed an issue where the native ongoing call notification failed to appear.
- Resolved a bug where disabling mentions in the message composer did not work as expected.
- Fixed an issue where the MessageOptionSheet failed to appear when only the reactions option was enabled.
- Corrected the issue where the "Send" button became active when only space characters were entered, even if no valid message content was present.
- Resolved a crash that occurred when cancelling a call from the background state in the sample app.

## 5.0.4

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.0.4`.

## Fixes
- Fixed an issue where CometChatSDK.framework was missing a dSYM file during iOS build uploads, causing upload failures.
- Resolved a bug causing all screens to suddenly disconnect, improving stability.
- Corrected the group member count display in the Group Info page to accurately reflect member additions and removals.
- Eliminated a brief black screen flicker that appeared when opening a user or group from the search screen.
- Prevented users from submitting edited messages that only include space characters, avoiding unnecessary "edited" status.
- Removed flicker when reopening the app from the background or recent apps list.
- Removed the unnecessary online presence badge on the chat header avatar in one-on-one chats for a cleaner UI.
- Disabled logout functionality when the user has no internet connection, ensuring network-dependent actions behave correctly.
- Adjusted the spacing between the CometChat logo and "Login" text on the login screen to align with design standards.
- Prevented the poll creation page from becoming scrollable, ensuring a stable and consistent user experience during poll creation.
- Resolved an issue where the app was rejected due to the use of deprecated media permissions. The permissions have been updated to comply with current platform requirements.

## 5.0.3

## Enhancements
- Updated `cometchat_sdk` to version `4.0.23`.
- Updated `cometchat_uikit_shared` to version `5.0.3`.

## Fixes
- Fixed an issue where the dateSeparatorPattern in CometChatMessageList was not functioning as expected.
- Resolved a problem where the FooterView would close unexpectedly when interacting with the MessageComposer in the Flutter UI Kit.
- Fixed a bug causing the app to open twice when accepting a VOIP call from the background.
- Addressed the appearance of duplicate date separators in message threads after sending a new message.
- Resolved an issue where the reply compose box would disappear when replying to sticker messages.
- Fixed a UI issue where the send button was misaligned and other buttons became unusable when replying to video, sticker, or poll messages.
- Corrected the display of translated messages to prevent the original word from appearing below the translation.
- Fixed a visual glitch where a dark screen briefly flashed when reopening a deleted chat from the search view.

## 5.0.2

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.0.2`.

## Fixes
- Fixed an issue in CometChatMessageList where the `onLoad` callback was not triggered after messages were visually loaded.
- Fixed an issue where two identical stickers appeared in the message composer when opening a chat or replying in a thread.
- Fixed an issue where the search bar text for banned members did not appear in the default color on both Android and iOS, reducing visibility.
- Resolved a crash in the Push Notification Sample App that occurred when accepting a call while the app was closed (killed).
- Fixed an issue where the app froze or became unresponsive when accepting a call from the background.

## 5.0.1

## Enhancements
- Improved sticky date separator behavior to remain fixed at the top during new chat sessions, enhancing readability.
- Updated `cometchat_sdk` to version `4.0.22`.
- Updated `cometchat_uikit_shared` to version `5.0.1`.

## Fixes
- Corrected incorrect capitalization in the unblock confirmation popup. It now reads "Unblock this contact?" with proper formatting.
- Removed the incorrectly displayed password protection icon from the group info section for password-protected groups.
- Restored the missing online/last seen status in the user info section.
- Updated the Add Member component to default to selection mode, removing the need for a long press to select users.
- Resolved an issue where incorrect options (e.g., Change Scope, Ban, Remove) appeared during ownership transfer selection.
- Fixed an issue allowing messages to be sent without changes after clicking the Edit button. The Send button is now disabled until edits are made.
- Fixed an issue where the chat UI would break upon reopening the chat screen.
- Resolved an issue where the summary icon incorrectly appeared in thread view upon opening.
- Fixed unexpected display of the user name in one-to-one conversation threads.
- Resolved an issue where the "Edit Message" background appeared in light mode when using dark mode.
- Fixed flickering of the voice recording UI for a few seconds after recording ended.
- Corrected display of the unblock option for blocked users .
- Resolved flickering of the "Leave" option in group info when only one user was present.

## 5.0.0

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.0.0`.
- Updated properties for all components to improve flexibility, customization, and overall usability.
- Enhanced the **User Component** by refining properties for better profile representation and interaction.
- Improved the **Groups Component** with additional properties for group visibility and management.
- Updated the **Group Members Component**, allowing for better user role management within groups.
- Refined the **Thread Header Component** with improved customization options.
- Enhanced the **Message Header Component**, offering better control over display settings.
- Improved the **Message List Component** by adding new properties for message styling and rendering.
- Updated the **Message Composer Component** with enhanced properties for message input control.

## 5.0.0-beta.2

## Enhancements
- Updated `cometchat_uikit_shared` to version `5.0.0-beta.2`.
- Enhanced the **User Component** by refining properties for better profile representation and interaction.
- Improved the **Groups Component** with additional properties for group visibility and management.
- Updated the **Group Members Component**, allowing for better user role management within groups.
- Refined the **Thread Header Component** with improved customization options.
- Enhanced the **Message Header Component**, offering better control over display settings.
- Improved the **Message List Component** by adding new properties for message styling and rendering.
- Updated the **Message Composer Component** with enhanced properties for message input control.

## Fixes
- **Resolved Flutter UI Kit Build Failure**: Fixed an issue causing build failures when using Flutter version 3.29.0.
- **Last Message Not Updating for Group Action Messages**: Addressed a problem where the last message did not update if it was a group action message.
- **Deleting Mentioned Names in Messages**: Fixed an issue where deleting a mentioned name in a message resulted in character-by-character deletion instead of removing the full mention.
- **Incorrect User Name Display in Group Member List**: Fixed an issue where user names were incorrectly displayed in the group member list.
- **Threaded Messages Missing Sender's Name**: Resolved an issue where threaded messages did not display the sender's name in the chat screen.

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
