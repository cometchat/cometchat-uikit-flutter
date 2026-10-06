---
name: cometchat-flutter-components
description: >
  Complete catalog of CometChat Flutter UI Kit v6 widgets. Reference before writing
  integration code — never invent widget names. Covers all chat components
  (conversations, messages, users, groups), call components (buttons, incoming,
  outgoing, ongoing, call logs), and shared views (avatar, badge, receipt, reactions,
  bubbles, list base, search, status indicator).
license: "MIT"
compatibility: "cometchat_chat_uikit ^6.0.0; flutter >=2.5.0"
allowed-tools: "executeBash, readFile, readCode, fileSearch, listDirectory, grepSearch"
metadata:
  author: "CometChat"
  version: "1.0.0"
  tags: "cometchat flutter components widgets catalog props"
---

# CometChat Flutter UIKit v6 — Widget Catalog

Canonical reference for every public widget in `cometchat_chat_uikit`. Look up names, props, view slots, and style classes here before writing code.

---

## Rule: NEVER_INVENT_NAMES

Always use exact widget names from this catalog. Do not invent names like `CometChatChat`, `CometChatMessenger`, `CometChatChatList`, `CometChatContactList`, `CometChatMessageView`, or `CometChatUserList` — they don't exist.

---

## 1. Chat Components

### CometChatConversations

Displays a list of recent conversations with real-time updates (new messages, typing, presence, receipts).

- **Location:** `chat_ui/src/conversations/cometchat_conversations.dart`
- **Key props:** `onItemTap`, `onItemLongPress`, `conversationsRequestBuilder`, `usersStatusVisibility`, `receiptsVisibility`, `deleteConversationOptionVisibility`, `textFormatters`, `hideAppbar`, `hideSearch`, `conversationsBloc`
- **View slots:** `listItemView(Conversation)`, `subtitleView(ctx, Conversation)`, `trailingView(Conversation)`, `leadingView(ctx, Conversation)`, `titleView(ctx, Conversation)`, `emptyStateView`, `errorStateView`, `loadingStateView`
- **Style:** `CometChatConversationsStyle`
- **Request builder:** `ConversationsRequestBuilder`

### CometChatMessageList

Displays messages for a 1:1 or group conversation with real-time updates, reactions, threads, and smart replies.

- **Location:** `chat_ui/src/message_list/widgets/cometchat_message_list.dart`
- **Key props:** `user`, `group`, `messagesRequestBuilder`, `parentMessageId`, `templates`, `alignment`, `hideDeletedMessages`, `disableReceipts`, `disableReactions`, `enableSwipeToReply`, `textFormatters`, `messageListBloc`
- **View slots:** `headerView`, `footerView`, `emptyStateView`, `errorStateView`, `loadingStateView`, `emptyChatGreetingView`
- **Style:** `CometChatMessageListStyle`
- **Request builder:** `MessagesRequestBuilder`

### CometChatMessageComposer

Text input with attachments, voice recording, rich text toolbar, mentions, and AI features.

- **Location:** `chat_ui/src/message_composer/widgets/cometchat_message_composer.dart`
- **Key props:** `user`, `group`, `parentMessageId`, `placeholderText`, `disableTypingEvents`, `text`, `onChange`, `onSendButtonTap`, `textFormatters`, `disableMentions`, `hideVoiceRecordingButton`, `richTextConfiguration`
- **View slots:** `auxiliaryButtonView`, `secondaryButtonView`, `sendButtonView`, `headerView`, `footerView`, `richTextToolbarView`
- **Style:** `CometChatMessageComposerStyle`
- **Note:** Scaffold must set `resizeToAvoidBottomInset: false` — composer handles keyboard internally.

### CometChatMessageHeader

Displays user/group info as an AppBar with online status, typing indicator, and call buttons.

- **Location:** `chat_ui/src/message_header/cometchat_message_header.dart`
- **Key props:** `user`, `group`, `onBack`, `showBackButton`, `hideVideoCallButton`, `hideVoiceCallButton`, `usersStatusVisibility`, `hideChatHistoryButton`, `hideNewChatButton`
- **View slots:** `subtitleView(Group?, User?, ctx)`, `listItemView(Group?, User?, ctx)`, `trailingView(User?, Group?, ctx)`, `leadingStateView(Group?, User?, ctx)`, `titleView`, `auxiliaryButtonView`
- **Style:** `CometChatMessageHeaderStyle`
- **Implements:** `PreferredSizeWidget` (use as `appBar:` in Scaffold)

