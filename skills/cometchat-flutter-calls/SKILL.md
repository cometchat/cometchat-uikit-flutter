---
name: cometchat-flutter-calls
description: >
  Use when implementing voice calls, video calls, or call UI with CometChat Flutter UIKit v6.
  Covers CometChatCallButtons, CometChatIncomingCall, CometChatOutgoingCall,
  CometChatOngoingCall, CometChatCallLogs, CometChatUIKitCalls, CallingConfiguration,
  CallButtonsBloc, IncomingCallBloc, OutgoingCallBloc, OngoingCallBloc, CallLogsBloc,
  CallEventService, CallOperationsServiceLocator, call_operations, call_settings,
  SessionSettingsBuilder, CallAppSettings, initiateCall, acceptCall, rejectCall,
  endSession, startSession, generateToken, CallNavigationContext,
  CometChatDisplayIncomingCallOverlay, CallScreenOverlay, native_call_kit,
  call permissions, audio call, video call, group call, call logs, call history,
  incoming call screen, outgoing call screen, ongoing call screen, call bubble,
  or "add calling to my app". Also use when seeing errors like
  "CallManager not found", "startSession null", "call token null",
  "session already started", or call-related crashes.
license: "MIT"
compatibility: "cometchat_chat_uikit ^6.0.0"
allowed-tools: "executeBash, readFile, readCode, fileSearch, listDirectory, grepSearch"
metadata:
  author: "CometChat"
  version: "1.0.0"
  tags: "cometchat flutter calls voice video calling incoming outgoing ongoing call-logs"
---

# CometChat Flutter UIKit — Calls

Voice and video calling for 1:1 and group conversations. Call functionality is built into `cometchat_chat_uikit` — no separate package needed.

## Import

```dart
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
```

The first import gives you chat components. The second gives you call-specific types.

## Rule: CALLS_VIA_UIKIT_SETTINGS

Turn calling on with `UIKitSettings.enableCalls` and configure the call UI with `UIKitSettings.callingConfiguration`. The UI Kit then sets the Calls SDK up itself — once, however many components need it: `CometChatUIKit.init` (for a restored session), `login` and `loginWithAuthToken` start call handling (the incoming call listener) and initialise and log the user into the Calls SDK; `logout` stops it and logs the Calls SDK out. Do not call `CometChatUIKitCalls.init()` yourself: it is a second, unsynchronised Calls init next to the UI Kit's own.

```dart
// ✅ CORRECT — the UI Kit sets the Calls SDK up
final settings = (UIKitSettingsBuilder()
      ..appId = appId
      ..region = region
      ..authKey = authKey
      ..enableCalls = true
      ..callingConfiguration = CallingConfiguration())
    .build();
CometChatUIKit.init(uiKitSettings: settings, onSuccess: (_) { /* route */ });

// ❌ WRONG — a second Calls init racing the UI Kit's own
CometChatUIKit.init(
  uiKitSettings: settings,
  onSuccess: (_) => CometChatUIKitCalls.init(appId, region),
);
```

## Rule: CALLS_NEED_THE_NAVIGATOR_KEY

The incoming call banner, the call screens, the refused-permission SnackBar, the `onAccept` / `onDecline` hooks (their `BuildContext`) and "Connecting..." are all shown on the navigator of `CallNavigationContext.navigatorKey`. Give it to your `MaterialApp` (or set `CallNavigationContext.navigatorKey` to your own key before `runApp`). Without it nothing is shown: an incoming call is not rung here (`onError` gets `NO_NAVIGATOR`; the call is not declined), and placing a call is refused with `NO_NAVIGATOR`.

```dart
// ✅ CORRECT — the UI Kit's call UI has a navigator to show on
MaterialApp(
  navigatorKey: CallNavigationContext.navigatorKey,
  home: const HomeScreen(),
)

// ✅ ALSO CORRECT — your own key, handed to the UI Kit before runApp
final navigatorKey = GlobalKey<NavigatorState>();
void main() {
  CallNavigationContext.navigatorKey = navigatorKey;
  runApp(MaterialApp(navigatorKey: navigatorKey, home: const HomeScreen()));
}
```

## Rule: CALLS_READY_IS_BOUNDED

