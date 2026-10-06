// A11Y3 — the 200% text-scale pass over the primary screens.
//
// This is a ratchet, not a one-off audit. [_knownFindings] is empty — every
// scale-caused overflow and truncation this pass found has been fixed — so
// anything that appears here from now on fails the build.
//
// The fixes, for reference. `core/utils/text_scale_utils.dart` holds three
// helpers: `scaledMaxLines` lets a single-line label wrap above 1.15x instead
// of clipping (`CometChatListItem`, `CometChatConversationListItem`,
// `CometChatGroupListItem`, `CometChatFilesBubble`, `CometChatDate`);
// `scaledDimension` grows a fixed box with the text size (composer attachment
// tiles, audio player rows). Beyond those: the conversations empty state and the incoming-call
// screen became scrollable, the deleted bubble's label became `Flexible`, and
// the collaborative bubble's title column became `Expanded`.
//
// Getting the *context* right mattered as much as the fixes. Three findings
// turned out to be artefacts of how this file pumped a widget rather than bugs
// — a bubble in a bare `Scaffold` body reports overflow that a real message
// list would scroll away. [asBubble] is the answer to that; do not drop it when
// adding a bubble surface.
//
// `clippedAtDefaultScale` and `overflowAtDefaultScale` findings are reported
// below but NOT gated. Those already fail with no scaling at all, so scaling
// did not cause them and A11Y3 is not the ticket that fixes them — but they are
// printed on every run, because a string no user can read is worth someone
// picking up.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// CallLog, CallLogsListItem and CometChatCallBubble live in the calls barrel.
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';

import 'text_scale_harness.dart';

// ---------------------------------------------------------------------------
// Fakes — the same shapes the conversations golden test uses.
// ---------------------------------------------------------------------------

class _FakeUser extends Fake implements User {
  _FakeUser({required this.name, required this.uid, this.status = 'offline'});

  @override
  final String name;
  @override
  final String uid;
  @override
  final String status;
  @override
  String? get avatar => null;
  @override
  String? get role => 'default';
  @override
  bool? get blockedByMe => false;
  @override
  bool? get hasBlockedMe => false;
}

class _FakeGroup extends Fake implements Group {
  _FakeGroup({required this.name, required this.type, required this.guid});

  @override
  final String name;
  @override
  final String guid;
  @override
  final String type;
  @override
  String? get icon => null;
  @override
  int get membersCount => 24;
}

class _FakeConversation extends Fake implements Conversation {
  // 6.1.1 added conversation pinning, which the list row now reads. This
  // branch predates it, so the fake had no answer and threw.
  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;

  _FakeConversation({
    required AppEntity conversationWith,
    this.conversationId = 'c1',
    int unreadMessageCount = 0,
  }) : _with = conversationWith,
       _unread = unreadMessageCount;

  final AppEntity _with;
  final int _unread;

  @override
  final String conversationId;
  @override
  int get unreadMessageCount => _unread;
  @override
  AppEntity get conversationWith => _with;
  @override
  BaseMessage? get lastMessage => null;
}

class _FakeMediaMessage extends Fake implements MediaMessage {
  _FakeMediaMessage({required List<Attachment> attachments, this.caption})
    : _attachments = attachments;

  final List<Attachment> _attachments;

  @override
  final String? caption;

  @override
  List<Attachment>? get attachments => _attachments;
  @override
  Map<String, dynamic>? get metadata => null;
}

/// `CallLogsUtils.receiverName` type-tests the initiator and receiver against
/// `CallUser`, so faking the `CallEntity` marker class is not enough — the name
/// comes back empty and the row renders without a title.
class _FakeCallUser extends Fake implements CallUser {
  _FakeCallUser({required this.uid, required this.name});

  @override
  final String? uid;
  @override
  final String? name;
  @override
  String? get avatar => null;
}