### CometChatUsers

Displays a searchable, alphabetically sorted list of users.

- **Location:** `chat_ui/src/users/cometchat_users.dart`
- **Key props:** `onItemTap`, `onItemLongPress`, `usersRequestBuilder`, `usersStatusVisibility`, `hideSearch`, `selectionMode`, `usersBloc`
- **View slots:** `listItemView(User)`, `subtitleView(ctx, User)`, `trailingView(ctx, User)`, `leadingView(ctx, User)`, `titleView(ctx, User)`, `emptyStateView`, `errorStateView`, `loadingStateView`
- **Style:** `CometChatUsersStyle`
- **Request builder:** `UsersRequestBuilder`

### CometChatGroups

Displays a searchable list of groups the user has joined or can join.

- **Location:** `chat_ui/src/groups/cometchat_groups.dart`
- **Key props:** `onItemTap`, `onItemLongPress`, `groupsRequestBuilder`, `hideSearch`, `selectionMode`, `groupTypeVisibility`, `groupsBloc`
- **View slots:** `listItemView(Group)`, `subtitleView(ctx, Group)`, `trailingView(ctx, Group)`, `leadingView(ctx, Group)`, `titleView(ctx, Group)`, `emptyStateView`, `errorStateView`, `loadingStateView`
- **Style:** `CometChatGroupsStyle`
- **Request builder:** `GroupsRequestBuilder`

### CometChatGroupMembers

Displays members of a specific group with role badges and management options (kick, ban, scope change).

- **Location:** `chat_ui/src/group_members/cometchat_group_members.dart`
- **Key props:** `group` (required), `groupMembersRequestBuilder`, `hideSearch`, `selectionMode`, `usersStatusVisibility`, `hideBanMemberOption`, `hideKickMemberOption`, `hideScopeChangeOption`
- **View slots:** `listItemView(GroupMember)`, `subtitleView(ctx, GroupMember)`, `trailingView(ctx, GroupMember)`, `leadingView`, `titleView`, `emptyStateView`, `errorStateView`, `loadingStateView`
- **Style:** `CometChatGroupMembersStyle`
- **Request builder:** `GroupMembersRequestBuilder`

### CometChatSearch

Full-screen search across conversations and messages with filter chips and dual-section results.

- **Location:** `chat_ui/src/search/cometchat_search.dart`
- **Key props:** `onConversationClicked`, `onMessageClicked`, `searchFilters`, `searchIn`, `user`, `group`, `conversationsRequestBuilder`, `messagesRequestBuilder`
- **View slots:** `conversationItemView(ctx, Conversation)`, `conversationSubtitleView(ctx, Conversation)`, `conversationLeadingView(ctx, Conversation)`, `conversationTailView(ctx, Conversation)`, `searchTextMessageView(ctx, TextMessage)`, `searchImageMessageView(ctx, MediaMessage)`, `emptyStateView`, `errorStateView`, `loadingStateView`, `initialStateView`
- **Style:** `CometChatSearchStyle`

### CometChatThreadedHeader

Displays a parent message with reply count in a threaded conversation view. Listens for real-time reply count updates.

- **Location:** `chat_ui/src/threaded_header/widgets/cometchat_threaded_header.dart`
- **Key props:** `parentMessage` (required), `loggedInUser` (required), `template`, `receiptsVisibility`, `textFormatters`
- **View slots:** `messageActionView(BaseMessage, ctx)`
- **Style:** `CometChatThreadedHeaderStyle`

### CometChatMessageInformation

Displays read/delivered receipt information for a message. Shows per-member receipts in group conversations.

- **Location:** `chat_ui/src/message_information/widgets/cometchat_message_information.dart`
- **Key props:** `message` (required), `title`, `template`, `textFormatters`
- **Style:** `CometChatMessageInformationStyle`

### CometChatAIAssistantChatHistory

Displays AI assistant conversation history with pagination, date separators, message deletion, and new chat button.