With `enableCalls`, the `onSuccess` of `init`, `login` and `loginWithAuthToken` (and the futures they return) comes once the Calls SDK is set up, within about 22 s. A Calls failure or timeout never becomes `onError`; it is retried when a call, an answer or the call logs need it. Show a splash instead of holding `runApp` on `await CometChatUIKit.init(...)`.

To wait for the Calls SDK elsewhere (for example in a push/VoIP handler), `await CallEventService.instance.waitForCallsSdk()` — it returns within 22 s and never throws. Nothing needs re-initialising after a call or after logout and re-login (`CallEventService.reinitializeAfterSession()` is deprecated).

## Rule: CALL_ERRORS_REACH_ONERROR

Give the call components an `onError` (through `CallingConfiguration`: `callButtonsConfiguration`, `outgoingCallConfiguration`, `incomingCallConfiguration`; and `CometChatCallLogs.onError`) and show what arrives: a refused call or a failed join is otherwise silent. A failure the SDK reported is its own `CometChatException`, code kept. The UI Kit's own refusals use these codes:

| Code | Meaning |
|------|---------|
| `ACTIVE_CALL` | Another call is in progress on this device |
| `PERMISSION_DENIED` | Microphone (or camera) refused; `details` lists them, e.g. `microphone,camera` |
| `PERMISSION_PERMANENTLY_DENIED` | As above, and only the app's settings page can grant it now |
| `CALLS_NOT_READY` | The Calls SDK is not initialised or not logged in |
| `JOIN_TIMEOUT` | The Calls SDK did not answer the join within 30 s, or the call view did not report joining within 30 s of appearing |
| `JOIN_FAILED` | The Calls SDK refused the join; `errorParams['sdkCode']` has its code |
| `NO_NAVIGATOR` | `CallNavigationContext.navigatorKey` has no navigator: nothing is placed (a call placed meanwhile is cancelled) |
| `BLOCKED_BY_ME` | Call logs call-back: the logged-in user has blocked the callee |
| `HAS_BLOCKED_ME` | Call logs call-back: the callee has blocked the logged-in user |
| `HOST_CALLBACK_ERROR` | An incoming call's `onAccept` / `onDecline` threw something other than a `CometChatException`; `details` has it. The accept or decline went ahead |

A failed join closes the call screen at once (there is no error screen) and frees the device before `onError` runs. A failed join, a lost outgoing screen or a banner that cannot be shown frees the device at once; no endCall or reject is sent for them (Android parity), except that an outgoing call still ringing is cancelled so the callee stops ringing. The outgoing/incoming/call-screen `onError` also gets the SDK's error for a cancel, decline or end that failed because the call was already over — usually not worth showing: End or the no-answer timeout racing the callee's accept or decline, both people hanging up at once. Show the UI Kit's own codes there and log the rest. The same goes for an incoming call's accept or decline that failed because the call was already over (the caller cancelled while the permission prompt was up, or the same user answered on another device): the incoming call reports it but, without an `onError`, shows no "Something went wrong" for it. The call buttons' `onError` also gets what a group meeting's call screen reports.

If the app shows the call screen itself — `CallScreenOverlay.show(...)` after a VoIP or CallKit accept — pass `onError` there too; a failed join is otherwise silent. `CometChatCallLogs` without an `outgoingCallConfiguration` uses the `CallingConfiguration` one, as the message header does.

```dart
CallingConfiguration(
  callButtonsConfiguration: CallButtonsConfiguration(onError: showError),
  outgoingCallConfiguration: CometChatOutgoingCallConfiguration(onError: showError),
  incomingCallConfiguration: CometChatIncomingCallConfiguration(onError: showError),
)
```

## Architecture

```
call_ui/src/
├── call_buttons/          # Voice/video call buttons (CallButtonsBloc)
├── incoming_call/         # Incoming call screen (IncomingCallBloc)
├── outgoing_call/         # Outgoing call screen (OutgoingCallBloc)
├── ongoing_call/          # Active call screen — WebRTC (OngoingCallBloc)
├── call_logs/             # Call history list (CallLogsBloc + Clean Arch)
├── call_operations/       # Shared clean architecture (DI, use cases, repos)
├── call_bubble/           # Call message bubble in chat
├── call_settings/         # CometChatUIKitCalls, CallNavigationContext
├── native_call_kit/       # iOS CallKit / Android ConnectionService
├── utils/                 # CallUtils, CallStateService, CallPermissions
├── call_event_service.dart  # Centralized call event handling
└── calling_configuration.dart  # Top-level config object
```