class _FakeCallLog extends Fake implements CallLog {
  @override
  String? get sessionId => 'session_1';
  @override
  int? get initiatedAt => 1756713600;
  @override
  String? get type => 'audio';
  @override
  String? get status => 'unanswered';
  @override
  String? get receiverType => 'user';
  @override
  CallEntity? get initiator => _FakeCallUser(uid: 'bob', name: 'Bob Smith');
  @override
  CallEntity? get receiver =>
      _FakeCallUser(uid: 'alex', name: 'Alexandra Constantinou');
}

class _FakeCall extends Fake implements Call {
  @override
  String get sessionId => 'session_1';
  @override
  String get type => 'audio';
  @override
  String get receiverType => 'user';
  @override
  String get category => 'call';
  @override
  AppEntity? get callInitiator =>
      _FakeUser(name: 'Alexandra Constantinou', uid: 'alex');
  @override
  AppEntity? get callReceiver => _FakeUser(name: 'Bob Smith', uid: 'bob');
  @override
  User? get sender => _FakeUser(name: 'Alexandra Constantinou', uid: 'alex');
}

class _FakeTextMessage extends Fake implements TextMessage {
  // 6.1.1 added pinned and saved messages, which message information now reads.
  @override
  DateTime? get pinnedAt => null;

  @override
  DateTime? get savedAt => null;

  @override
  int get id => 1;
  @override
  String get text => 'Rescheduled to Thursday 14:00 — does that work?';
  @override
  String get category => 'message';
  @override
  User get sender => _FakeUser(name: 'Alexandra Constantinou', uid: 'alex');
  @override
  String get receiverUid => 'bob';
  @override
  String get type => 'text';
  @override
  String get receiverType => 'user';
  @override
  DateTime? get sentAt => DateTime(2026, 9, 1, 14, 30);
  @override
  DateTime? get deliveredAt => DateTime(2026, 9, 1, 14, 31);
  @override
  DateTime? get readAt => DateTime(2026, 9, 1, 14, 32);
  @override
  DateTime? get deletedAt => null;
  @override
  DateTime? get editedAt => null;
  @override
  String get muid => 'm1';
  @override
  Map<String, dynamic>? get metadata => null;
  @override
  ModerationStatusEnum? get moderationStatus => null;
  @override
  AppEntity get receiver => _FakeUser(name: 'Bob Smith', uid: 'bob');
  @override
  String? get conversationId => 'c1';
  @override
  int get parentMessageId => 0;
  @override
  int get replyCount => 0;
  @override
  List<User> get mentionedUsers => <User>[];
}

/// Long-but-realistic content. Short strings hide overflow: a name that fits at
/// 200% only because it is six characters proves nothing about a real one.
List<Conversation> _conversations() => <Conversation>[
  _FakeConversation(
    conversationWith: _FakeUser(
      name: 'Alexandra Constantinou',
      uid: 'alex',
      status: 'online',
    ),
    unreadMessageCount: 3,
  ),
  _FakeConversation(
    conversationWith: _FakeGroup(
      name: 'Platform Engineering — On Call',
      type: CometChatGroupType.public,
      guid: 'oncall',
    ),
    conversationId: 'c2',
    unreadMessageCount: 128,
  ),
  _FakeConversation(
    conversationWith: _FakeUser(name: 'Bob Smith', uid: 'bob'),
    conversationId: 'c3',
  ),
];

// ---------------------------------------------------------------------------
// Known findings. Empty, and it should stay that way.
//
// Every entry would be a WCAG 2.1 AA 1.4.4 failure being accepted rather than
// fixed. Do not add to this set to make a build pass; add to it only when a
// finding has been reviewed and consciously deferred, with the reason written
// down next to it.
// ---------------------------------------------------------------------------

const Set<String> _knownFindings = <String>{};

// ---------------------------------------------------------------------------

