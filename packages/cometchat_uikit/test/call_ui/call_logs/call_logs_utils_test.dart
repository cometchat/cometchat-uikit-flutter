/// Behaviour tests for [CallLogsUtils] — the pure helpers behind every row of
/// `CometChatCallLogs`.
///
/// Everything here is a static function over a `CallLog`, so there is no SDK
/// in the way. What is worth pinning is the perspective logic: a call log is
/// symmetric on the wire, and these helpers decide which side of it the
/// logged-in user should be shown. Get the initiator/receiver test the wrong
/// way round and the list shows every caller their own name, which no golden
/// would catch.
///
/// Also pinned: the three-way shape test (user↔user, user↔group, anything
/// else), the duration formatter's carry arithmetic, and the date-bucket key
/// that groups rows into day sections.
///
/// Round 5 (P5-C13) added getDisplayName, getAvatarUrl and
/// getOtherParticipantId, which show the group for every group call; the
/// receiverName / receiverAvatar / returnReceiverId they replace are
/// deprecated and still pinned below as they were.
///
///   flutter test test/call_ui/call_logs/call_logs_utils_test.dart
// The deprecated helpers keep their tests until 7.0.0 removes them.
// ignore_for_file: deprecated_member_use_from_same_package
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart'
    show CallLogsUtils, CometChatCallLogsStyle;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _me = User(uid: 'me', name: 'Me');
final _them = User(uid: 'them', name: 'Them');

CallUser _callUser(String uid) =>
    CallUser(uid: uid, name: uid.toUpperCase(), avatar: 'https://x/$uid.png');

CallGroup _callGroup(String guid) => CallGroup(
  guid: guid,
  name: guid.toUpperCase(),
  icon: 'https://x/$guid.png',
);

CallLog _log({CallEntity? initiator, CallEntity? receiver, int? initiatedAt}) =>
    CallLog(
      sessionId: 's1',
      initiator: initiator,
      receiver: receiver,
      initiatedAt: initiatedAt,
    );

/// A one-to-one log I placed.
CallLog _outgoing() =>
    _log(initiator: _callUser('me'), receiver: _callUser('them'));

/// A one-to-one log placed to me.
CallLog _incoming() =>
    _log(initiator: _callUser('them'), receiver: _callUser('me'));

/// A group call I started.
CallLog _outgoingGroup() =>
    _log(initiator: _callUser('me'), receiver: _callGroup('team'));

/// A group call somebody else started.
CallLog _incomingGroup() =>
    _log(initiator: _callUser('them'), receiver: _callGroup('team'));