## Components

### CometChatCallButtons

Voice and video call buttons. Typically placed in `CometChatMessageHeader`'s trailing view or standalone.

```dart
CometChatCallButtons(
  user: user,           // For 1:1 calls
  group: group,         // For group calls (meetings)
  hideVoiceCallButton: false,
  hideVideoCallButton: false,
  voiceCallIcon: Icon(Icons.call),
  videoCallIcon: Icon(Icons.videocam),
  callButtonsStyle: CometChatCallButtonsStyle(
    voiceCallIconColor: colorPalette.iconPrimary,
    videoCallIconColor: colorPalette.iconPrimary,
  ),
  outgoingCallConfiguration: CometChatOutgoingCallConfiguration(
    outgoingCallStyle: CometChatOutgoingCallStyle(...),
  ),
)
```

Call buttons are built into `CometChatMessageHeader` by default:
```dart
CometChatMessageHeader(
  user: user,
  group: group,
  hideVoiceCallButton: false,
  hideVideoCallButton: false,
)
```

### CometChatIncomingCall

Displays when the logged-in user receives a call. Supports accept/decline with custom views.

```dart
CometChatIncomingCall(
  call: call,                    // Required — the active Call object
  user: callerUser,              // Caller info for display
  onAccept: (ctx, call) { },
  onDecline: (ctx, call) { },
  disableSoundForCalls: false,             // true: no ringtone, no vibration
  customSoundForCalls: 'assets/ringtone.mp3', // the app's own asset
  incomingCallStyle: CometChatIncomingCallStyle(
    backgroundColor: colorPalette.background3,
    acceptButtonColor: colorPalette.success,
    declineButtonColor: colorPalette.error,
  ),
  // Custom view slots
  titleView: (ctx, call) => Text('Custom Title'),
  subTitleView: (ctx, call) => Text('Custom Subtitle'),
  leadingView: (ctx, call) => Icon(Icons.call),
  trailingView: (ctx, call) => CometChatAvatar(image: user.avatar),
)
```

### CometChatOutgoingCall

Displays when the logged-in user initiates a call.

```dart
CometChatOutgoingCall(
  call: call,
  user: receiverUser,
  outgoingCallStyle: CometChatOutgoingCallStyle(
    backgroundColor: colorPalette.background1,
  ),
)
```

### CometChatOngoingCall

The active call screen with WebRTC video/audio. Rendered after a call is accepted. It shows "Connecting..." until the call view arrives. While it still connects (until the native side reports the join; Android back, iOS has none), back cancels the call as End would (a 1-on-1 call is ended on the server); once it is up, back does nothing. While the screen is up, a pop entry on the top route of `CallNavigationContext.navigatorKey`'s navigator keeps back off the app's screens under the call: that route's `PopScope` callbacks get `didPop: false` (even with `canPop: true`) and `maybePop()` does not pop it. Routes pushed during the call and nested navigators (tabs, go_router shell routes) are not covered. The text follows the app's locale (English for a language the UI Kit does not ship).

```dart
CometChatOngoingCall(
  sessionSettingsBuilder: sessionSettingsBuilder,
  sessionId: call.sessionId!,
  callWorkFlow: CallWorkFlow.directCalling,
)
```

### CometChatCallLogs

Scrollable list of call history. Clean Architecture + BLoC with `CallLogsServiceLocator`.

```dart
CometChatCallLogs(
  onItemClick: (callLog) { /* Navigate or initiate call */ },
  callLogsStyle: CometChatCallLogsStyle(backgroundColor: colorPalette.background1),
)
```

### CometChatCallBubble

Message bubble for call events in the message list. Automatically rendered for call-type messages.

## CallingConfiguration

Top-level configuration object bundling all call component configs:

```dart
CallingConfiguration(
  outgoingCallConfiguration: CometChatOutgoingCallConfiguration(...),
  incomingCallConfiguration: CometChatIncomingCallConfiguration(...),
  callButtonsConfiguration: CallButtonsConfiguration(...),
  groupSessionSettingsBuilder: sessionSettingsBuilder,
)
```

## CometChatUIKitCalls API

| Method | Purpose |
|--------|---------|
| `CometChatUIKitCalls.init(appId, region)` | Initialize calls SDK (not needed with `enableCalls`: the UI Kit does it) |
| `CometChatUIKitCalls.initiateCall(call)` | Start a call |
| `CometChatUIKitCalls.acceptCall(sessionId)` | Accept incoming call |
| `CometChatUIKitCalls.rejectCall(sessionId, status)` | Reject/cancel call |
| `CometChatUIKitCalls.generateToken(sessionId)` | Generate call token |
| `CometChatUIKitCalls.startSession(sessionId, settings, {launchOngoingCallService})` | Join the WebRTC session (the SDK generates the token itself) |
| `CometChatUIKitCalls.endSession()` | Leave the call session (stops the Android ongoing-call service first) |

## Call Flow — 1:1 Direct Call

```
Caller                              Receiver
  |-- CometChatCallButtons tap ------->|
  |-- initiateCall(Call) ------------->|
  |-- CometChatOutgoingCall shown ---->|
  |                                    |-- CometChatIncomingCall shown
  |                                    |-- acceptCall(sessionId)
  |<-- onOutgoingCallAccepted ---------|
  |-- CometChatOngoingCall shown ----->|-- CometChatOngoingCall shown
  |   (each joins: startSession(sessionId, settings))
  |-- End: endSession(), then endCall -->|-- the call-ended event closes it
```

## Golden Path — Messages Screen with Calls

```dart
Scaffold(
  resizeToAvoidBottomInset: false,
  appBar: CometChatMessageHeader(
    user: user,
    group: group,
    onBack: () => Navigator.pop(context),
    hideVoiceCallButton: false,
    hideVideoCallButton: false,
  ),
  body: Column(
    children: [
      Expanded(child: CometChatMessageList(user: user, group: group)),
      CometChatMessageComposer(user: user, group: group),
    ],
  ),
)
```

## BLoC Events

### CallButtonsBloc
| Event | Purpose |
|-------|---------|
| `InitiateVoiceCall` | Start audio call (a meeting for a group) |
| `InitiateVideoCall` | Start video call (a meeting for a group) |
| `CallRejected(call)` / `CallEnded(call)` | The call these buttons placed is over; the bloc adds these itself from the call events |

### IncomingCallBloc
| Event | Purpose |
|-------|---------|
| `AcceptCall` | Accept the incoming call |
| `RejectCall` | Decline the incoming call |
| `CallCancelled` | Ringing is over for this device: the caller cancelled, the same user answered or declined on another device, or it rang 60 s with no answer. The state becomes `cancelled`; nothing is sent |

### OutgoingCallBloc
| Event | Purpose |
|-------|---------|
| `CancelCall` | End tapped: cancel the outgoing call |
| `OutgoingCallAccepted(call)` | Receiver accepted |
| `OutgoingCallRejected(call)` | Receiver declined, was busy, or the server ended the call |

### OngoingCallBloc
| Event | Purpose |
|-------|---------|
| `LoadCallingScreen` | Join: token, then the Calls SDK session |
| `EndCallButtonPressed` | Hang up (once: later ones are ignored). A 1-on-1 call: the session is left, the screen closes at once, `endCall` goes in the background and `ccCallEnded` fires when it succeeds |
| `SessionTimeout` / `OngoingCallEnded` | The session timed out or ended |

`OngoingCallState.errorCode` holds the code `onError` got when the status is `error`.

### CallLogsBloc
| Event | Purpose |
|-------|---------|
| `LoadCallLogs` | Initial load |
| `LoadMoreCallLogs` | Pagination |
| `RefreshCallLogs` | Reload from the first page |
| `InitiateCallFromLog(callLog:, context:)` | Call the log's other party back |

## Gotchas