- **Location:** `chat_ui/src/ai_assistant_chat_history/widgets/cometchat_ai_assistant_chat_history.dart`
- **Key props:** `user`, `group`, `messagesRequestBuilder`, `onMessageClicked`, `onNewChatButtonClicked`, `onClose`, `hideStickyDate`, `hideDateSeparator`
- **View slots:** `emptyStateView`, `errorStateView`, `loadingStateView`, `backButton`
- **Style:** `CometChatAIAssistantChatHistoryStyle`

---

## 2. Call Components

### CometChatCallButtons

Voice and video call icon buttons. Supports direct calls (user) and meetings (group).

- **Location:** `call_ui/src/call_buttons/cometchat_call_buttons.dart`
- **Key props:** `user`, `group`, `hideVoiceCallButton`, `hideVideoCallButton`, `outgoingCallConfiguration`, `callSettingsBuilder`, `callButtonsBloc`
- **View slots:** `voiceCallIcon`, `videoCallIcon`
- **Style:** `CometChatCallButtonsStyle`

### CometChatIncomingCall

Incoming call banner (a card at the top of the screen) with decline and accept buttons. The UI Kit shows it itself, over `CallNavigationContext.navigatorKey`'s navigator, when the logged-in user receives a call (with `enableCalls`); configure it through `CallingConfiguration.incomingCallConfiguration`.

- **Location:** `call_ui/src/incoming_call/cometchat_incoming_call.dart`
- **Key props:** `call` (required), `user`, `callSettingsBuilder`, `onDecline`, `onAccept`, `onError`, `disableSoundForCalls`, `customSoundForCalls`, `customSoundForCallsPackage`, `incomingCallBloc` (yours to close)
- **View slots:** `titleView(ctx, Call)`, `subTitleView(ctx, Call)`, `leadingView(ctx, Call)`, `trailingView(ctx, Call)`, `itemView(ctx, Call)`
- **Style:** `CometChatIncomingCallStyle`

### CometChatOutgoingCall

Full-screen outgoing call UI with cancel button. Shown when the logged-in user initiates a call.

- **Location:** `call_ui/src/outgoing_call/cometchat_outgoing_call.dart`
- **Key props:** `call` (required), `user`, `sessionSettingsBuilder`, `onCancelled`, `disableSoundForCalls`, `customSoundForCalls`
- **View slots:** `subtitleView(ctx, Call)`, `avatarView(ctx, Call)`, `titleView(ctx, Call)`, `cancelledView(ctx, Call)`
- **Style:** `CometChatOutgoingCallStyle`

### CometChatOngoingCall

Renders the active call screen using the CometChat Calls SDK. Blocks back navigation.

- **Location:** `call_ui/src/ongoing_call/cometchat_ongoing_call.dart`
- **Key props:** `sessionSettingsBuilder` (required), `sessionId` (required), `callWorkFlow`, `onError`, `bloc`
- **Style:** None (rendered by Calls SDK)

### CometChatCallLogs

Displays a list of call logs (missed, incoming, outgoing) with icons and timestamps.

- **Location:** `call_ui/src/call_logs/cometchat_call_logs/cometchat_call_logs.dart`
- **Key props:** `callLogsRequestBuilder`, `onItemClick`, `onCallLogIconClicked`, `hideAppbar`, `outgoingCallConfiguration`, `callLogsBloc`
- **View slots:** `listItemView(CallLog, ctx)`, `subTitleView(CallLog, ctx)`, `trailingView`, `leadingStateView`, `titleView`, `emptyStateView`, `errorStateView`, `loadingStateView`
- **Style:** `CometChatCallLogsStyle`
- **Request builder:** `CallLogRequestBuilder`

### CometChatCallBubble

Inline bubble for call messages inside the message list. Shows call type icon, title, and join button.

- **Location:** `call_ui/src/call_bubble/cometchat_call_bubble.dart`
- **Key props:** `icon`, `title`, `buttonText`, `onTap`, `subtitle`, `alignment`, `iconUrl`
- **Style:** `CometChatCallBubbleStyle`

---

## 3. Shared Views

### CometChatAvatar

Circular avatar with image URL fallback to initials from name.

