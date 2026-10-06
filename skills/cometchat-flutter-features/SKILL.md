---
name: cometchat-flutter-features
description: >
  Enable and configure features in CometChat Flutter UIKit v6 — calls, reactions,
  smart replies, conversation starters, stickers, mentions, rich text formatting,
  message translation, link preview, and AI features. Covers what's auto-enabled,
  what needs UIKitSettings flags, and what needs CometChat dashboard toggles.
license: "MIT"
compatibility: "cometchat_chat_uikit ^6.0.0"
allowed-tools: "executeBash, readFile, readCode, fileSearch, listDirectory, grepSearch"
metadata:
  author: "CometChat"
  version: "1.0.0"
  tags: "cometchat flutter features calls reactions stickers ai smart-replies extensions"
---

# CometChat Flutter UIKit v6 — Features

How to enable, configure, and disable features in `cometchat_chat_uikit`.

## 1. Feature Categories

Every feature falls into one of three categories:

| Category | What it means | Example features | How to enable |
|---|---|---|---|
| **Auto-enabled** | Works out of the box when you render the standard components | Text/media messages, typing indicators, read receipts, reactions, message editing/deletion, threaded replies, @mentions | Just render `CometChatMessageHeader` + `CometChatMessageList` + `CometChatMessageComposer` |
| **UIKitSettings flag** | Set a property on `UIKitSettingsBuilder` before `CometChatUIKit.init()` | Voice/video calls (`enableCalls: true`), presence/typing (`subscriptionType`) | Set the flag → init |
| **Dashboard-toggle** | Enable the extension in the CometChat dashboard. UIKit auto-wires the UI once enabled. | Polls, stickers, smart replies, conversation starters, conversation summary, message translation, link preview, collaborative document, collaborative whiteboard, image moderation, thumbnail generation | Toggle on in dashboard → restart app |

## 2. Auto-Enabled Features

These work immediately when you render the standard message components:

| Feature | Component | Notes |
|---|---|---|
| Text messages | `CometChatMessageList` + `CometChatMessageComposer` | Default message type |
| Image/video/audio/file messages | `CometChatMessageComposer` attachment options | Media picker built in |
| Read receipts | `CometChatMessageList` | Blue double-check. Disable with `disableReceipts: true` |
| Typing indicators | `CometChatMessageHeader` subtitle | Requires `subscriptionType` set in UIKitSettings |
| Reactions | `CometChatMessageList` | Long-press any message. Disable with `disableReactions: true` |
| Message editing/deletion | `CometChatMessageList` long-press menu | Own messages only |
| Threaded replies | `CometChatMessageList` | Controlled by `hideReplyInThreadOption` |
| Reply (quote) | `CometChatMessageList` | Swipe-to-reply via `enableSwipeToReply: true` (default) |
| @Mentions | `CometChatMessageComposer` | Type `@` to trigger. Uses `CometChatMentionsFormatter` |
| Rich text (markdown) | `CometChatMessageComposer` | Bold, italic, strikethrough, code, lists, blockquote, links via WYSIWYG toolbar |
| Group action messages | `CometChatMessageList` | Member joined/left/kicked. Hide with `hideGroupActionMessages: true` |

## 3. UIKitSettings Features

Set these on `UIKitSettingsBuilder` before calling `CometChatUIKit.init()`:

### Calls

```dart
final settings = (UIKitSettingsBuilder()
      ..appId = 'YOUR_APP_ID'
      ..region = 'us'
      ..authKey = 'YOUR_AUTH_KEY'
      ..subscriptionType = CometChatSubscriptionType.allUsers
      ..enableCalls = true  // ← enables voice & video calls
      ..callingConfiguration = CallingConfiguration(
           outgoingCallConfiguration: CometChatOutgoingCallConfiguration(...),
           incomingCallConfiguration: CometChatIncomingCallConfiguration(...),
           callButtonsConfiguration: CallButtonsConfiguration(...),
           groupSessionSettingsBuilder: sessionSettingsBuilder,
         ))
    .build();
```

When `enableCalls` is `true`, the UIKit:
1. Initializes `CometChatUIKitCalls` after chat SDK init
2. Registers call message templates (call bubbles in message list)
3. Shows voice/video call buttons in `CometChatMessageHeader`

