/// Behaviour tests for [CallUtils].
///
/// [CallUtils] is the pure decision layer behind every call surface: it turns
/// a `Call` or a `CallLog` plus the logged-in user into the label, icon and
/// colour the list and the bubble show. Nothing in it touches the SDK
/// statics, and both `Call` and `CallLog` are ordinary constructible models,
/// so the whole matrix — status × direction × media type — is reachable from a
/// VM test.
///
/// The interesting property is the *direction* split, and where it stops:
/// a cancelled or unanswered call reads "Call cancelled" to the caller and
/// "Missed voice call" to the person who was called, while a rejected or busy
/// call reads the same on both sides (round 5, P5-D08/P5-D09: the chat SDK
/// gives realtime call messages the user who acted as `callInitiator`). Every
/// status is asserted from every initiator: me, someone else, none, a group.
///
/// Labels are compared against `Translations.of(context)` rather than literal
/// English so the tests pin the mapping, not the copy.
///
///   flutter test test/call_ui/call_utils_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────

User _user(String uid) => User(uid: uid, name: 'User $uid');

/// A 1:1 call [status] between [initiator] and the fixed receiver.
Call _call({
  required String status,
  required String initiator,
  String type = CallTypeConstants.audioCall,
  String receiverType = ReceiverTypeConstants.user,
  User? sender,
}) => Call(
  callStatus: status,
  callInitiator: _user(initiator),
  receiverUid: 'them',
  type: type,
  receiverType: receiverType,
  sender: sender,
);

/// A call log [status] whose initiator is [initiatorUid].
CallLog _log({
  required String status,
  String initiatorUid = 'me',
  String receiverUid = 'them',
  String type = CallTypeConstants.audioCall,
}) => CallLog(
  status: status,
  type: type,
  initiator: CallUser(uid: initiatorUid, name: 'Initiator'),
  receiver: CallUser(uid: receiverUid, name: 'Receiver'),
);

final _me = _user('me');

/// A call log [status] someone else started, with the logged-in user as the
/// receiver.
CallLog _incomingLog(String status) =>
    _log(status: status, initiatorUid: 'them', receiverUid: 'me');

/// A status the UI Kit does not know.
const _unknownStatus = 'some_new_status';

/// Every call status, plus one the UI Kit does not know.
const _allStatuses = [
  CallStatusConstants.initiated,
  CallStatusConstants.ongoing,
  CallStatusConstants.ended,
  CallStatusConstants.cancelled,
  CallStatusConstants.unanswered,
  CallStatusConstants.rejected,
  CallStatusConstants.busy,
  _unknownStatus,
];

/// Who a call's `callInitiator` names: the logged-in user, someone else,
/// nobody, or a group (both of the last two used to throw a TypeError).
enum _By { me, other, nobody, group }

/// A 1:1 call [status] whose initiator is [by].
Call _callBy(
  _By by,
  String status, {
  String type = CallTypeConstants.audioCall,
}) => Call(
  callStatus: status,
  callInitiator: switch (by) {
    _By.me => _me,
    _By.other => _user('them'),
    _By.nobody => null,
    _By.group => Group(guid: 'g1', name: 'Group', type: 'public'),
  },
  receiverUid: 'them',
  type: type,
  receiverType: ReceiverTypeConstants.user,
);