- **Location:** `shared_ui/src/clean_architecture/presentation/views/misc/avatar/cometchat_avatar.dart`
- **Key props:** `image`, `name`, `width`, `height`, `padding`, `margin`, `colorPalette`, `spacing`, `typography`
- **Style:** `CometChatAvatarStyle`

### CometChatBadge

Unread count badge (red circle with number).

- **Location:** `shared_ui/src/clean_architecture/presentation/views/misc/badge/cometchat_badge.dart`
- **Style:** `CometChatBadgeStyle`

### CometChatReceipt

Message delivery receipt icons (sent, delivered, read).

- **Location:** `shared_ui/src/clean_architecture/presentation/views/misc/receipt/cometchat_receipt.dart`
- **Style:** `CometChatReceiptStyle`

### CometChatReactions

Displays emoji reaction chips below a message bubble with tap/long-press callbacks.

- **Location:** `shared_ui/src/clean_architecture/presentation/views/components/reactions/cometchat_reactions.dart`
- **Key props:** `reactionList` (required), `alignment`, `onReactionTap`, `onReactionLongPress`, `colorPalette`, `spacing`, `typography`
- **Style:** `CometChatReactionsStyle`

### CometChatMessageBubble

Skeleton structure for any message bubble. Binds together leading, header, content, footer, thread, reply, and bottom views.

- **Location:** `shared_ui/src/clean_architecture/presentation/views/misc/message_bubble/cometchat_message_bubble.dart`
- **Key props:** `alignment`, `colorPalette`, `spacing`, `contentPadding`
- **View slots:** `leadingView`, `headerView`, `contentView`, `footerView`, `bottomView`, `threadView`, `replyView`, `statusInfoView`
- **Style:** `CometChatMessageBubbleStyle`

### CometChatListBase

Top-level container with app bar, search box, and scrollable content. Used internally by Conversations, Users, Groups, GroupMembers.

- **Location:** `shared_ui/src/clean_architecture/presentation/views/components/list_base/cometchat_listbase.dart`
- **Key props:** `container` (required), `title`, `hideSearch`, `showBackButton`, `onSearch`, `hideAppBar`, `searchReadOnly`, `onSearchTap`
- **View slots:** `backIcon`, `menuOptions`, `titleView`
- **Style:** `ListBaseStyle`

### CometChatStatusIndicator

Small colored dot indicating user online/offline status or group type icon.

- **Location:** `shared_ui/src/clean_architecture/presentation/views/misc/status_indicator/cometchat_status_indicator.dart`
- **Style:** `CometChatStatusIndicatorStyle`

### CometChatDate

Formatted date/time label used in conversation trailing, message date separators, and sticky headers.

- **Location:** `shared_ui/src/clean_architecture/presentation/views/misc/date/cometchat_date.dart`
- **Style:** `CometChatDateStyle`

---

## 4. Bubble Widgets

Content widgets rendered inside `CometChatMessageBubble`. All accept optional `colorPalette`, `spacing`, `typography` for theme-caching optimization.

### CometChatTextBubble

- **Location:** `shared_ui/src/clean_architecture/presentation/views/bubbles/text_bubble/cometchat_text_bubble.dart`
- **Key props:** `text`, `alignment`, `formatters`, `emojiCount`, `colorPalette`, `spacing`, `typography`
- **Style:** `CometChatTextBubbleStyle`

### CometChatImageBubble

- **Location:** `shared_ui/src/clean_architecture/presentation/views/bubbles/image_bubble/cometchat_image_bubble.dart`
- **Key props:** `imageUrl`, `caption`, `colorPalette`, `spacing`
- **Style:** `CometChatImageBubbleStyle`

### CometChatVideoBubble

- **Location:** `shared_ui/src/clean_architecture/presentation/views/bubbles/video_bubble/cometchat_video_bubble.dart`
- **Key props:** `videoUrl`, `thumbnailUrl`, `colorPalette`, `spacing`
- **Style:** `CometChatVideoBubbleStyle`

### CometChatAudioBubble

- **Location:** `shared_ui/src/clean_architecture/presentation/views/bubbles/audio_bubble/cometchat_audio_bubble.dart`
- **Key props:** `audioUrl`, `title`, `colorPalette`, `spacing`, `typography`
- **Style:** `CometChatAudioBubbleStyle`