For detailed call implementation, see the `cometchat-flutter-calls` skill.

### Presence & Typing

```dart
..subscriptionType = CometChatSubscriptionType.allUsers
```

Options: `allUsers`, `roles`, `friends`. Controls which users' presence and typing events you receive.

### Date/Time Formatting

```dart
..dateTimeFormatterCallback = (DateTime dateTime) => 'custom format'
```

## 4. Dashboard-Toggle Features

These are extensions enabled in the CometChat dashboard (app.cometchat.com → Extensions). Once enabled, the UIKit auto-wires the UI.

| Extension | UI surface when enabled | Extension directory |
|---|---|---|
| Polls | "Create Poll" option in composer attachment menu | `extensions/polls/` |
| Stickers | Sticker picker button next to composer | `extensions/stickers/` |
| Smart Replies | Chip suggestions above composer after incoming message | AI view: `views/ai_smart_replies/` |
| Conversation Starters | Suggested messages when chat is empty | AI view: `views/ai_conversation_starter/` |
| Conversation Summary | Summary panel above composer | AI view: `views/ai_conversation_summary/` |
| Message Translation | "Translate" option in message long-press menu | `extensions/message_translation/` |
| Link Preview | Rich preview card for URLs in messages | `extensions/link_preview/` |
| Collaborative Document | "Document" option in composer attachment menu | `extensions/collaborative_document/` |
| Collaborative Whiteboard | "Whiteboard" option in composer attachment menu | `extensions/collaborative_whiteboard/` |
| Image Moderation | Blurs inappropriate images automatically | `extensions/image_moderation/` |
| Thumbnail Generation | Auto-generates thumbnails for images/videos | `extensions/thumbnail_generation/` |

## 5. Calls

Voice and video calling for 1:1 and group conversations. Built into `cometchat_chat_uikit` — no separate package.

```dart
// Enable in UIKitSettings
..enableCalls = true

// Call buttons appear automatically in CometChatMessageHeader
CometChatMessageHeader(
  user: user,
  group: group,
  hideVoiceCallButton: false,  // default
  hideVideoCallButton: false,  // default
)
```

`CallingConfiguration` bundles all call component configs:

```dart
CallingConfiguration(
  outgoingCallConfiguration: CometChatOutgoingCallConfiguration(...),
  incomingCallConfiguration: CometChatIncomingCallConfiguration(...),
  callButtonsConfiguration: CallButtonsConfiguration(...),
  groupSessionSettingsBuilder: sessionSettingsBuilder,
)
```

For the full call flow, init sequence, and gotchas, see the `cometchat-flutter-calls` skill.

## 6. AI Features

AI features require enabling the corresponding extension in the CometChat dashboard. The UIKit provides built-in views for each.

### Smart Replies

Suggested reply chips shown above the composer after receiving a message.

```dart
CometChatMessageList(
  user: user,
  group: group,
  enableSmartReplies: true,
  smartRepliesDelayDuration: 10000,  // ms before showing suggestions
  smartRepliesKeywords: ['what', 'when', 'why', 'who', 'where', 'how', '?'],
)
```

### Conversation Starters

Suggested messages shown when the chat is empty to help start a conversation.

```dart
CometChatMessageList(
  user: user,
  group: group,
  enableConversationStarters: true,
)
```

### Conversation Summary

A summary of the conversation shown in a panel. Available via the AI option sheet in the message header.

### AI Assistant

Full AI chat assistant with chat history. Uses Clean Architecture + BLoC at `chat_ui/src/ai_assistant_chat_history/`. The chat history button appears in `CometChatMessageHeader` for AI-type users.

Related props on `CometChatMessageHeader`:
- `hideChatHistoryButton` — hide the AI chat history button
- `hideNewChatButton` — hide the new AI chat button
- `chatHistoryButtonClick` — custom callback for chat history tap
- `newChatButtonClick` — custom callback for new chat tap

## 7. Rich Text & Formatters

The composer supports rich text formatting via the WYSIWYG toolbar (bold, italic, strikethrough, inline code, ordered/bullet lists, blockquote, links, code blocks).

