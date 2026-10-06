/// The 1:1 call action bubbles, rendered: text, icon and colour (round 5,
/// P5-C10; owner's P5-D08 A and P5-D09 B), and the call bubbles hidden when
/// calling is off (P5-D11 A).
///
/// One rule decides all three: a call is missed when it went unanswered or
/// was cancelled, for whoever did not start it. A rejected or busy call reads
/// the same on both sides, because the chat SDK gives realtime and history
/// call messages the user who acted as `callInitiator`. The icon wears the
/// text's colour in both templates; the video one painted a normally ended
/// call red.
///
///   flutter test test/chat_ui/message_list/call_bubbles_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _me = User(uid: 'me', name: 'Me');

/// Who the call message names as `callInitiator`.
enum _By { me, other, nobody, group }

const _unknownStatus = 'some_new_status';

const _statuses = [
  CallStatusConstants.initiated,
  CallStatusConstants.ongoing,
  CallStatusConstants.ended,
  CallStatusConstants.cancelled,
  CallStatusConstants.unanswered,
  CallStatusConstants.rejected,
  CallStatusConstants.busy,
  _unknownStatus,
];

Call _call(_By by, String status, String type) => Call(
  id: 1,
  sessionId: 's1',
  callStatus: status,
  callInitiator: switch (by) {
    _By.me => _me,
    _By.other => User(uid: 'them', name: 'Them'),
    _By.nobody => null,
    _By.group => Group(guid: 'g1', name: 'Group', type: 'public'),
  },
  sender: _me,
  receiverUid: 'them',
  type: type,
  receiverType: ReceiverTypeConstants.user,
  sentAt: DateTime(2026, 10, 1, 10),
);

bool _missed(_By by, String status) =>
    by != _By.me &&
    (status == CallStatusConstants.unanswered ||
        status == CallStatusConstants.cancelled);

/// The P5-D08 A table.
String _expectedText(Translations t, _By by, String status, String type) {
  final video = type == CallTypeConstants.videoCall;
  if (_missed(by, status)) return video ? t.missedVideoCall : t.missedVoiceCall;
  return switch (status) {
    CallStatusConstants.initiated =>
      by == _By.me ? t.outgoingCall : t.incomingCall,
    CallStatusConstants.ongoing => t.callAccepted,
    CallStatusConstants.ended => t.callEnded,
    CallStatusConstants.cancelled => t.callCancelled,
    CallStatusConstants.unanswered => t.callUnanswered,
    CallStatusConstants.rejected => t.callRejected,
    CallStatusConstants.busy => t.callBusy,
    _ => video ? t.videoCall : t.voiceCall,
  };
}

/// What the bubble rendered: its text, the colour of that text, the icon's
/// asset and the icon's colour.
typedef _Rendered = ({
  String text,
  Color? textColor,
  String asset,
  Color? iconColor,
  CometChatColorPalette palette,
  Translations translations,
});

Future<_Rendered> _render(WidgetTester tester, Call call) async {
  final template = MessageTemplateUtils.getMessageTemplate(
    messageType: call.type,
    messageCategory: MessageCategoryConstants.call,
  )!;
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (context) {
            captured = context;
            return template.contentView!(
                  call,
                  context,
                  BubbleAlignment.center,
                ) ??
                const SizedBox();
          },
        ),
      ),
    ),
  );
  final bubble = find.byType(CometChatActionBubble);
  final text = tester.widget<Text>(
    find.descendant(of: bubble, matching: find.byType(Text)),
  );
  final image = tester.widget<Image>(
    find.descendant(of: bubble, matching: find.byType(Image)),
  );
  return (
    text: text.data!,
    textColor: text.style?.color,
    asset: (image.image as AssetImage).assetName,
    iconColor: image.color,
    palette: CometChatThemeHelper.getColorPalette(captured),
    translations: Translations.of(captured),
  );
}