void main() {
  final List<Finding> all = <Finding>[];

  /// Lays a bubble out the way the message list does: inside a scroll view,
  /// aligned to one side, bounded to 72% of the screen — the rule the Kit's own
  /// multi-attachment bubbles apply.
  ///
  /// Both halves matter. Pumping a bubble into a bare `Align` lets it take the
  /// full viewport width and report overflow no user would ever see; leaving
  /// out the scroll view makes any bubble taller than the screen look like an
  /// overflow, when in a real message list it simply scrolls. What survives
  /// this wrapper is a bubble that cannot fit the space it is actually given.
  Widget asBubble(BuildContext context, Widget child, BubbleAlignment side) {
    return SingleChildScrollView(
      child: Align(
        alignment: side == BubbleAlignment.right
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.72,
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> check(
    WidgetTester tester,
    String surface,
    Widget Function() builder,
  ) async {
    await mockNetworkImagesFor(() async {
      all.addAll(
        await collectFindings(tester, surface: surface, builder: builder),
      );
    });
  }

  group('200% text scale — primary screens', () {
    testWidgets('conversations list', (WidgetTester tester) async {
      final List<Conversation> conversations = _conversations();
      await check(tester, 'conversations list', () {
        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (BuildContext context, int index) =>
              CometChatConversationListItem(
                conversation: conversations[index],
                onItemClick: (_) {},
              ),
        );
      });
    });

    testWidgets('conversations empty state', (WidgetTester tester) async {
      await check(tester, 'conversations empty state', () {
        return Builder(
          builder: (BuildContext context) => ConversationsEmptyView(
            style: const CometChatConversationsStyle(),
            colorPalette: CometChatThemeHelper.getColorPalette(context),
            spacing: CometChatThemeHelper.getSpacing(context),
            typography: CometChatThemeHelper.getTypography(context),
          ),
        );
      });
    });

    testWidgets('conversations error state', (WidgetTester tester) async {
      await check(tester, 'conversations error state', () {
        return Builder(
          builder: (BuildContext context) => ConversationsErrorView(
            errorMessage:
                'Something went wrong while loading your conversations. '
                'Check your connection and try again.',
            style: const CometChatConversationsStyle(),
            colorPalette: CometChatThemeHelper.getColorPalette(context),
            spacing: CometChatThemeHelper.getSpacing(context),
            typography: CometChatThemeHelper.getTypography(context),
          ),
        );
      });
    });

    testWidgets('shared list item', (WidgetTester tester) async {
      await check(tester, 'shared list item', () {
        return const CometChatListItem(
          avatarName: 'Alexandra Constantinou',
          title: 'Alexandra Constantinou',
          subtitleView: Text('Typing a fairly ordinary message right now…'),
        );
      });
    });

    testWidgets('text bubble', (WidgetTester tester) async {
      await check(tester, 'text bubble', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            const CometChatTextBubble(
              text:
                  'Rescheduled to Thursday 14:00 — can you confirm that works '
                  'before I send the invite out to everyone?',
              alignment: BubbleAlignment.right,
            ),
            BubbleAlignment.right,
          ),
        );
      });
    });

    // The multi-attachment bubble, not the deprecated single-file one:
    // `enableMultipleAttachments` defaults to true, so this is what ships.
    testWidgets('files bubble', (WidgetTester tester) async {
      final MediaMessage message = _FakeMediaMessage(
        caption: 'Latest two — the second one supersedes what I sent Monday.',
        attachments: <Attachment>[
          Attachment(
            'https://example.invalid/a.pdf',
            'Q3-platform-readiness-review-final-v2.pdf',
            'pdf',
            'application/pdf',
            2516582,
          ),
          Attachment(
            'https://example.invalid/b.xlsx',
            'coverage-by-component-2026-09.xlsx',
            'xlsx',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            88410,
          ),
        ],
      );
      await check(tester, 'files bubble', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            CometChatFilesBubble(
              message: message,
              alignment: BubbleAlignment.left,
            ),
            BubbleAlignment.left,
          ),
        );
      });
    });

    testWidgets('avatar, badge and date row', (WidgetTester tester) async {
      await check(tester, 'avatar, badge and date row', () {
        return Row(
          children: <Widget>[
            const CometChatAvatar(name: 'Alexandra Constantinou'),
            const Expanded(child: Text('Alexandra Constantinou')),
            CometChatDate(date: DateTime(2026, 9, 1, 14, 30)),
            const CometChatBadge(count: 128),
          ],
        );
      });
    });

    // --- groups -----------------------------------------------------------

    testWidgets('groups list', (WidgetTester tester) async {
      final List<Group> groups = <Group>[
        _FakeGroup(
          name: 'Platform Engineering — On Call',
          type: CometChatGroupType.public,
          guid: 'oncall',
        ),
        _FakeGroup(
          name: 'Design Review',
          type: CometChatGroupType.private,
          guid: 'design',
        ),
      ];
      await check(tester, 'groups list', () {
        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (BuildContext context, int index) =>
              CometChatGroupListItem(group: groups[index], onItemClick: (_) {}),
        );
      });
    });

    // --- call logs --------------------------------------------------------

    testWidgets('call log list item', (WidgetTester tester) async {
      await check(tester, 'call log list item', () {
        return CallLogsListItem(
          callLog: _FakeCallLog(),
          loggedInUser: _FakeUser(name: 'Bob Smith', uid: 'bob'),
        );
      });
    });

    // --- composer ---------------------------------------------------------

    testWidgets('composer attachment tray', (WidgetTester tester) async {
      await check(tester, 'composer attachment tray', () {
        return SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              CometChatAttachmentTile(
                tile: AttachmentTile(
                  fileId: 'f1',
                  name: 'Q3-platform-readiness-review-final-v2.pdf',
                  mimeType: 'application/pdf',
                  size: 2516582,
                  status: AttachmentTileStatus.done,
                ),
                onCancelOrRemove: () {},
              ),
              CometChatAttachmentTile(
                tile: AttachmentTile(
                  fileId: 'f2',
                  name: 'coverage.xlsx',
                  mimeType: 'application/vnd.ms-excel',
                  size: 88410,
                  status: AttachmentTileStatus.failed,
                  errorMessage: 'Upload failed',
                ),
                onCancelOrRemove: () {},
              ),
            ],
          ),
        );
      });
    });

    // --- message list bubbles ---------------------------------------------

    testWidgets('action bubble', (WidgetTester tester) async {
      await check(tester, 'action bubble', () {
        return const CometChatActionBubble(
          text:
              'Alexandra Constantinou added Bob Smith to Platform '
              'Engineering — On Call',
        );
      });
    });

    testWidgets('deleted bubble', (WidgetTester tester) async {
      await check(tester, 'deleted bubble', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            const CometChatDeletedBubble(),
            BubbleAlignment.left,
          ),
        );
      });
    });

    testWidgets('deleted bubble via its factory', (WidgetTester tester) async {
      // The factory lays the deleted row out itself rather than delegating to
      // CometChatDeletedBubble, and it is the path the message list actually
      // takes. 6.2.0's Flexible fix reached the bubble above and not this
      // copy, and this harness did not catch that because it only pumped the
      // bubble — so the second copy is covered here too now. ENG-39099.
      await check(tester, 'deleted bubble via its factory', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            DeletedBubbleFactory().build(
              context,
              _FakeTextMessage(),
              BubbleAlignment.left,
            ),
            BubbleAlignment.left,
          ),
        );
      });
    });

    testWidgets('call bubble', (WidgetTester tester) async {
      await check(tester, 'call bubble', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            const CometChatCallBubble(
              title: 'Missed audio call',
              subtitle: 'Tap to call back',
              buttonText: 'Call again',
              alignment: BubbleAlignment.left,
            ),
            BubbleAlignment.left,
          ),
        );
      });
    });

    testWidgets('images bubble', (WidgetTester tester) async {
      final MediaMessage message = _FakeMediaMessage(
        caption: 'Three from the offsite — the second is the one for the deck.',
        attachments: <Attachment>[
          Attachment(
            'https://example.invalid/1.png',
            'offsite-1.png',
            'png',
            'image/png',
            184320,
          ),
          Attachment(
            'https://example.invalid/2.png',
            'offsite-2.png',
            'png',
            'image/png',
            201110,
          ),
        ],
      );
      await check(tester, 'images bubble', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            CometChatImagesBubble(
              message: message,
              alignment: BubbleAlignment.left,
            ),
            BubbleAlignment.left,
          ),
        );
      });
    });

    // --- message header ---------------------------------------------------

    testWidgets('message header', (WidgetTester tester) async {
      await check(tester, 'message header', () {
        return CometChatMessageHeader(
          user: _FakeUser(
            name: 'Alexandra Constantinou',
            uid: 'alex',
            status: 'online',
          ),
        );
      });
    });

    // --- media viewer -----------------------------------------------------

    testWidgets('media viewer', (WidgetTester tester) async {
      await check(tester, 'media viewer', () {
        return CometChatMediaViewer(
          mediaItems: <Attachment>[
            Attachment(
              'https://example.invalid/1.png',
              'offsite-team-photo-2026-09-01.png',
              'png',
              'image/png',
              184320,
            ),
          ],
        );
      });
    });

    // --- remaining message bubbles ----------------------------------------

    testWidgets('voice note bubble', (WidgetTester tester) async {
      await check(tester, 'voice note bubble', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            const CometChatVoiceNoteBubble(
              title: 'Voice message',
              alignment: BubbleAlignment.right,
            ),
            BubbleAlignment.right,
          ),
        );
      });
    });

    testWidgets('audios bubble', (WidgetTester tester) async {
      final MediaMessage message = _FakeMediaMessage(
        caption: 'Two takes — the second one is the keeper.',
        attachments: <Attachment>[
          Attachment(
            'https://example.invalid/a.m4a',
            'standup-recap-take-2.m4a',
            'm4a',
            'audio/mp4',
            402110,
          ),
        ],
      );
      await check(tester, 'audios bubble', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            CometChatAudiosBubble(
              message: message,
              alignment: BubbleAlignment.left,
            ),
            BubbleAlignment.left,
          ),
        );
      });
    });

    testWidgets('videos bubble', (WidgetTester tester) async {
      final MediaMessage message = _FakeMediaMessage(
        caption: 'Screen recording of the overflow at 200%.',
        attachments: <Attachment>[
          Attachment(
            'https://example.invalid/v.mp4',
            'text-scale-repro.mp4',
            'mp4',
            'video/mp4',
            8402110,
          ),
        ],
      );
      await check(tester, 'videos bubble', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            CometChatVideosBubble(
              message: message,
              alignment: BubbleAlignment.left,
            ),
            BubbleAlignment.left,
          ),
        );
      });
    });

    testWidgets('collaborative bubble', (WidgetTester tester) async {
      await check(tester, 'collaborative bubble', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            const CometChatCollaborativeBubble(
              url: 'https://example.invalid/doc',
              title: 'Collaborative Document',
              subtitle:
                  'Alexandra Constantinou has shared a document to '
                  'collaborate on',
              buttonText: 'Open Document',
              alignment: BubbleAlignment.left,
            ),
            BubbleAlignment.left,
          ),
        );
      });
    });

    testWidgets('ai assistant bubble', (WidgetTester tester) async {
      await check(tester, 'ai assistant bubble', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            const CometChatAIAssistantBubble(
              text:
                  'The composer is the largest component in the package at '
                  '22k lines, and it had five test files before this pass.',
              alignment: BubbleAlignment.left,
            ),
            BubbleAlignment.left,
          ),
        );
      });
    });

    testWidgets('message bubble wrapper', (WidgetTester tester) async {
      await check(tester, 'message bubble wrapper', () {
        return Builder(
          builder: (BuildContext context) => asBubble(
            context,
            const CometChatMessageBubble(
              alignment: BubbleAlignment.right,
              headerView: Text('Alexandra Constantinou'),
              contentView: CometChatTextBubble(
                text: 'Rescheduled to Thursday 14:00 — does that work?',
                alignment: BubbleAlignment.right,
              ),
              footerView: Text('14:32'),
            ),
            BubbleAlignment.right,
          ),
        );
      });
    });

    // --- call screens -----------------------------------------------------

    testWidgets('incoming call', (WidgetTester tester) async {
      await check(tester, 'incoming call', () {
        return CometChatIncomingCall(
          call: _FakeCall(),
          user: _FakeUser(name: 'Alexandra Constantinou', uid: 'alex'),
          disableSoundForCalls: true,
        );
      });
    });

    testWidgets('outgoing call', (WidgetTester tester) async {
      await check(tester, 'outgoing call', () {
        return CometChatOutgoingCall(
          call: _FakeCall(),
          user: _FakeUser(name: 'Alexandra Constantinou', uid: 'alex'),
          disableSoundForCalls: true,
        );
      });
    });

    // --- message information ----------------------------------------------

    testWidgets('message information', (WidgetTester tester) async {
      await check(tester, 'message information', () {
        return CometChatMessageInformation(message: _FakeTextMessage());
      });
    });

    // --- search / notification feed / users -------------------------------
    //
    // These three build their own bloc and hit the SDK on construction, so they
    // cannot be pumped in a widget test without a live CometChat session. What
    // is testable of them is already covered: all three render their rows
    // through `CometChatListItem`, which has its own surface above, and the
    // search results reuse the message bubbles. If they ever grow a
    // presentational sub-view that can be constructed standalone, add it here.

    testWidgets('users list', (WidgetTester tester) async {
      await check(tester, 'users list', () {
        return ListView(
          children: <Widget>[
            CometChatListItem(
              avatarName: 'Alexandra Constantinou',
              title: 'Alexandra Constantinou',
              subtitleView: const Text('Available'),
            ),
            CometChatListItem(
              avatarName: 'Bob Smith',
              title: 'Bob Smith',
              subtitleView: const Text('Away — back at 15:00'),
            ),
          ],
        );
      });
    });

    tearDownAll(() {
      // `clippedAtDefaultScale` is reported, not gated: text that does not fit
      // without any scaling is a layout bug rather than a text-scale one, and
      // A11Y3 is not the ticket that fixes it.
      final List<Finding> unexpected = all
          .where(
            (Finding f) =>
                f.kind != FindingKind.clippedAtDefaultScale &&
                f.kind != FindingKind.overflowAtDefaultScale &&
                !_knownFindings.contains(f.key),
          )
          .toList();

      // Always print the full picture: a green run should still tell you where
      // the Kit stands at 200%, not just that nothing regressed.
      final StringBuffer report = StringBuffer()
        ..writeln('')
        ..writeln('200% text-scale pass — ${all.length} finding(s)');
      for (final Finding f in all..sort((a, b) => a.key.compareTo(b.key))) {
        report.writeln(
          '  ${_knownFindings.contains(f.key) ? 'known' : 'NEW  '}  $f',
        );
      }
      // ignore: avoid_print
      print(report);

      expect(
        unexpected,
        isEmpty,
        reason:
            'These surfaces break at increased text scale and are not in '
            '_knownFindings. Fix the layout, or — if it is a deliberate, '
            'reviewed regression — add the key to _knownFindings with a '
            'reason.\n\n'
            '${unexpected.map((Finding f) => '  $f').join('\n')}',
      );
    });
  });
}