### CometChatFileBubble

- **Location:** `shared_ui/src/clean_architecture/presentation/views/bubbles/file_bubble/cometchat_file_bubble.dart`
- **Key props:** `fileUrl`, `title`, `subtitle`, `colorPalette`, `spacing`, `typography`
- **Style:** `CometChatFileBubbleStyle`

### CometChatDeletedBubble

Placeholder shown for deleted messages ("This message was deleted").

- **Location:** `shared_ui/src/clean_architecture/presentation/views/misc/deleted_bubble/cometchat_deleted_bubble.dart`
- **Style:** `CometChatDeletedBubbleStyle`

### CometChatCardBubble

Interactive card message with title, body, and action buttons.

- **Location:** `shared_ui/src/clean_architecture/presentation/views/bubbles/card_bubble/cometchat_card_bubble.dart`
- **Style:** `CardBubbleStyle`

---

## 5. Utility Widgets

### CometChatListItem

Individual row used inside list components. Combines avatar, status indicator, title, subtitle, and tail view.

- **Location:** `shared_ui/src/clean_architecture/presentation/views/misc/list_item/cometchat_list_item.dart`
- **Key props:** `avatarURL`, `avatarName`, `statusIndicatorColor`, `statusIndicatorIcon`, `title`, `hideSeparator`
- **View slots:** `subtitleView`, `tailView`, `titleView`, `leadingStateView`
- **Style:** `ListItemStyle`, `CometChatAvatarStyle`, `CometChatStatusIndicatorStyle`

### CometChatConfirmDialog

Modal confirmation dialog with title, message, confirm/cancel buttons. Call `.show()` to display.

- **Location:** `shared_ui/src/clean_architecture/presentation/views/misc/confirm_dialog/cometchat_confirm_dialog.dart`
- **Key props:** `context` (required), `title`, `messageText`, `confirmButtonText`, `cancelButtonText`, `onConfirm`, `onCancel`
- **Style:** `CometChatConfirmDialogStyle`

### CometChatActionSheet

Bottom sheet for message actions (copy, reply, delete, etc.) and attachment options.

- **Location:** `shared_ui/src/clean_architecture/presentation/views/misc/action_sheet/cometchat_action_sheet.dart`
- **Style:** `CometChatMessageOptionSheetStyle`, `CometChatAttachmentOptionSheetStyle`

---

## 6. AI Views

### CometChatAISmartReplies

Displays AI-generated smart reply suggestions as tappable chips.

- **Location:** `shared_ui/src/views/ai_smart_replies/cometchat_ai_smart_replies_view.dart`
- **Style:** `CometChatAISmartRepliesStyle`

### CometChatAIConversationStarter

Shows AI-generated conversation starters for empty chats.

- **Location:** `shared_ui/src/views/ai_conversation_starter/cometchat_ai_conversation_starter_view.dart`
- **Style:** `CometChatAIConversationStarterStyle`

### CometChatAIConversationSummary

Displays an AI-generated summary of the conversation.

- **Location:** `shared_ui/src/views/ai_conversation_summary/cometchat_ai_conversation_summary_view.dart`
- **Style:** `CometChatAIConversationSummaryStyle`

### CometChatAIAssistantBubble

Bubble for AI assistant responses with streaming text support.

- **Location:** `shared_ui/src/views/ai_assistant_bubble/cometchat_ai_assistant_bubble.dart`
- **Style:** `CometChatAIAssistantBubbleStyle`

---

## Quick Reference: Import

```dart
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';       // All chat widgets
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';      // Call widgets
```

## Quick Reference: Architecture

All components follow Clean Architecture + BLoC:
```
{component}/
├── bloc/           # BLoC, Events, State (Equatable)
├── domain/         # Use Cases, Repository interfaces
├── data/           # Repository impl, DataSources
├── di/             # ServiceLocator (singleton)
└── widgets/        # UI components
```

## Quick Reference: Theme

Always use `CometChatThemeHelper` — never hardcode colors:
```dart
final colorPalette = CometChatThemeHelper.getColorPalette(context);
final typography = CometChatThemeHelper.getTypography(context);
final spacing = CometChatThemeHelper.getSpacing(context);
```