void main() {
  setUp(() {
    CometChatUIKit.authenticationSettings =
        (UIKitSettingsBuilder()
              ..appId = 'app'
              ..region = 'us'
              ..enableCalls = true)
            .build();
    CometChatUIKit.loggedInUser = _me;
  });

  tearDown(() {
    CometChatUIKit.authenticationSettings = null;
    CometChatUIKit.loggedInUser = null;
  });

  for (final type in [
    CallTypeConstants.audioCall,
    CallTypeConstants.videoCall,
  ]) {
    for (final by in _By.values) {
      testWidgets('P5-C10 / P5-E26: the $type bubble, started by ${by.name}: '
          'every status renders its text, and the icon wears the text colour, '
          'red only when missed', (tester) async {
        for (final status in _statuses) {
          final r = await _render(tester, _call(by, status, type));
          final reason = '$status, started by ${by.name}';
          expect(
            r.text,
            ' ${_expectedText(r.translations, by, status, type)}',
            reason: reason,
          );
          expect(r.iconColor, r.textColor, reason: reason);
          expect(
            r.textColor,
            _missed(by, status) ? r.palette.error : r.palette.textSecondary,
            reason: reason,
          );
          final audio = type == CallTypeConstants.audioCall;
          if (_missed(by, status)) {
            expect(
              r.asset,
              audio ? AssetConstants.audioMissed : AssetConstants.videoMissed,
              reason: reason,
            );
          }
        }
      });
    }
  }

  group('the manual checks, as the bubbles render them', () {
    testWidgets('P5-N10: an accepted, then ended, voice call reads by its '
        'outcome on both phones and is never red', (tester) async {
      for (final (by, opening) in [(_By.me, 'outgoing'), (_By.other, 'in')]) {
        final initiated = await _render(
          tester,
          _call(by, CallStatusConstants.initiated, CallTypeConstants.audioCall),
        );
        final t = initiated.translations;
        expect(
          initiated.text,
          ' ${opening == 'outgoing' ? t.outgoingCall : t.incomingCall}',
        );
        for (final (status, text) in [
          (CallStatusConstants.ongoing, t.callAccepted),
          (CallStatusConstants.ended, t.callEnded),
        ]) {
          final r = await _render(
            tester,
            _call(by, status, CallTypeConstants.audioCall),
          );
          expect(r.text, ' $text');
          expect(r.textColor, r.palette.textSecondary);
          expect(r.iconColor, r.palette.textSecondary);
        }
      }
    });

    testWidgets('P5-N11: a video call ended by the callee is grey, icon and '
        'text, on both phones', (tester) async {
      for (final by in [_By.me, _By.other]) {
        final r = await _render(
          tester,
          _call(by, CallStatusConstants.ended, CallTypeConstants.videoCall),
        );
        expect(r.text, ' ${r.translations.callEnded}');
        expect(r.iconColor, r.palette.textSecondary, reason: by.name);
        expect(r.iconColor, isNot(r.palette.error), reason: by.name);
      }
    });

    testWidgets('P5-N12: a cancelled call: "Call cancelled" in grey for the '
        'caller, "Missed voice call" in red for the callee', (tester) async {
      final caller = await _render(
        tester,
        _call(
          _By.me,
          CallStatusConstants.cancelled,
          CallTypeConstants.audioCall,
        ),
      );
      expect(caller.text, ' ${caller.translations.callCancelled}');
      expect(caller.textColor, caller.palette.textSecondary);
      expect(caller.asset, AssetConstants.callNoFill);

      final callee = await _render(
        tester,
        _call(
          _By.other,
          CallStatusConstants.cancelled,
          CallTypeConstants.audioCall,
        ),
      );
      expect(callee.text, ' ${callee.translations.missedVoiceCall}');
      expect(callee.textColor, callee.palette.error);
      expect(callee.iconColor, callee.palette.error);
      expect(callee.asset, AssetConstants.audioMissed);
    });

    testWidgets('P5-N13: a declined call reads "Call rejected" in grey on '
        'both phones, whoever the SDK names as initiator', (tester) async {
      for (final by in _By.values) {
        final r = await _render(
          tester,
          _call(by, CallStatusConstants.rejected, CallTypeConstants.audioCall),
        );
        expect(r.text, ' ${r.translations.callRejected}', reason: by.name);
        expect(r.textColor, r.palette.textSecondary, reason: by.name);
        expect(r.asset, AssetConstants.callNoFill, reason: by.name);
      }
    });

    testWidgets('P5-E24: a busy call reads "Call busy" in grey on both '
        'phones', (tester) async {
      for (final by in _By.values) {
        final r = await _render(
          tester,
          _call(by, CallStatusConstants.busy, CallTypeConstants.videoCall),
        );
        expect(r.text, ' ${r.translations.callBusy}', reason: by.name);
        expect(r.textColor, r.palette.textSecondary, reason: by.name);
        expect(r.asset, AssetConstants.videocamNoFill, reason: by.name);
      }
    });

    testWidgets('a call with no initiator renders without an error', (
      tester,
    ) async {
      // callInitiator was hard-cast to User and threw a TypeError.
      final r = await _render(
        tester,
        _call(
          _By.nobody,
          CallStatusConstants.unanswered,
          CallTypeConstants.videoCall,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(r.text, ' ${r.translations.missedVideoCall}');
    });
  });

  group('P5-D11 A: calling off hides the call and meeting bubbles', () {
    test('no call or meeting templates, types or categories', () {
      CometChatUIKit.authenticationSettings =
          (UIKitSettingsBuilder()
                ..appId = 'app'
                ..region = 'us'
                ..enableCalls = false)
              .build();

      for (final type in [
        CallTypeConstants.audioCall,
        CallTypeConstants.videoCall,
      ]) {
        expect(
          MessageTemplateUtils.getMessageTemplate(
            messageType: type,
            messageCategory: MessageCategoryConstants.call,
          ),
          isNull,
          reason: type,
        );
      }
      expect(
        MessageTemplateUtils.getMessageTemplate(
          messageType: MessageTypeConstants.meeting,
          messageCategory: MessageCategoryConstants.custom,
        ),
        isNull,
      );
      final templates = MessageTemplateUtils.getAllMessageTemplates();
      expect(
        templates.where(
          (t) =>
              t.category == MessageCategoryConstants.call ||
              t.type == MessageTypeConstants.meeting,
        ),
        isEmpty,
      );
      expect(
        MessageTemplateUtils.getAllMessageCategories(),
        isNot(contains(MessageCategoryConstants.call)),
      );
      expect(
        MessageTemplateUtils.getAllMessageTypes(),
        isNot(contains(MessageTypeConstants.meeting)),
      );
    });

    test('calling on brings all of them back', () {
      final templates = MessageTemplateUtils.getAllMessageTemplates();
      expect(
        templates.where((t) => t.category == MessageCategoryConstants.call),
        hasLength(2),
      );
      expect(
        templates.where((t) => t.type == MessageTypeConstants.meeting),
        hasLength(1),
      );
      expect(
        MessageTemplateUtils.getAllMessageCategories(),
        contains(MessageCategoryConstants.call),
      );
      expect(
        MessageTemplateUtils.getAllMessageTypes(),
        contains(MessageTypeConstants.meeting),
      );
    });
  });
}