/// Runs [body] with a [BuildContext] that has the UI Kit's translations.
Future<void> _withContext(
  WidgetTester tester,
  void Function(BuildContext context) body,
) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  body(captured);
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // isLoggedInUser
  // ═══════════════════════════════════════════════════════════════════════════

  group('isLoggedInUser', () {
    test('matches on uid', () {
      expect(CallUtils.isLoggedInUser(_user('me'), _me), isTrue);
      expect(CallUtils.isLoggedInUser(_user('them'), _me), isFalse);
    });

    test('a null on either side is not a match', () {
      // Both nulls must read as "not me": treating an unknown initiator as the
      // logged-in user would label every incoming call as outgoing.
      expect(CallUtils.isLoggedInUser(null, _me), isFalse);
      expect(CallUtils.isLoggedInUser(_user('me'), null), isFalse);
      expect(CallUtils.isLoggedInUser(null, null), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Media-type predicates
  // ═══════════════════════════════════════════════════════════════════════════

  group('media type', () {
    test('isVideoCall is true only for the video type', () {
      expect(
        CallUtils.isVideoCall(
          _call(
            status: CallStatusConstants.ended,
            initiator: 'me',
            type: CallTypeConstants.videoCall,
          ),
        ),
        isTrue,
      );
      expect(
        CallUtils.isVideoCall(_call(status: 'ended', initiator: 'me')),
        isFalse,
      );
    });

    test('isAudioCall is true only for the audio type', () {
      expect(CallUtils.isAudioCall(_log(status: 'ended')), isTrue);
      expect(
        CallUtils.isAudioCall(
          _log(status: 'ended', type: CallTypeConstants.videoCall),
        ),
        isFalse,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // getCallStatus — the label for a Call message (P5-C10, owner's P5-D08 A)
  // ═══════════════════════════════════════════════════════════════════════════

  group('getCallStatus', () {
    testWidgets('P5-C10: every status reads the P5-D08 table, from every '
        'initiator, for voice and video', (tester) async {
      await _withContext(tester, (c) {
        final t = Translations.of(c);
        for (final video in [false, true]) {
          final type = video
              ? CallTypeConstants.videoCall
              : CallTypeConstants.audioCall;
          final missed = video ? t.missedVideoCall : t.missedVoiceCall;
          final asCaller = <String, String>{
            CallStatusConstants.initiated: t.outgoingCall,
            CallStatusConstants.ongoing: t.callAccepted,
            CallStatusConstants.ended: t.callEnded,
            CallStatusConstants.cancelled: t.callCancelled,
            CallStatusConstants.unanswered: t.callUnanswered,
            CallStatusConstants.rejected: t.callRejected,
            CallStatusConstants.busy: t.callBusy,
            _unknownStatus: video ? t.videoCall : t.voiceCall,
          };
          final asCallee = <String, String>{
            CallStatusConstants.initiated: t.incomingCall,
            CallStatusConstants.ongoing: t.callAccepted,
            CallStatusConstants.ended: t.callEnded,
            CallStatusConstants.cancelled: missed,
            CallStatusConstants.unanswered: missed,
            CallStatusConstants.rejected: t.callRejected,
            CallStatusConstants.busy: t.callBusy,
            _unknownStatus: video ? t.videoCall : t.voiceCall,
          };
          for (final by in _By.values) {
            final table = by == _By.me ? asCaller : asCallee;
            for (final entry in table.entries) {
              expect(
                CallUtils.getCallStatus(
                  c,
                  _callBy(by, entry.key, type: type),
                  _me,
                ),
                ' ${entry.value}',
                reason: '${entry.key}, started by ${by.name}, $type',
              );
            }
          }
        }
      });
    });

    testWidgets('P5-N13 / P5-E24: a declined or busy call never reads as '
        'missed, even with the callee as callInitiator', (tester) async {
      // The chat SDK gives realtime and history call messages the user who
      // acted as callInitiator, so the caller's bubble for a call the callee
      // declined names the callee. It used to read "Missed Call" there.
      await _withContext(tester, (c) {
        final t = Translations.of(c);
        expect(
          CallUtils.getCallStatus(
            c,
            _callBy(_By.other, CallStatusConstants.rejected),
            _me,
          ),
          ' ${t.callRejected}',
        );
        expect(
          CallUtils.getCallStatus(
            c,
            _callBy(_By.other, CallStatusConstants.busy),
            _me,
          ),
          ' ${t.callBusy}',
        );
      });
    });

    testWidgets('P5-E25: a cancelled call reads the same live and reloaded', (
      tester,
    ) async {
      // Live, the caller's own cancel names the caller; reloaded, so does the
      // REST copy. Both sides keep their text.
      await _withContext(tester, (c) {
        final t = Translations.of(c);
        final cancelled = _callBy(_By.other, CallStatusConstants.cancelled);
        expect(
          CallUtils.getCallStatus(c, cancelled, _me),
          ' ${t.missedVoiceCall}',
        );
        expect(
          CallUtils.getCallStatus(c, cancelled, _user('them')),
          ' ${t.callCancelled}',
        );
      });
    });

    testWidgets('a group call is never missed: its cancel reads as cancelled', (
      tester,
    ) async {
      await _withContext(tester, (c) {
        final t = Translations.of(c);
        expect(
          CallUtils.getCallStatus(
            c,
            _call(
              status: CallStatusConstants.cancelled,
              initiator: 'them',
              receiverType: ReceiverTypeConstants.group,
            ),
            _me,
          ),
          ' ${t.callCancelled}',
        );
      });
    });

    testWidgets('a non-call message yields just the space', (tester) async {
      await _withContext(tester, (c) {
        expect(
          CallUtils.getCallStatus(
            c,
            TextMessage(
              text: 'hi',
              receiverUid: 'them',
              receiverType: ReceiverTypeConstants.user,
              type: MessageTypeConstants.text,
            ),
            _me,
          ),
          ' ',
        );
      });
    });

    testWidgets('a null logged-in user reads every call as incoming', (
      tester,
    ) async {
      await _withContext(tester, (c) {
        final t = Translations.of(c);
        // Nobody signed in is never the initiator, so a signed-out render
        // degrades to the callee's wording rather than throwing.
        expect(
          CallUtils.getCallStatus(
            c,
            _call(status: CallStatusConstants.initiated, initiator: 'me'),
            null,
          ),
          ' ${t.incomingCall}',
        );
      });
    });
  });
  // ═══════════════════════════════════════════════════════════════════════════
  // getLastMessageForGroupCall
  // ═══════════════════════════════════════════════════════════════════════════

  group('getLastMessageForGroupCall', () {
    testWidgets('names the sender for someone else, and says "You" for me', (
      tester,
    ) async {
      await _withContext(tester, (c) {
        final t = Translations.of(c);
        final fromThem = _call(
          status: CallStatusConstants.initiated,
          initiator: 'them',
          receiverType: ReceiverTypeConstants.group,
          sender: _user('them'),
        );
        final fromMe = _call(
          status: CallStatusConstants.initiated,
          initiator: 'me',
          receiverType: ReceiverTypeConstants.group,
          sender: _me,
        );

        expect(
          CallUtils.getLastMessageForGroupCall(fromThem, c, _me),
          'User them ${t.initiatedGroupCall}',
        );
        expect(
          CallUtils.getLastMessageForGroupCall(fromMe, c, _me),
          t.youInitiatedGroupCall,
        );
      });
    });

    testWidgets('a 1:1 message produces nothing', (tester) async {
      await _withContext(tester, (c) {
        expect(
          CallUtils.getLastMessageForGroupCall(
            _call(status: CallStatusConstants.initiated, initiator: 'them'),
            c,
            _me,
          ),
          '',
        );
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // isMissedCall (P5-C10, owner's P5-D09 B)
  // ═══════════════════════════════════════════════════════════════════════════

  group('isMissedCall', () {
    test('P5-C10: unanswered and cancelled are missed for whoever did not '
        'start the call; nothing else is', () {
      for (final by in _By.values) {
        for (final status in _allStatuses) {
          final missed =
              by != _By.me &&
              (status == CallStatusConstants.unanswered ||
                  status == CallStatusConstants.cancelled);
          expect(
            CallUtils.isMissedCall(_callBy(by, status), _me),
            missed,
            reason: '$status, started by ${by.name}',
          );
        }
      }
    });

    test('P5-E24: busy and rejected are not missed for the callee', () {
      for (final status in [
        CallStatusConstants.busy,
        CallStatusConstants.rejected,
      ]) {
        expect(
          CallUtils.isMissedCall(_callBy(_By.other, status), _me),
          isFalse,
          reason: status,
        );
      }
    });

    test('a group call is never a missed call', () {
      expect(
        CallUtils.isMissedCall(
          _call(
            status: CallStatusConstants.unanswered,
            initiator: 'them',
            receiverType: ReceiverTypeConstants.group,
          ),
          _me,
        ),
        isFalse,
      );
    });
  });
  // ═══════════════════════════════════════════════════════════════════════════
  // callLogLoggedInUser
  // ═══════════════════════════════════════════════════════════════════════════

  group('callLogLoggedInUser', () {
    test('true when the logged-in user initiated the logged call', () {
      expect(CallUtils.callLogLoggedInUser(_log(status: 'ended'), _me), isTrue);
    });

    test('false when someone else initiated it', () {
      expect(
        CallUtils.callLogLoggedInUser(
          _log(status: 'ended', initiatorUid: 'them', receiverUid: 'me'),
          _me,
        ),
        isFalse,
      );
    });

    test('a null log or a null user is false', () {
      expect(CallUtils.callLogLoggedInUser(null, _me), isFalse);
      expect(
        CallUtils.callLogLoggedInUser(_log(status: 'ended'), null),
        isFalse,
      );
    });

    test('a log with neither participant set is false', () {
      expect(
        CallUtils.callLogLoggedInUser(CallLog(status: 'ended'), _me),
        isFalse,
      );
    });

    test('a group initiator falls back to the receiver', () {
      // A group call log carries a CallGroup as initiator, so the answer has
      // to come off the receiver instead.
      CallLog log(String receiverUid) => CallLog(
        status: 'ended',
        initiator: CallGroup(guid: 'g1', name: 'Group'),
        receiver: CallUser(uid: receiverUid, name: 'Receiver'),
      );
      expect(CallUtils.callLogLoggedInUser(log('me'), _me), isTrue);
      expect(CallUtils.callLogLoggedInUser(log('them'), _me), isFalse);
    });

    test('a missing initiator falls back to the receiver', () {
      final log = CallLog(
        status: 'ended',
        receiver: CallUser(uid: 'me', name: 'Receiver'),
      );
      expect(CallUtils.callLogLoggedInUser(log, _me), isTrue);
    });

    test('a group receiver falls back to the initiator', () {
      final log = CallLog(
        status: 'ended',
        initiator: CallUser(uid: 'me', name: 'Me'),
        receiver: CallGroup(guid: 'g1', name: 'Group'),
      );
      expect(CallUtils.callLogLoggedInUser(log, _me), isTrue);
    });

    // FINDING: the last two arms of callLogLoggedInUser cannot be reached
    // without crashing. Whenever `initiator is CallGroup` is evaluated, the
    // earlier `receiver is CallUser` arm has already returned, so the
    // `callLog.receiver as CallUser` inside it can only ever run against a
    // non-CallUser and throws. The symmetric arm below it has the same shape.
    // A group-initiated log with a group receiver therefore takes down the
    // call-logs list rather than returning false. Pinned, not fixed.
    test('FINDING: a group-to-group log throws instead of returning false', () {
      final log = CallLog(
        status: 'ended',
        initiator: CallGroup(guid: 'g1', name: 'Group'),
        receiver: CallGroup(guid: 'g2', name: 'Other'),
      );
      expect(
        () => CallUtils.callLogLoggedInUser(log, _me),
        throwsA(isA<TypeError>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // isMissedCallLog — the one missed rule for a call log (P5-C11)
  // ═══════════════════════════════════════════════════════════════════════════

  group('isMissedCallLog', () {
    test('P5-C11: unanswered and cancelled are missed for whoever did not '
        'start the call; nothing else is', () {
      for (final mine in [true, false]) {
        for (final status in _allStatuses) {
          expect(
            CallUtils.isMissedCallLog(
              mine ? _log(status: status) : _incomingLog(status),
              _me,
            ),
            !mine &&
                (status == CallStatusConstants.unanswered ||
                    status == CallStatusConstants.cancelled),
            reason: '$status, ${mine ? 'mine' : 'theirs'}',
          );
        }
      }
    });

    test('a missing log is not missed; a missing user reads as the callee', () {
      expect(CallUtils.isMissedCallLog(null, _me), isFalse);
      expect(
        CallUtils.isMissedCallLog(
          _log(status: CallStatusConstants.unanswered),
          null,
        ),
        isTrue,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // getStatus — the label for a CallLog row (P5-C11)
  // ═══════════════════════════════════════════════════════════════════════════

  group('getStatus', () {
    testWidgets('P5-C11: every status, from both sides', (tester) async {
      await _withContext(tester, (c) {
        final t = Translations.of(c);
        final mine = <String, String>{
          CallStatusConstants.initiated: t.outgoingCall,
          CallStatusConstants.ongoing: t.ongoingCall,
          CallStatusConstants.ended: t.outgoingCall,
          CallStatusConstants.unanswered: t.unansweredCall,
          CallStatusConstants.cancelled: t.cancelledCall,
          // It read lowercase "rejected call", and busy "Unanswered Call".
          CallStatusConstants.rejected: t.callRejected,
          CallStatusConstants.busy: t.callBusy,
          _unknownStatus: '',
        };
        final theirs = <String, String>{
          CallStatusConstants.initiated: t.incomingCall,
          CallStatusConstants.ongoing: t.ongoingCall,
          CallStatusConstants.ended: t.incomingCall,
          CallStatusConstants.unanswered: t.missedCall,
          CallStatusConstants.cancelled: t.missedCall,
          // Declined or busy is not missed (P5-D09 B).
          CallStatusConstants.rejected: t.callRejected,
          CallStatusConstants.busy: t.callBusy,
          _unknownStatus: '',
        };
        for (final entry in mine.entries) {
          expect(
            CallUtils.getStatus(c, _log(status: entry.key), _me),
            ' ${entry.value}',
            reason: '${entry.key}, mine',
          );
        }
        for (final entry in theirs.entries) {
          expect(
            CallUtils.getStatus(c, _incomingLog(entry.key), _me),
            ' ${entry.value}',
            reason: '${entry.key}, theirs',
          );
        }
      });
    });

    testWidgets('a missing log, user or context yields the empty string', (
      tester,
    ) async {
      await _withContext(tester, (c) {
        // Note: empty, not the " " every other path returns — call sites that
        // trim will not notice, but one that measures will.
        expect(CallUtils.getStatus(c, null, _me), '');
        expect(CallUtils.getStatus(c, _log(status: 'ended'), null), '');
        expect(CallUtils.getStatus(null, _log(status: 'ended'), _me), '');
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // getCallIcon (P5-C11)
  // ═══════════════════════════════════════════════════════════════════════════

  group('getCallIcon', () {
    final colors = CometChatColorPalette(
      success: const Color(0xFF00FF01),
      error: const Color(0xFFFF0002),
    );
    const typography = CometChatTypography();
    final spacing = CometChatSpacing();

    Widget icon(
      BuildContext c,
      CallLog log, {
      CometChatCallLogsStyle style = const CometChatCallLogsStyle(),
      Widget? incoming,
      Widget? outgoing,
      Widget? missed,
    }) => CallUtils.getCallIcon(
      c,
      log,
      _me,
      colors,
      typography,
      spacing,
      style,
      incomingCallIcon: incoming,
      outgoingCallIcon: outgoing,
      missedCallIcon: missed,
    );

    testWidgets('P5-C11 / P5-N14: missed only for a missed call, otherwise '
        'the direction, for every status', (tester) async {
      await _withContext(tester, (c) {
        for (final status in _allStatuses) {
          expect(
            (icon(c, _log(status: status)) as Icon).icon,
            Icons.call_made_outlined,
            reason: '$status, mine',
          );
          final missed =
              status == CallStatusConstants.unanswered ||
              status == CallStatusConstants.cancelled;
          expect(
            (icon(c, _incomingLog(status)) as Icon).icon,
            missed
                ? Icons.call_missed_outgoing_rounded
                : Icons.call_received_outlined,
            reason: '$status, theirs',
          );
        }
      });
    });

    testWidgets('P5-E24: an incoming busy or rejected call is incoming, not '
        'missed', (tester) async {
      await _withContext(tester, (c) {
        for (final status in [
          CallStatusConstants.busy,
          CallStatusConstants.rejected,
        ]) {
          expect(
            (icon(c, _incomingLog(status)) as Icon).icon,
            Icons.call_received_outlined,
            reason: status,
          );
        }
      });
    });

    testWidgets('an unknown status shows the direction, not an empty box', (
      tester,
    ) async {
      await _withContext(tester, (c) {
        expect(
          (icon(c, _log(status: _unknownStatus)) as Icon).icon,
          Icons.call_made_outlined,
        );
        expect(
          (icon(c, _incomingLog(_unknownStatus)) as Icon).icon,
          Icons.call_received_outlined,
        );
      });
    });

    testWidgets('the palette supplies the default colours', (tester) async {
      await _withContext(tester, (c) {
        expect(
          (icon(c, _log(status: CallStatusConstants.ended)) as Icon).color,
          const Color(0xFF00FF01),
        );
        expect(
          (icon(c, _incomingLog(CallStatusConstants.cancelled)) as Icon).color,
          const Color(0xFFFF0002),
        );
      });
    });

    testWidgets('the style wins over the palette', (tester) async {
      await _withContext(tester, (c) {
        const style = CometChatCallLogsStyle(
          incomingCallIconColor: Color(0xFF111111),
          outgoingCallIconColor: Color(0xFF222222),
          missedCallIconColor: Color(0xFF333333),
        );
        expect(
          (icon(c, _log(status: CallStatusConstants.ended), style: style)
                  as Icon)
              .color,
          const Color(0xFF222222),
        );
        expect(
          (icon(c, _incomingLog(CallStatusConstants.ended), style: style)
                  as Icon)
              .color,
          const Color(0xFF111111),
        );
        expect(
          (icon(c, _incomingLog(CallStatusConstants.unanswered), style: style)
                  as Icon)
              .color,
          const Color(0xFF333333),
        );
      });
    });

    testWidgets('a supplied widget replaces the default icon entirely', (
      tester,
    ) async {
      await _withContext(tester, (c) {
        const incoming = Text('in');
        const outgoing = Text('out');
        const missed = Text('missed');

        expect(
          icon(
            c,
            _log(status: CallStatusConstants.ended),
            incoming: incoming,
            outgoing: outgoing,
            missed: missed,
          ),
          same(outgoing),
        );
        expect(
          icon(
            c,
            _incomingLog(CallStatusConstants.ended),
            incoming: incoming,
            outgoing: outgoing,
            missed: missed,
          ),
          same(incoming),
        );
        expect(
          icon(
            c,
            _incomingLog(CallStatusConstants.unanswered),
            incoming: incoming,
            outgoing: outgoing,
            missed: missed,
          ),
          same(missed),
        );
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // getCallStatusColor (P5-C11)
  // ═══════════════════════════════════════════════════════════════════════════

  group('getCallStatusColor', () {
    final colors = CometChatColorPalette(
      textPrimary: const Color(0xFF0A0A0A),
      error: const Color(0xFFB00020),
    );

    test('P5-C11: red exactly for a missed call, from both sides and for '
        'every status', () {
      for (final status in _allStatuses) {
        expect(
          CallUtils.getCallStatusColor(_log(status: status), _me, colors),
          const Color(0xFF0A0A0A),
          reason: '$status, mine',
        );
        final missed =
            status == CallStatusConstants.unanswered ||
            status == CallStatusConstants.cancelled;
        expect(
          CallUtils.getCallStatusColor(_incomingLog(status), _me, colors),
          missed ? const Color(0xFFB00020) : const Color(0xFF0A0A0A),
          reason: '$status, theirs',
        );
      }
    });

    test('P5-E24: an incoming busy or rejected call is not red', () {
      // Busy stayed the primary colour while its icon went missed, and a
      // rejected one went red; both now read as plain incoming calls.
      for (final status in [
        CallStatusConstants.busy,
        CallStatusConstants.rejected,
      ]) {
        expect(
          CallUtils.getCallStatusColor(_incomingLog(status), _me, colors),
          const Color(0xFF0A0A0A),
          reason: status,
        );
      }
    });

    test('an unknown status is the primary colour, not the error one', () {
      expect(
        CallUtils.getCallStatusColor(_incomingLog(_unknownStatus), _me, colors),
        const Color(0xFF0A0A0A),
      );
    });

    test('an empty palette degrades to transparent rather than throwing', () {
      final empty = CometChatColorPalette();
      expect(
        CallUtils.getCallStatusColor(
          _log(status: CallStatusConstants.ended),
          _me,
          empty,
        ),
        Colors.transparent,
      );
      expect(
        CallUtils.getCallStatusColor(
          _incomingLog(CallStatusConstants.cancelled),
          _me,
          empty,
        ),
        Colors.transparent,
      );
    });
  });
  // ═══════════════════════════════════════════════════════════════════════════
  // isCallInitiatedByMe
  // ═══════════════════════════════════════════════════════════════════════════

  group('isCallInitiatedByMe', () {
    tearDown(() => CometChatUIKit.loggedInUser = null);

    test('compares the initiator against the UI Kit\'s logged-in user', () {
      CometChatUIKit.loggedInUser = _me;
      expect(
        CallUtils.isCallInitiatedByMe(
          _call(status: CallStatusConstants.initiated, initiator: 'me'),
        ),
        isTrue,
      );
      expect(
        CallUtils.isCallInitiatedByMe(
          _call(status: CallStatusConstants.initiated, initiator: 'them'),
        ),
        isFalse,
      );
    });

    test('false when nobody is signed in', () {
      CometChatUIKit.loggedInUser = null;
      expect(
        CallUtils.isCallInitiatedByMe(
          _call(status: CallStatusConstants.initiated, initiator: 'me'),
        ),
        isFalse,
      );
    });

    test('false when the initiator is a group rather than a user', () {
      CometChatUIKit.loggedInUser = _me;
      final call = Call(
        callStatus: CallStatusConstants.initiated,
        callInitiator: Group(guid: 'g1', name: 'Group', type: 'public'),
        receiverUid: 'g1',
        type: CallTypeConstants.audioCall,
        receiverType: ReceiverTypeConstants.group,
      );
      expect(CallUtils.isCallInitiatedByMe(call), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // getCallIconByStatus (P5-C10)
  // ═══════════════════════════════════════════════════════════════════════════

  group('getCallIconByStatus', () {
    testWidgets('P5-C10: missed glyph for a missed call, a direction while '
        'initiated, the plain glyph for everything else', (tester) async {
      await _withContext(tester, (c) {
        for (final audio in [true, false]) {
          for (final by in _By.values) {
            for (final status in _allStatuses) {
              final missed =
                  by != _By.me &&
                  (status == CallStatusConstants.unanswered ||
                      status == CallStatusConstants.cancelled);
              final String expected;
              if (missed) {
                expected = audio
                    ? AssetConstants.audioMissed
                    : AssetConstants.videoMissed;
              } else if (status == CallStatusConstants.initiated) {
                expected = by == _By.me
                    ? (audio
                          ? AssetConstants.outgoingAudioCallNoFill
                          : AssetConstants.outgoingVideoCallNoFill)
                    : (audio
                          ? AssetConstants.incomingAudioCallNoFill
                          : AssetConstants.incomingVideoCallNoFill);
              } else {
                expected = audio
                    ? AssetConstants.callNoFill
                    : AssetConstants.videocamNoFill;
              }
              expect(
                CallUtils.getCallIconByStatus(
                  c,
                  _callBy(by, status),
                  _me,
                  audio,
                ),
                expected,
                reason:
                    '$status, started by ${by.name}, '
                    '${audio ? 'audio' : 'video'}',
              );
            }
          }
        }
      });
    });

    testWidgets('P5-E24: busy is the plain glyph for the callee too', (
      tester,
    ) async {
      await _withContext(tester, (c) {
        expect(
          CallUtils.getCallIconByStatus(
            c,
            _callBy(_By.other, CallStatusConstants.busy),
            _me,
            true,
          ),
          AssetConstants.callNoFill,
        );
      });
    });

    testWidgets('a non-call message yields no icon', (tester) async {
      await _withContext(tester, (c) {
        expect(
          CallUtils.getCallIconByStatus(
            c,
            TextMessage(
              text: 'hi',
              receiverUid: 'them',
              receiverType: ReceiverTypeConstants.user,
              type: MessageTypeConstants.text,
            ),
            _me,
            true,
          ),
          '',
        );
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // getCallTextColor / getCallIconColor (P5-C10)
  // ═══════════════════════════════════════════════════════════════════════════

  group('getCallTextColor', () {
    final colors = CometChatColorPalette(
      textSecondary: const Color(0xFF0B0B0B),
      error: const Color(0xFFB00021),
    );

    testWidgets('P5-C10: red exactly when the call is missed', (tester) async {
      await _withContext(tester, (c) {
        for (final by in _By.values) {
          for (final status in _allStatuses) {
            final call = _callBy(by, status);
            expect(
              CallUtils.getCallTextColor(c, call, _me, colors),
              CallUtils.isMissedCall(call, _me)
                  ? const Color(0xFFB00021)
                  : const Color(0xFF0B0B0B),
              reason: '$status, started by ${by.name}',
            );
          }
        }
        // The rule is not vacuous: one missed and one plain call.
        expect(
          CallUtils.getCallTextColor(
            c,
            _callBy(_By.other, CallStatusConstants.cancelled),
            _me,
            colors,
          ),
          const Color(0xFFB00021),
        );
        expect(
          CallUtils.getCallTextColor(
            c,
            _callBy(_By.other, CallStatusConstants.busy),
            _me,
            colors,
          ),
          const Color(0xFF0B0B0B),
        );
      });
    });

    testWidgets('a group call and a non-call message stay secondary', (
      tester,
    ) async {
      await _withContext(tester, (c) {
        expect(
          CallUtils.getCallTextColor(
            c,
            _call(
              status: CallStatusConstants.unanswered,
              initiator: 'them',
              receiverType: ReceiverTypeConstants.group,
            ),
            _me,
            colors,
          ),
          const Color(0xFF0B0B0B),
        );
        expect(
          CallUtils.getCallTextColor(
            c,
            TextMessage(
              text: 'hi',
              receiverUid: 'them',
              receiverType: ReceiverTypeConstants.user,
              type: MessageTypeConstants.text,
            ),
            _me,
            colors,
          ),
          const Color(0xFF0B0B0B),
        );
      });
    });

    testWidgets('an empty palette degrades to transparent', (tester) async {
      await _withContext(tester, (c) {
        final empty = CometChatColorPalette();
        expect(
          CallUtils.getCallTextColor(
            c,
            _call(status: CallStatusConstants.ended, initiator: 'me'),
            _me,
            empty,
          ),
          Colors.transparent,
        );
        expect(
          CallUtils.getCallTextColor(
            c,
            _call(status: CallStatusConstants.cancelled, initiator: 'them'),
            _me,
            empty,
          ),
          Colors.transparent,
        );
      });
    });
  });

  group('getCallIconColor', () {
    final colors = CometChatColorPalette(
      iconSecondary: const Color(0xFF0C0C0C),
      error: const Color(0xFFB00022),
    );

    testWidgets('P5-C10: red exactly when the call is missed', (tester) async {
      await _withContext(tester, (c) {
        for (final by in _By.values) {
          for (final status in _allStatuses) {
            final call = _callBy(by, status);
            expect(
              CallUtils.getCallIconColor(c, call, _me, colors),
              CallUtils.isMissedCall(call, _me)
                  ? const Color(0xFFB00022)
                  : const Color(0xFF0C0C0C),
              reason: '$status, started by ${by.name}',
            );
          }
        }
      });
    });

    testWidgets('P5-N11: an ended call is never red, from either side', (
      tester,
    ) async {
      // The video bubble painted its icon with this helper, which used to
      // turn a normally ended call red for the callee.
      await _withContext(tester, (c) {
        for (final by in _By.values) {
          expect(
            CallUtils.getCallIconColor(
              c,
              _callBy(by, CallStatusConstants.ended),
              _me,
              colors,
            ),
            const Color(0xFF0C0C0C),
            reason: by.name,
          );
        }
        expect(
          CallUtils.getCallIconColor(
            c,
            _callBy(_By.other, CallStatusConstants.unanswered),
            _me,
            colors,
          ),
          const Color(0xFFB00022),
        );
      });
    });

    testWidgets('an empty palette degrades to transparent', (tester) async {
      await _withContext(tester, (c) {
        final empty = CometChatColorPalette();
        expect(
          CallUtils.getCallIconColor(
            c,
            _call(status: CallStatusConstants.initiated, initiator: 'me'),
            _me,
            empty,
          ),
          Colors.transparent,
        );
        expect(
          CallUtils.getCallIconColor(
            c,
            _call(status: CallStatusConstants.unanswered, initiator: 'them'),
            _me,
            empty,
          ),
          Colors.transparent,
        );
      });
    });
  });
}