void main() {
  // ===========================================================================
  // P5-C13: the group shows on every group row; a missing user never throws.
  group('getDisplayName / getAvatarUrl / getOtherParticipantId', () {
    test('P5-C13: a group call somebody else started shows the group', () {
      // receiverName and friends named the initiator here.
      expect(CallLogsUtils.getDisplayName(_me, _incomingGroup()), 'TEAM');
      expect(
        CallLogsUtils.getAvatarUrl(_me, _incomingGroup()),
        'https://x/team.png',
      );
      expect(
        CallLogsUtils.getOtherParticipantId(_me, _incomingGroup()),
        'team',
      );
    });

    test('a group call I started shows the group too', () {
      expect(CallLogsUtils.getDisplayName(_me, _outgoingGroup()), 'TEAM');
      expect(
        CallLogsUtils.getAvatarUrl(_me, _outgoingGroup()),
        'https://x/team.png',
      );
      expect(
        CallLogsUtils.getOtherParticipantId(_me, _outgoingGroup()),
        'team',
      );
    });

    test('a 1:1 call shows the other participant, whoever called', () {
      for (final log in [_outgoing(), _incoming()]) {
        expect(CallLogsUtils.getDisplayName(_me, log), 'THEM');
        expect(CallLogsUtils.getAvatarUrl(_me, log), 'https://x/them.png');
        expect(CallLogsUtils.getOtherParticipantId(_me, log), 'them');
      }
      // Seen from the other side.
      expect(CallLogsUtils.getDisplayName(_them, _outgoing()), 'ME');
      expect(CallLogsUtils.getOtherParticipantId(_them, _incoming()), 'me');
    });

    test('P5-C13: with no logged-in user a 1:1 row is empty, a group row '
        'still shows the group', () {
      expect(CallLogsUtils.getDisplayName(null, _outgoing()), '');
      expect(CallLogsUtils.getAvatarUrl(null, _outgoing()), '');
      expect(CallLogsUtils.getOtherParticipantId(null, _outgoing()), '');
      expect(CallLogsUtils.getDisplayName(null, _incomingGroup()), 'TEAM');
      expect(
        CallLogsUtils.getOtherParticipantId(null, _incomingGroup()),
        'team',
      );
    });

    test('a user who took no part sees nobody, not one of the two', () {
      final stranger = User(uid: 'stranger', name: 'Stranger');
      expect(CallLogsUtils.getDisplayName(stranger, _outgoing()), '');
      expect(CallLogsUtils.getOtherParticipantId(stranger, _incoming()), '');
    });

    test('missing fields, a missing log and odd shapes give empty strings', () {
      expect(
        CallLogsUtils.getDisplayName(
          _me,
          _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallUser(uid: 'x'),
          ),
        ),
        '',
      );
      expect(
        CallLogsUtils.getAvatarUrl(
          _me,
          _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallGroup(guid: 'g'),
          ),
        ),
        '',
      );
      expect(
        CallLogsUtils.getOtherParticipantId(
          _me,
          _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallGroup(),
          ),
        ),
        '',
      );
      expect(CallLogsUtils.getDisplayName(_me, null), '');
      expect(CallLogsUtils.getDisplayName(_me, _log()), '');
      expect(
        CallLogsUtils.getDisplayName(
          _me,
          _log(initiator: _callGroup('team'), receiver: _callUser('me')),
        ),
        '',
      );
    });
  });

  // ===========================================================================
  group('receiverName', () {
    test('an outgoing 1:1 call names the other side', () {
      expect(CallLogsUtils.receiverName(_me, _outgoing()), 'THEM');
    });

    test('an incoming 1:1 call also names the other side', () {
      expect(CallLogsUtils.receiverName(_me, _incoming()), 'THEM');
    });

    test('a group call I started names the group', () {
      expect(CallLogsUtils.receiverName(_me, _outgoingGroup()), 'TEAM');
    });

    test('a group call I did not start names the initiator, not the group', () {
      // Asymmetric on purpose: the row for a call somebody else placed into a
      // group shows who placed it.
      expect(CallLogsUtils.receiverName(_me, _incomingGroup()), 'THEM');
    });

    test('a missing name degrades to an empty string, never null', () {
      final log = _log(
        initiator: CallUser(uid: 'me'),
        receiver: CallUser(uid: 'them'),
      );
      expect(CallLogsUtils.receiverName(_me, log), '');
    });

    test('a null logged-in user or null log yields an empty string', () {
      expect(CallLogsUtils.receiverName(null, _outgoing()), '');
      expect(CallLogsUtils.receiverName(_me, null), '');
      expect(CallLogsUtils.receiverName(null, null), '');
    });

    test('a group-initiated log falls through to an empty string', () {
      final log = _log(
        initiator: _callGroup('team'),
        receiver: _callUser('me'),
      );
      expect(CallLogsUtils.receiverName(_me, log), '');
    });

    test('a log with no entities at all yields an empty string', () {
      expect(CallLogsUtils.receiverName(_me, _log()), '');
    });

    test('a third party viewing a 1:1 log sees the initiator', () {
      // Neither side is the viewer, so the `else` arm runs.
      expect(CallLogsUtils.receiverName(_them, _outgoing()), 'ME');
    });
  });

  // ===========================================================================
  group('receiverAvatar', () {
    test('an outgoing 1:1 call shows the other side avatar', () {
      expect(
        CallLogsUtils.receiverAvatar(_me, _outgoing()),
        'https://x/them.png',
      );
    });

    test('an incoming 1:1 call shows the caller avatar', () {
      expect(
        CallLogsUtils.receiverAvatar(_me, _incoming()),
        'https://x/them.png',
      );
    });

    test('a group call I started shows the group icon', () {
      expect(
        CallLogsUtils.receiverAvatar(_me, _outgoingGroup()),
        'https://x/team.png',
      );
    });

    test('a group call I did not start shows the initiator avatar', () {
      expect(
        CallLogsUtils.receiverAvatar(_me, _incomingGroup()),
        'https://x/them.png',
      );
    });

    test('a missing avatar or icon becomes an empty string', () {
      expect(
        CallLogsUtils.receiverAvatar(
          _me,
          _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallUser(uid: 'them'),
          ),
        ),
        '',
      );
      expect(
        CallLogsUtils.receiverAvatar(
          _me,
          _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallGroup(guid: 'g'),
          ),
        ),
        '',
      );
    });

    test('null inputs and unsupported shapes give an empty string', () {
      expect(CallLogsUtils.receiverAvatar(null, _outgoing()), '');
      expect(CallLogsUtils.receiverAvatar(_me, null), '');
      expect(CallLogsUtils.receiverAvatar(_me, _log()), '');
    });
  });

  // ===========================================================================
  group('returnReceiverId', () {
    test('an outgoing 1:1 call resolves to the other uid', () {
      expect(CallLogsUtils.returnReceiverId(_me, _outgoing()), 'them');
    });

    test('an incoming 1:1 call also resolves to the other uid', () {
      expect(CallLogsUtils.returnReceiverId(_me, _incoming()), 'them');
    });

    test('a group call I started resolves to the guid', () {
      expect(CallLogsUtils.returnReceiverId(_me, _outgoingGroup()), 'team');
    });

    test('a group call I did not start resolves to the initiator uid', () {
      // This is what the row taps through to, so it opens a 1:1 chat rather
      // than the group.
      expect(CallLogsUtils.returnReceiverId(_me, _incomingGroup()), 'them');
    });

    test('missing ids become an empty string', () {
      expect(
        CallLogsUtils.returnReceiverId(
          _me,
          _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallUser(),
          ),
        ),
        '',
      );
      expect(
        CallLogsUtils.returnReceiverId(
          _me,
          _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallGroup(),
          ),
        ),
        '',
      );
    });

    test('null inputs and unsupported shapes give an empty string', () {
      expect(CallLogsUtils.returnReceiverId(null, _outgoing()), '');
      expect(CallLogsUtils.returnReceiverId(_me, null), '');
      expect(CallLogsUtils.returnReceiverId(_me, _log()), '');
    });
  });

  // ===========================================================================
  group('isUser', () {
    test('true only when both ends are users', () {
      expect(CallLogsUtils.isUser(_outgoing()), isTrue);
      expect(CallLogsUtils.isUser(_incoming()), isTrue);
    });

    test('false for a group on either end', () {
      expect(CallLogsUtils.isUser(_outgoingGroup()), isFalse);
      expect(
        CallLogsUtils.isUser(
          _log(initiator: _callGroup('team'), receiver: _callUser('me')),
        ),
        isFalse,
      );
    });

    test('false for a null log or a log missing its entities', () {
      expect(CallLogsUtils.isUser(null), isFalse);
      expect(CallLogsUtils.isUser(_log()), isFalse);
      expect(CallLogsUtils.isUser(_log(initiator: _callUser('me'))), isFalse);
    });
  });

  // ===========================================================================
  group('formatMinutesAndSeconds', () {
    test('under an hour the hours part is omitted', () {
      expect(CallLogsUtils.formatMinutesAndSeconds(0), '0m 00s');
      expect(CallLogsUtils.formatMinutesAndSeconds(5), '5m 00s');
      expect(CallLogsUtils.formatMinutesAndSeconds(59), '59m 00s');
    });

    test('an hour or more prefixes the hours', () {
      expect(CallLogsUtils.formatMinutesAndSeconds(60), '1h 0m 00s');
      expect(CallLogsUtils.formatMinutesAndSeconds(125), '2h 5m 00s');
    });

    test('the fractional part becomes seconds, zero-padded', () {
      expect(CallLogsUtils.formatMinutesAndSeconds(1.5), '1m 30s');
      expect(CallLogsUtils.formatMinutesAndSeconds(2.1), '2m 06s');
    });

    test('a fraction that rounds to 60 seconds carries into the minutes', () {
      // 0.999 * 60 rounds to 60 — without the carry this would read '0m 60s'.
      expect(CallLogsUtils.formatMinutesAndSeconds(0.999), '1m 00s');
    });

    test('a second carry that fills the hour carries again', () {
      // 59.999 min → 59m + 60s → 60m → 1h 0m 00s. Both carries in one call.
      expect(CallLogsUtils.formatMinutesAndSeconds(59.999), '1h 0m 00s');
    });

    test('the seconds field is always two digits', () {
      for (final m in [0.05, 0.1, 0.15]) {
        final parts = CallLogsUtils.formatMinutesAndSeconds(m).split(' ');
        expect(parts.last.length, 3, reason: 'for $m');
      }
    });
  });

  // ===========================================================================
  group('storeValueInMapTime', () {
    test('an epoch second becomes the dd MMM yyyy bucket key', () {
      // Timezone-independent by construction: the epoch is derived from a
      // LOCAL DateTime and the helper reads it back with
      // `DateTime.fromMillisecondsSinceEpoch`, which is also local. Both ends
      // use the same zone, so the round trip lands on the same calendar day
      // whatever TZ the runner has. Never compare a hardcoded epoch against a
      // hardcoded label here — that is the shape that passes in IST and fails
      // on a UTC runner.
      final epoch = DateTime(2024, 3, 5, 12).millisecondsSinceEpoch ~/ 1000;
      expect(CallLogsUtils.storeValueInMapTime(epoch), '05 Mar 2024');
    });

    test('two timestamps on the same day share one key', () {
      final morning = DateTime(2024, 3, 5, 1).millisecondsSinceEpoch ~/ 1000;
      final evening = DateTime(2024, 3, 5, 23).millisecondsSinceEpoch ~/ 1000;
      expect(
        CallLogsUtils.storeValueInMapTime(morning),
        CallLogsUtils.storeValueInMapTime(evening),
      );
    });

    test('adjacent days do not share a key', () {
      final a = DateTime(2024, 3, 5, 23).millisecondsSinceEpoch ~/ 1000;
      final b = DateTime(2024, 3, 6, 1).millisecondsSinceEpoch ~/ 1000;
      expect(
        CallLogsUtils.storeValueInMapTime(a),
        isNot(CallLogsUtils.storeValueInMapTime(b)),
      );
    });

    test('a null timestamp buckets under the empty key', () {
      expect(CallLogsUtils.storeValueInMapTime(null), '');
    });

    test('the key round-trips through the parser getDateTimeTitle uses', () {
      final epoch = DateTime(2024, 3, 5, 12).millisecondsSinceEpoch ~/ 1000;
      final key = CallLogsUtils.storeValueInMapTime(epoch);
      // getDateTimeTitle parses with the same "dd MMM yyyy" format; if the two
      // ever drift, every day separator silently disappears.
      expect(() => DateFormat('dd MMM yyyy').parse(key), returnsNormally);
    });
  });

  // ===========================================================================
  group('returnCallLogList', () {
    test('reads the bucket at the given index, in insertion order', () {
      final grouped = <String, List<CallLog>>{
        '05 Mar 2024': [_outgoing()],
        '06 Mar 2024': [_incoming(), _outgoing()],
      };

      expect(CallLogsUtils.returnCallLogList(grouped, 0), hasLength(1));
      expect(CallLogsUtils.returnCallLogList(grouped, 1), hasLength(2));
    });

    test('an empty bucket reads back as an empty list', () {
      final grouped = <String, List<CallLog>>{'05 Mar 2024': []};
      expect(CallLogsUtils.returnCallLogList(grouped, 0), isEmpty);
    });

    test('an out-of-range index throws rather than answering empty', () {
      expect(
        () => CallLogsUtils.returnCallLogList(<String, List<CallLog>>{}, 0),
        throwsRangeError,
      );
    });
  });

  // ===========================================================================
  group('getDateTimeTitle', () {
    Future<Widget> render(
      WidgetTester tester,
      Map<String, List<CallLog>> grouped,
      int index, {
      String? pattern,
      TextStyle? style,
    }) async {
      late Widget built;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              built = CallLogsUtils.getDateTimeTitle(
                grouped,
                index,
                pattern,
                style,
                context,
              );
              return built;
            },
          ),
        ),
      );
      return built;
    }

    testWidgets('a valid bucket key becomes a dated separator', (tester) async {
      final built = await render(tester, {
        '05 Mar 2024': [_outgoing()],
      }, 0);

      expect(built, isA<CometChatDate>());
      final date = built as CometChatDate;
      expect(date.date, DateTime(2024, 3, 5));
      expect(date.pattern, DateTimePattern.dayDateFormat);
      expect(date.customDateString, isNull);
    });

    testWidgets('a supplied separator pattern overrides the date entirely', (
      tester,
    ) async {
      final built = await render(
        tester,
        {
          '05 Mar 2024': [_outgoing()],
        },
        0,
        pattern: 'EEEE',
      );

      expect((built as CometChatDate).customDateString, 'EEEE');
    });

    testWidgets('the caller text style is carried onto the separator', (
      tester,
    ) async {
      const style = TextStyle(fontSize: 21, color: Color(0xFF00FF00));
      final built = await render(
        tester,
        {
          '05 Mar 2024': [_outgoing()],
        },
        0,
        style: style,
      );

      expect((built as CometChatDate).style.textStyle, style);
    });

    testWidgets('with no style the separator falls back to a bare TextStyle', (
      tester,
    ) async {
      final built = await render(tester, {
        '05 Mar 2024': [_outgoing()],
      }, 0);

      expect((built as CometChatDate).style.textStyle, const TextStyle());
    });

    testWidgets('an unparsable bucket key renders nothing at all', (
      tester,
    ) async {
      // The empty key `storeValueInMapTime` produces for a null timestamp is
      // exactly this case: the whole day separator vanishes.
      final built = await render(tester, {
        '': [_outgoing()],
      }, 0);

      expect(built, isA<SizedBox>());
    });

    testWidgets('a key in the wrong date format also renders nothing', (
      tester,
    ) async {
      final built = await render(tester, {
        '2024-03-05': [_outgoing()],
      }, 0);

      expect(built, isA<SizedBox>());
    });
  });

  // ===========================================================================
  group('getTime', () {
    Future<Widget> render(
      WidgetTester tester,
      int? epochSeconds, {
      String? datePattern,
      CometChatDateStyle dateStyle = const CometChatDateStyle(),
      CometChatCallLogsStyle callLogsStyle = const CometChatCallLogsStyle(),
    }) async {
      late Widget built;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              built = CallLogsUtils.getTime(
                context,
                epochSeconds,
                CometChatThemeHelper.getColorPalette(context),
                CometChatThemeHelper.getTypography(context),
                CometChatThemeHelper.getSpacing(context),
                callLogsStyle,
                dateStyle,
                datePattern: datePattern,
              );
              return built;
            },
          ),
        ),
      );
      return built;
    }

    testWidgets('a null timestamp renders nothing', (tester) async {
      expect(await render(tester, null), isA<SizedBox>());
    });

    testWidgets('a timestamp becomes a dated label at zero padding', (
      tester,
    ) async {
      final epoch = DateTime(2024, 3, 5, 14, 7).millisecondsSinceEpoch ~/ 1000;

      final built = await render(tester, epoch) as CometChatDate;

      expect(built.date, DateTime(2024, 3, 5, 14, 7));
      expect(built.padding, EdgeInsets.zero);
      // With no override the label is pre-formatted by the util itself.
      expect(built.customDateString, contains('5 March'));
    });

    testWidgets('a datePattern replaces the formatted label', (tester) async {
      final epoch = DateTime(2024, 3, 5, 14, 7).millisecondsSinceEpoch ~/ 1000;

      final built =
          await render(tester, epoch, datePattern: 'h:mm a') as CometChatDate;

      expect(built.customDateString, 'h:mm a');
    });

    testWidgets('an explicit date style wins over the palette defaults', (
      tester,
    ) async {
      final epoch = DateTime(2024, 3, 5).millisecondsSinceEpoch ~/ 1000;
      const style = CometChatDateStyle(
        backgroundColor: Color(0xFF112233),
        textColor: Color(0xFF445566),
        borderRadius: BorderRadius.all(Radius.circular(9)),
      );

      final built =
          await render(tester, epoch, dateStyle: style) as CometChatDate;

      expect(built.style.backgroundColor, const Color(0xFF112233));
      expect(built.style.textColor, const Color(0xFF445566));
      expect(built.style.textStyle?.color, const Color(0xFF445566));
      expect(
        built.style.borderRadius,
        const BorderRadius.all(Radius.circular(9)),
      );
    });

    testWidgets('without a style the label still ellipsises and is themed', (
      tester,
    ) async {
      final epoch = DateTime(2024, 3, 5).millisecondsSinceEpoch ~/ 1000;

      final built = await render(tester, epoch) as CometChatDate;

      expect(built.style.textStyle?.overflow, TextOverflow.ellipsis);
      expect(built.style.textStyle?.fontSize, isNotNull);
      expect(built.style.borderRadius, BorderRadius.circular(0));
    });

    testWidgets('epoch zero is a real timestamp, not treated as absent', (
      tester,
    ) async {
      expect(await render(tester, 0), isA<CometChatDate>());
    });
  });
}