### Text Formatters

Pass `textFormatters` to both `CometChatMessageList` and `CometChatMessageComposer` for consistent rendering:

```dart
// Available formatters (in shared_ui/src/formatter/)
// - CometChatMentionsFormatter  — @mention users
// - CometChatUrlFormatter       — auto-link URLs
// - CometChatPhoneNumberFormatter — auto-link phone numbers
// - CometChatEmailFormatter     — auto-link emails
// - MarkdownTextFormatter       — render markdown in bubbles

CometChatMessageList(
  user: user,
  group: group,
  textFormatters: [
    CometChatMentionsFormatter(),
    CometChatUrlFormatter(),
  ],
)

CometChatMessageComposer(
  user: user,
  group: group,
  textFormatters: [
    CometChatMentionsFormatter(),
  ],
)
```

### Mentions

`CometChatMentionsFormatter` is the primary formatter for @mentions. Type `@` in the composer to trigger the user suggestion list.

Related props:
- `disableMentions` — disable @mention suggestions on both list and composer
- `disableMentionAll` — disable the @all mention option (composer)
- `mentionAllLabel` / `mentionAllLabelId` — customize the @all label

### Rich Text Toolbar

The composer's WYSIWYG toolbar is the active formatting system. Configure via:

```dart
CometChatMessageComposer(
  user: user,
  group: group,
  richTextConfiguration: RichTextConfiguration(...),
  richTextToolbarView: (context) => CustomToolbar(),
  onRichTextFormatApplied: (formatType) { },
)
```

## 8. Reactions

Reactions are auto-enabled. Users long-press a message to add emoji reactions.

### Disabling Reactions

```dart
CometChatMessageList(
  user: user,
  group: group,
  disableReactions: true,  // hides reaction UI entirely
)
```

### Customizing Reactions

```dart
CometChatMessageList(
  user: user,
  group: group,
  favoriteReactions: ['👍', '❤️', '😂', '😮', '😢', '🙏'],
  addReactionIcon: Icon(Icons.add_reaction),
  onReactionClick: (reaction) { },
  onReactionLongPress: (reaction) { },
  onReactionListItemClick: (reaction) { },
  reactionsRequestBuilder: ReactionsRequestBuilder()..limit = 10,
  hideReactionOption: true,  // hide "React" from long-press menu
)
```

## 9. Disabling Features

Most features can be hidden or disabled via component props.

### CometChatMessageHeader

| Prop | Type | Effect |
|---|---|---|
| `hideVoiceCallButton` | `bool?` | Hide voice call button |
| `hideVideoCallButton` | `bool?` | Hide video call button |
| `hideChatHistoryButton` | `bool?` | Hide AI chat history button |
| `hideNewChatButton` | `bool?` | Hide new AI chat button |
| `usersStatusVisibility` | `bool?` | Show/hide online status indicator |

### CometChatMessageList

| Prop | Type | Default | Effect |
|---|---|---|---|
| `disableReactions` | `bool` | `false` | Disable all reaction UI |
| `disableReceipts` | `bool` | `false` | Hide read/delivered receipts |
| `disableSoundForMessages` | `bool` | `false` | Mute message sounds |
| `hideDeletedMessages` | `bool` | `false` | Hide deleted message placeholders |
| `hideReplies` | `bool` | `true` | Hide reply count on messages |
| `hideThreadView` | `bool?` | — | Hide thread reply indicator |
| `hideDateSeparator` | `bool` | `false` | Hide date separators |
| `hideStickyDate` | `bool` | `false` | Hide sticky date header |
| `hideGroupActionMessages` | `bool` | `false` | Hide "X joined" / "X left" messages |
| `hideReplyInThreadOption` | `bool` | `false` | Remove "Reply in Thread" from long-press menu |
| `hideReplyOption` | `bool` | `false` | Remove "Reply" from long-press menu |
| `hideCopyMessageOption` | `bool` | `false` | Remove "Copy" from long-press menu |
| `hideDeleteMessageOption` | `bool` | `false` | Remove "Delete" from long-press menu |
| `hideEditMessageOption` | `bool` | `false` | Remove "Edit" from long-press menu |
| `hideMessageInfoOption` | `bool` | `false` | Remove "Message Info" from long-press menu |
| `hideMessagePrivatelyOption` | `bool` | `false` | Remove "Message Privately" from long-press menu |
| `hideReactionOption` | `bool` | `false` | Remove "React" from long-press menu |
| `hideTranslateMessageOption` | `bool` | `false` | Remove "Translate" from long-press menu |
| `hideShareMessageOption` | `bool` | `false` | Remove "Share" from long-press menu |
| `hideSuggestedMessages` | `bool` | `false` | Hide AI suggested messages |
| `enableSmartReplies` | `bool` | `false` | Enable smart reply suggestions |
| `enableConversationStarters` | `bool` | `false` | Enable conversation starter suggestions |
| `enableSwipeToReply` | `bool` | `true` | Enable swipe-to-reply gesture |