- With `enableCalls`, the UI Kit initialises and logs in the Calls SDK itself; an extra `CometChatUIKitCalls.init()` only races it.
- After logout the UI Kit logs the Calls SDK out; the next login logs it in again. No re-init is needed.
- `CometChatUIKit.logout()` first ends this device's calls on the server (within ~3 s: a ringing incoming call declined, a ringing outgoing call cancelled, a 1-on-1 call ended; a meeting only left) and closes the call screens, then logs out. `login` as another user does the same first. A direct `CometChat.logout()` skips the server side.
- A join the Calls SDK never answers gives up after 30 s, and so does a call view that does not report the native join (`onSessionJoined`, a participant joining, or a participant list) within 30 s of appearing, counted while the app is in the foreground (not on web): the call screen closes, the session is left, `onError` gets `JOIN_TIMEOUT`, nothing is sent to the server.
- Hanging up a 1-on-1 call: the media session is left first, the screen closes at once, and `endCall` goes out in the background; `ccCallEnded` fires when the server confirms (the chat bubble and the call buttons hear it even though the screen is gone). A failed `endCall` still reaches `onError`. Only a second End tap is ignored: when the other side ends the call at about the same time (its End, or its "peer left" rule as you hang up), one `endCall` fails because the call has already ended, reaches `onError` (filter it out), and that side gets no `ccCallEnded`.
- The "peer left" rule (a 1-on-1 call ends when the other person leaves the media) is armed only once the other person has been seen in the call, so the side that joins first does not end the call while the other is still connecting. It applies to any 1-on-1 call screen (`CallWorkFlow.defaultCalling`), with or without a call record.
- A voice call is a `SessionType.audio` session; a video call a video session. On Android an audio session is a voice session (no camera, no camera dot, the earpiece by default, a headset wins). On iOS the Calls SDK (native 5.0.4) still makes it a video session: the paused camera and the hidden video toggle and camera switch are what keep it voice-only (do not drop them), iOS may ask for the camera, and call audio plays from the loudspeaker. That is the UI Kit's own settings, used when you pass no builder (the call buttons included): a builder you pass (`CometChatCallButtons.callSettingsBuilder`, `CometChatOutgoingCall(Configuration).sessionSettingsBuilder`, `CometChatIncomingCall(Configuration).callSettingsBuilder`) keeps your audio mode and layout, and the UI Kit only applies the call's type on top (a voice call: audio session, camera paused, video toggle and camera switch hidden) without changing your builder. `CallScreenOverlay.show` and `CometChatOngoingCall` use your builder as it is.
- Answering a 1-on-1 call during a group meeting leaves the meeting first, then joins the call.
- `CallScreenOverlay.dismiss(sessionId:)` closes the call screen only when it shows that call. A screen your code takes down with `dismiss()` while its call is still on leaves the call's session and frees the device; it does not end the call on the server.
- During a call the screen stays portrait; afterwards the orientation goes back before `CallStateService.isActiveCall` turns false. Android: the activity's own orientation from before the call (its manifest setting, or one set from code). iOS: the orientations in Info.plist; an orientation set from code is not restored: set it again when `isActiveCall` turns false.
- An outgoing call nobody answers is given up 45 s after it was placed: the outgoing screen sends `unanswered` and closes. Not configurable. After End (or that timeout) an accept that arrives is not joined, and a best-effort `endCall` tries to free the callee (the same request an ordinary caller hang-up sends); the screen closes when the server answers the cancel, or after 10 s at most. Once a logout has begun the screen sends nothing more and reports nothing: the logout ends the call.
- The outgoing screen hears the callee from its first build on. An app sent to the background right after placing a call builds it only when it comes back, so an answer or decline in between is missed and the call rings on until the timeout.
- The call buttons and the call logs place one call at a time, across the app: a second tap on the same component is dropped, a tap on another one gets `ACTIVE_CALL`, and the buttons stay off until the outgoing screen is up.
- The call logs' call-back makes the same checks as the call buttons (a call in progress, `CallNavigationContext.navigatorKey`, permissions) and then fetches a user callee with `CometChat.getUser` (not through the call logs repository), for the screen's name and avatar and to refuse a blocked user (`BLOCKED_BY_ME` / `HAS_BLOCKED_ME`). Set `onCallLogIconClicked` to take the icon over.
- An `onCancelled` on the outgoing screen takes End over: the cancel is then yours, and End wins does not apply (a racing accept is joined). The ringback plays on until the call ends or the screen closes; `CometChatUIKit.soundManager.stop()` stops it, as in 6.1.x. The 45 s timeout still ends a call left ringing.
- The ringback plays like a phone call: earpiece for a voice call, loudspeaker for a video call (a wired headset takes either, and so does a hands-free Bluetooth headset on iOS and Android 12+), in iOS Silent Mode, not at the Android media volume. `customSoundForCallsPackage` is only for a sound shipped in another package: leave it null for the app's own assets. A sound that cannot be found or played falls back to the app's own asset of that path, then to the UI Kit's ringback.
- The incoming call rings like the phone's own ringer would for a caller who is not a phone contact, on a player of its own:
  - Android: at the ring volume, silent in Silent/Vibrate mode and at ring volume 0 (it played at media volume in 6.1.x). Under Do Not Disturb it rings only when DND lets calls from anyone through (DND's allowed-contacts list cannot include the caller); otherwise it neither rings nor vibrates. It vibrates always in Vibrate mode, never in Silent mode, and in Sound mode as "Vibrate while ringing" (or the ramping ringer, or from Android 13 the ring vibration intensity) says: the settings differ by maker, check on yours. It keeps ringing in the background, up to the 60 s limit.
  - iOS: looping from the loudspeaker, silent with the Ring/Silent switch, at the media volume, vibrating every 2 s, pausing other apps' audio. It rings in-app only while the app is in the foreground and unlocked; back in the foreground it rings again if the call still rings and is within 60 s of the ring's start. Focus modes do not silence it. Background calls are VoIP push / CallKit's.
  - Over a group meeting (or any call session the app joined) it plays quieter and leaves the call's audio alone; on iOS it then plays through the meeting's audio, so the Silent switch does not silence it and it may not vibrate. A voice note recording or playing on iOS is left alone the same way.
  - `disableSoundForCalls` turns the ringtone and the vibration off. `CometChatUIKit.soundManager.stop()` stops the ringtone, as in 6.1.x; `soundManager.play(sound: Sound.incomingCall)` plays it the same way (once, unless `isLooping: true`).
- While the incoming ringtone rings, message sounds and any other one-shot `soundManager.play` are skipped, not queued, in Silent or Vibrate mode too. With `disableSoundForCalls` nothing rings, so they play as usual.
- The incoming call's first tap wins: after Accept or Decline both buttons are off and the other is ignored, the ringtone stops at the tap, and the default subtitle shows "Connecting..." while the accept goes through (a custom `subTitleView` shows what it shows). `onAccept` / `onDecline` run at the tap with the navigator's context (not without a navigator, nor for an ignored tap) and are side effects: the default action always goes ahead, and what they throw reaches `onError`. Do not stop the ringtone in them (the UI Kit already has; `soundManager.stop()` there gives the audio back while the call connects, and at Decline also stops the ringback of a call the user is placing). An `onAccept` that takes the banner down with `IncomingCallOverlay.dismiss()` does not stop the accept; `dismiss(sessionId:)` naming this call does (it counts as the call being over).
- An incoming call answered, declined or answered busy on another device of the same user stops ringing here (banner closed, `IncomingCallStatus.cancelled`, nothing sent), also while the permission prompt is up. Only for the user's own action: in a group call another member joining does not stop it ringing for the others.
- When the user's own call comes up (a call they placed is answered, or they join a meeting) while another incoming call still rings, that call is answered busy: its banner closes and it stops ringing.
- Accepting needs the microphone, and for a video call the camera too. Refused, the call is declined (`rejected`, `ccCallRejected`), `onError` gets `PERMISSION_DENIED` / `PERMISSION_PERMANENTLY_DENIED`, and without an `onError` the UI Kit says so in a SnackBar (with Settings when the system will not ask again).
- An incoming call nobody answers is given up on this device after 60 s (banner closed, ringtone stopped, nothing sent): a safety net for a cancel the socket lost. The 60 s are counted by the wall clock, also across a suspended iOS app. The caller's side ends the call itself (45 s for the UI Kit's outgoing screen).
- `IncomingCallOverlay.dismiss()` frees the call it removes; pass `sessionId:` when the dismiss is about one call (a cancel push), so it cannot take down another call's banner. A call dismissed by its session, declined, cancelled, given up or ended here in the last 2 minutes neither rings nor is answered busy on a late copy of its "initiated".
- An `IncomingCallBloc` you create yourself rings and runs a 60 s timer from its creation: close it when you are done (in a widget test, before the test's body ends). `CometChatIncomingCall` closes only the bloc it created.
- The banner sits 8 pt below the top safe-area inset (status bar, notch, Dynamic Island), and screen readers hear it as it appears.
- Group calls use `CometChat.Group` not `CometChat.User` on `CometChatCallButtons`.
- Incoming call handling is global: with `enableCalls` the UI Kit shows the banner itself over `CallNavigationContext.navigatorKey`'s navigator, on every screen. Do not mount your own incoming call UI per screen.
- `CallOperationsServiceLocator` must be initialized before using call BLoCs directly. UIKit widgets handle this automatically.
- Logout resets the call service locators and call state itself; no `reset()` of your own is needed.
- On iOS, CallKit integration via `native_call_kit` shows the native call UI. Ensure `Info.plist` has the `voip` background mode.
- On Android, the ongoing call foreground service shows a notification during active calls. The UI Kit's call screen starts it once the call view is back and the screen is still up (as a voice call: microphone only), and stops it when it leaves. `CometChatUIKitCalls.startSession` starts it on success unless `launchOngoingCallService: false`; since 6.2.0 `CallOperationsDataSourceImpl.startSession` (and the repository and `StartSessionUseCase` on it) does not: a call screen of your own that joins through them starts it with `CometChatOngoingCallService.launch(isVideo:)`. `CometChatUIKitCalls.endSession` stops it, whoever started it.

## Anti-Patterns

```dart
// ❌ WRONG — initialising the Calls SDK yourself
CometChatUIKit.init(
  uiKitSettings: settings,
  onSuccess: (_) => CometChatUIKitCalls.init(appId, region),
);

// ✅ CORRECT — let the UI Kit do it
final settings = (UIKitSettingsBuilder()
      // ...appId, region, authKey
      ..enableCalls = true
      ..callingConfiguration = CallingConfiguration())
    .build();
CometChatUIKit.init(uiKitSettings: settings);
```

```dart
// ❌ WRONG — showing the incoming call yourself on one screen
CometChatIncomingCall(call: call, user: user) // Only on the messages screen

// ✅ CORRECT — let the UI Kit ring on every screen: enableCalls, and the
// navigator key on the app's root MaterialApp
MaterialApp(
  navigatorKey: CallNavigationContext.navigatorKey,
  home: const HomeScreen(),
)
```

## Checklist

- [ ] `enableCalls = true` (+ `callingConfiguration`) in UIKitSettings; no `CometChatUIKitCalls.init()` of your own
- [ ] `MaterialApp(navigatorKey: CallNavigationContext.navigatorKey)` (or your key assigned to `CallNavigationContext.navigatorKey` before `runApp`): the banner, the call screens and the permission SnackBar need it
- [ ] Incoming call handling is global (app root level), not per-screen
- [ ] Camera + microphone permissions: the call components ask at call time; a refusal reaches `onError` as `PERMISSION_DENIED` / `PERMISSION_PERMANENTLY_DENIED` (offer the settings page for the latter)
- [ ] `resizeToAvoidBottomInset: false` on any Scaffold with call UI
- [ ] Call buttons visible in `CometChatMessageHeader` (default) or standalone
- [ ] Logout through `CometChatUIKit.logout()` (the UI Kit ends calls in progress, stops call handling and logs the Calls SDK out)
- [ ] `onError` on the call buttons, outgoing and incoming configurations and `CometChatCallLogs`, showing the codes above
- [ ] Android: `minSdk = 26`, ProGuard rules for `com.cometchat.**`
- [ ] iOS: `voip` background mode in `Info.plist` for CallKit
- [ ] Theme cached in `didChangeDependencies()`, not `build()`
- [ ] SDK listeners cleaned up in `dispose()`