### CometChatMessageComposer

| Prop | Type | Effect |
|---|---|---|
| `hideVoiceRecordingButton` | `bool?` | Hide voice recording button |
| `hideSendButton` | `bool?` | Hide send button |
| `hideAttachmentButton` | `bool?` | Hide attachment (paperclip) button |
| `hideStickersButton` | `bool?` | Hide stickers button |
| `hidePollsOption` | `bool?` | Hide "Create Poll" from attachment menu |
| `hideCollaborativeDocumentOption` | `bool?` | Hide "Document" from attachment menu |
| `hideCollaborativeWhiteboardOption` | `bool?` | Hide "Whiteboard" from attachment menu |
| `hideAudioAttachmentOption` | `bool?` | Hide audio from attachment menu |
| `hideFileAttachmentOption` | `bool?` | Hide file from attachment menu |
| `hideImageAttachmentOption` | `bool?` | Hide image from attachment menu |
| `hideVideoAttachmentOption` | `bool?` | Hide video from attachment menu |
| `hideTakePhotoOption` | `bool?` | Hide "Take Photo" from attachment menu |
| `disableTypingEvents` | `bool` | Stop sending typing indicators |
| `disableSoundForMessages` | `bool` | Mute send message sound |
| `disableMentions` | `bool?` | Disable @mention suggestions |
| `disableMentionAll` | `bool` | Disable @all mention |

## Extensions Directory

All extension implementations live under `chat_ui/src/extensions/`:

```
extensions/
├── collaborative/                  # Shared collaborative bubble
├── collaborative_document/         # Document extension
├── collaborative_whiteboard/       # Whiteboard extension
├── image_moderation/               # Image moderation filter
├── link_preview/                   # Link preview bubble
├── message_translation/            # Translation bubble + option
├── polls/                          # Poll creation + bubble
├── stickers/                       # Sticker keyboard + bubble
├── thumbnail_generation/           # Thumbnail config
├── extension_constants.dart        # Extension ID constants
├── extension_moderator.dart        # Extension moderator
└── extension.dart                  # Base extension class
```

## Quick Reference — Enabling Everything

```dart
final settings = (UIKitSettingsBuilder()
      ..appId = 'YOUR_APP_ID'
      ..region = 'us'
      ..authKey = 'YOUR_AUTH_KEY'
      ..subscriptionType = CometChatSubscriptionType.allUsers
      ..enableCalls = true)
    .build();

// With enableCalls, init completes once the Calls SDK is set up as well
// (bounded, about 22 s at most): await it behind a splash, not before runApp.
await CometChatUIKit.init(uiKitSettings: settings);

// Then in your messages screen:
CometChatMessageList(
  user: user,
  group: group,
  enableSmartReplies: true,
  enableConversationStarters: true,
  enableSwipeToReply: true,
  textFormatters: [CometChatMentionsFormatter()],
)

CometChatMessageComposer(
  user: user,
  group: group,
  textFormatters: [CometChatMentionsFormatter()],
)

CometChatMessageHeader(
  user: user,
  group: group,
  // Call buttons shown automatically when enableCalls = true
)
```

Dashboard extensions (polls, stickers, translation, link preview, collaborative doc/whiteboard) are auto-wired once enabled in the CometChat dashboard — no code changes needed.
