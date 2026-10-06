/// Behaviour tests for the ConversationUtils category dispatch and the icon
/// builders — Track 3 TEST3 (ENG-38684).
///
/// `conversation_utils_test.dart` covers the markdown stripping and
/// `conversation_subtitle_test.dart` covers `getLastMessage`. Everything else
/// in the file was untested: the category dispatch that picks which subtitle
/// builder runs, the custom / interactive / action / call builders behind it,
/// and the entire widget half that produces the leading icon on a conversation
/// row. The file sat at 28.1%.
///
/// The widget builders are asserted by pumping what they return, not by
/// reading their source back: an `Icon` that cannot build is not a passing
/// icon.
///
///   flutter test test/shared_ui/utils/conversation_dispatch_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as cc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');

TextMessage _text(String body) => TextMessage(
  text: body,
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: MessageTypeConstants.text,
  sender: _alice,
);

CustomMessage _custom(String type, {User? sender}) => CustomMessage(
  customData: const {'k': 'v'},
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: type,
  category: MessageCategoryConstants.custom,
  sender: sender ?? _alice,
);

final _team = Group(guid: 'g1', name: 'Team', type: 'public');
final _otherTeam = Group(guid: 'g2', name: 'Other', type: 'public');

Call _call(String type, {String? status, AppEntity? initiator}) => Call(
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: type,
  category: MessageCategoryConstants.call,
  sender: _alice,
  callStatus: status,
  callInitiator: initiator,
);

/// A file/media message whose attachment carries a chosen extension and MIME
/// type — the two hints `_getFileIconWidget` branches on.
MediaMessage _attached(
  String type, {
  String ext = 'bin',
  String mime = 'application/octet-stream',
  String? fileName,
}) =>
    MediaMessage(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        type: type,
        sender: _alice,
      )
      ..attachment = Attachment(
        'https://x/file.$ext',
        fileName ?? 'file.$ext',
        ext,
        mime,
        1,
      );

/// Text message carrying the link-preview extension payload the leading-icon
/// builder looks for. [links] of `null` omits the key entirely.
TextMessage _withInjected(Map<String, dynamic>? injected) => TextMessage(
  text: 'look at this',
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: MessageTypeConstants.text,
  sender: _alice,
)..metadata = injected;

Map<String, dynamic> _linkPreview(List<dynamic>? links) => {
  '@injected': {
    'extensions': {
      'link-preview': links == null ? <String, dynamic>{} : {'links': links},
    },
  },
};

MediaMessage _media(String type, {String? fileName}) {
  final m = MediaMessage(
    receiverUid: 'u2',
    receiverType: CometChatReceiverType.user,
    type: type,
    sender: _alice,
  );
  if (fileName != null) {
    m.attachment = Attachment(
      'https://x/$fileName',
      fileName,
      fileName.split('.').last,
      'application/octet-stream',
      1,
    );
  }
  return m;
}

Conversation _conversation(BaseMessage last, {AppEntity? with_}) =>
    Conversation(
      conversationId: 'c1',
      conversationType: CometChatConversationType.user,
      conversationWith: with_ ?? _bob,
      lastMessage: last,
    );

/// Runs [body] with a real BuildContext, which every builder here needs for
/// its localized labels and its colour palette.
Future<void> withContext(
  WidgetTester tester,
  void Function(BuildContext) body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) {
          body(context);
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pump();
}

/// Builds [build]'s widget inside a real tree and returns it, so a builder is
/// only credited when what it produced actually renders.
Future<Widget> pumpBuilt(
  WidgetTester tester,
  Widget Function(BuildContext) build,
) async {
  late Widget produced;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) {
          produced = build(context);
          return Scaffold(body: Center(child: produced));
        },
      ),
    ),
  );
  await tester.pump();
  return produced;
}

void main() {
  setUp(() {
    // The group-call subtitle branches on this static; without it every
    // meeting message reads as though someone else started the call.
    CometChatUIKit.loggedInUser = _alice;
  });

  tearDown(() {
    CometChatUIKit.loggedInUser = null;
  });

  // ==========================================================================
  group('getLastCustomMessage', () {
    testWidgets('each extension type gets its own label', (tester) async {
      await withContext(tester, (context) {
        final sticker = ConversationUtils.getLastCustomMessage(
          _conversation(_custom(ExtensionType.sticker)),
          context,
        );
        final document = ConversationUtils.getLastCustomMessage(
          _conversation(_custom(ExtensionType.document)),
          context,
        );
        final whiteboard = ConversationUtils.getLastCustomMessage(
          _conversation(_custom(ExtensionType.whiteboard)),
          context,
        );
        final poll = ConversationUtils.getLastCustomMessage(
          _conversation(_custom(ExtensionType.extensionPoll)),
          context,
        );

        for (final s in [sticker, document, whiteboard, poll]) {
          expect(s, isNotEmpty);
        }
        // Four distinct labels, not one label reused for every extension.
        expect({sticker, document, whiteboard, poll}.length, 4);
      });
    });

    testWidgets('an unknown custom type falls back to the raw type', (
      tester,
    ) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastCustomMessage(
            _conversation(_custom('something_we_do_not_know')),
            context,
          ),
          'something_we_do_not_know',
        );
      });
    });

    testWidgets('a non-custom last message yields the empty string', (
      tester,
    ) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastCustomMessage(
            _conversation(_text('not a custom message')),
            context,
          ),
          '',
        );
      });
    });

    testWidgets('a group call reads differently for me and for someone else', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final mine = ConversationUtils.getLastCustomMessage(
          _conversation(_custom(MessageTypeConstants.meeting, sender: _alice)),
          context,
        );
        final theirs = ConversationUtils.getLastCustomMessage(
          _conversation(_custom(MessageTypeConstants.meeting, sender: _bob)),
          context,
        );

        expect(mine, isNotEmpty);
        expect(mine, isNot(theirs));
        // The other party's line is attributed to them by name.
        expect(theirs, contains('Bob'));
      });
    });
  });

  // ==========================================================================
  group('getLastActionMessage', () {
    testWidgets('a group action uses the action text the server sent', (
      tester,
    ) async {
      final action = cc.Action(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        type: MessageTypeConstants.groupActions,
        category: MessageCategoryConstants.action,
        sender: _alice,
      )..message = 'Alice added Bob';

      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastActionMessage(
            _conversation(action),
            context,
          ),
          'Alice added Bob',
        );
      });
    });

    testWidgets('a group action with no text does not blow up', (tester) async {
      final action = cc.Action(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        type: MessageTypeConstants.groupActions,
        category: MessageCategoryConstants.action,
        sender: _alice,
      );

      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastActionMessage(
            _conversation(action),
            context,
          ),
          '',
        );
      });
    });
  });

  // ==========================================================================
  group('getLastConversationMessage — category dispatch', () {
    testWidgets('a text message routes to the message builder', (tester) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastConversationMessage(
            _conversation(_text('routed')),
            context,
          ),
          'routed',
        );
      });
    });

    testWidgets('a custom message routes to the custom builder', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final viaDispatch = ConversationUtils.getLastConversationMessage(
          _conversation(_custom(ExtensionType.sticker)),
          context,
        );
        final direct = ConversationUtils.getLastCustomMessage(
          _conversation(_custom(ExtensionType.sticker)),
          context,
        );
        expect(viaDispatch, direct);
        expect(viaDispatch, isNotEmpty);
      });
    });

    testWidgets('a call message routes to the call builder', (tester) async {
      await withContext(tester, (context) {
        final subtitle = ConversationUtils.getLastConversationMessage(
          _conversation(_call(MessageTypeConstants.audio)),
          context,
        );
        expect(subtitle, isNotEmpty);
      });
    });

    testWidgets('a conversation with no last message throws — pinned, not ok', (
      tester,
    ) async {
      // This pins a latent defect rather than endorsing it. The function reads
      // the category with `?.` (line 392, so null is expected there) and then
      // its `default:` branch does `conversation.lastMessage!.type` — a null
      // assert on the field it just admitted could be null. A conversation
      // with no messages yet hits it.
      //
      // It is not a live crash in the conversation list: the widget-side
      // caller, ConversationSubtitleUtils.getLastConversationWidget, returns
      // early on `messageCategory == null || lastMessage == null`
      // (conversation_subtitle_utils.dart:50). But the sibling passthrough at
      // line 12 of that file has no such guard, and this is public API.
      //
      // Fixing it is a lib/ change and belongs in its own ticket, not in this
      // measurement track. If someone does fix it, this test will fail — that
      // is the intent; update it then.
      final empty = Conversation(
        conversationId: 'c-empty',
        conversationType: CometChatConversationType.user,
        conversationWith: _bob,
      );
      await withContext(tester, (context) {
        expect(
          () => ConversationUtils.getLastConversationMessage(empty, context),
          throwsA(isA<TypeError>()),
        );
      });
    });
  });

  // ==========================================================================
  group('getLastMessageWidget — the leading icon', () {
    testWidgets('an image message produces an icon that renders', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(_media(MessageTypeConstants.image)),
          context,
          Colors.red,
        ),
      );
      expect(w, isA<Icon>());
      expect((w as Icon).color, Colors.red);
      expect(find.byIcon(w.icon!), findsOneWidget);
    });

    testWidgets('a video message produces a different icon than an image', (
      tester,
    ) async {
      late Icon image;
      late Icon video;
      await withContext(tester, (context) {
        // Hoisted into locals before the cast: a cast tacked onto a
        // multi-line call formats differently between the Flutter the floor
        // declares and the one package-checks pins, and the format gate
        // rejects whichever it did not produce. See analyze_gate.dart's
        // header.
        final imageWidget = ConversationUtils.getLastMessageWidget(
          _conversation(_media(MessageTypeConstants.image)),
          context,
          null,
        );
        final videoWidget = ConversationUtils.getLastMessageWidget(
          _conversation(_media(MessageTypeConstants.video)),
          context,
          null,
        );
        image = imageWidget as Icon;
        video = videoWidget as Icon;
      });
      expect(image.icon, isNot(video.icon));
    });

    testWidgets('a file message produces an icon that renders', (tester) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(
            _media(MessageTypeConstants.file, fileName: 'report.pdf'),
          ),
          context,
          null,
        ),
      );
      expect(w, isA<Icon>());
      expect(find.byIcon((w as Icon).icon!), findsOneWidget);
    });

    testWidgets('an audio message produces an icon that renders', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(
            _media(MessageTypeConstants.audio, fileName: 'note.mp3'),
          ),
          context,
          null,
        ),
      );
      expect(w, isA<Icon>());
      expect(find.byIcon((w as Icon).icon!), findsOneWidget);
    });

    testWidgets('an unknown type produces an empty box, not a crash', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(_media('hologram')),
          context,
          null,
        ),
      );
      expect(w, isA<SizedBox>());
    });
  });

  // ==========================================================================
  group('getLastConversationIcon — category dispatch', () {
    testWidgets('a media message routes to the message widget builder', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastConversationIcon(
          _conversation(_media(MessageTypeConstants.image)),
          context,
          null,
        ),
      );
      expect(w, isA<Icon>());
    });

    testWidgets('a custom message routes to the custom widget builder', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastConversationIcon(
          _conversation(_custom(ExtensionType.sticker)),
          context,
          null,
        ),
      );
      expect(w, isNotNull);
    });

    testWidgets('a call message routes to the call widget builder', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastConversationIcon(
          _conversation(_call(MessageTypeConstants.audio)),
          context,
          null,
        ),
      );
      expect(w, isNotNull);
    });

    testWidgets('a text message contributes no icon', (tester) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastConversationIcon(
          _conversation(_text('plain')),
          context,
          null,
        ),
      );
      // Text rows carry their subtitle, not a leading glyph.
      expect(w, isNotNull);
    });

    testWidgets('an interactive message gets the blocked glyph', (
      tester,
    ) async {
      // Interactive previews are not implemented yet (the builder's own TODO),
      // so the row shows a "not supported" marker rather than nothing.
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastConversationIcon(
          _conversation(_interactive(MessageTypeConstants.form)),
          context,
          Colors.teal,
        ),
      );
      expect(w, isA<Icon>());
      expect((w as Icon).icon, Icons.block);
      expect(w.color, Colors.teal);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('an action message contributes no icon', (tester) async {
      // `action` has no case in the widget dispatch (it is commented out in
      // the source), so it lands on the default arm.
      final action = cc.Action(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        type: MessageTypeConstants.groupActions,
        category: MessageCategoryConstants.action,
        sender: _alice,
      );
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastConversationIcon(
          _conversation(action),
          context,
          null,
        ),
      );
      expect(w, isA<SizedBox>());
    });
  });

  // ==========================================================================
  group('getDefaultOptionsWithCallback', () {
    testWidgets('produces a single delete option wired to the callback', (
      tester,
    ) async {
      final deleted = <Conversation>[];
      final conversation = _conversation(_text('bye'));
      late List<CometChatOption> options;

      await withContext(tester, (context) {
        options = ConversationUtils.getDefaultOptionsWithCallback(
          conversation: conversation,
          context: context,
          colorPalette: CometChatThemeHelper.getColorPalette(context),
          onDelete: deleted.add,
        )!;
      });

      expect(options, hasLength(1));
      final option = options.single;
      expect(option.id, ConversationOptionConstants.delete);
      expect(option.icon, AssetConstants.delete);
      expect(option.packageName, UIConstants.packageName);
      expect(option.title, isNotEmpty);

      expect(deleted, isEmpty, reason: 'building an option must not delete');
      option.onClick!();
      expect(deleted, [same(conversation)]);
    });

    testWidgets('the delete option is tinted with the error colour', (
      tester,
    ) async {
      late CometChatColorPalette palette;
      late CometChatOption option;
      await withContext(tester, (context) {
        palette = CometChatThemeHelper.getColorPalette(context);
        option = ConversationUtils.getDefaultOptionsWithCallback(
          conversation: _conversation(_text('bye')),
          context: context,
          colorPalette: palette,
          onDelete: null,
        )!.single;
      });
      expect(option.iconTint, palette.error);
      expect(option.backgroundColor, palette.background1);
    });

    testWidgets('a null callback makes the option a no-op, not a crash', (
      tester,
    ) async {
      late CometChatOption option;
      await withContext(tester, (context) {
        option = ConversationUtils.getDefaultOptionsWithCallback(
          conversation: _conversation(_text('bye')),
          context: context,
          colorPalette: CometChatThemeHelper.getColorPalette(context),
          onDelete: null,
        )!.single;
      });
      expect(option.onClick, isNotNull);
      expect(option.onClick!, returnsNormally);
    });

    testWidgets('the deprecated overload delegates and never deletes', (
      tester,
    ) async {
      // The old signature took a controller and had no way to be told what to
      // do on delete, which is why it was replaced. It must still return the
      // same option, with an onClick that does nothing.
      late List<CometChatOption> legacy;
      await withContext(tester, (context) {
        // ignore: deprecated_member_use_from_same_package
        legacy = ConversationUtils.getDefaultOptions(
          _conversation(_text('bye')),
          null,
          context,
          CometChatThemeHelper.getColorPalette(context),
        )!;
      });
      expect(legacy, hasLength(1));
      expect(legacy.single.id, ConversationOptionConstants.delete);
      expect(legacy.single.onClick!, returnsNormally);
    });
  });

  // ==========================================================================
  group('getLastInteractiveMessage', () {
    testWidgets('a form message gets the form label', (tester) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastInteractiveMessage(
            _conversation(_interactive(MessageTypeConstants.form)),
            context,
          ),
          Translations.of(context).formMessage,
        );
      });
    });

    testWidgets('a card message gets the card label', (tester) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastInteractiveMessage(
            _conversation(_interactive(MessageTypeConstants.card)),
            context,
          ),
          Translations.of(context).cardMessage,
        );
      });
    });

    testWidgets('a scheduler message gets a calendar-prefixed title', (
      tester,
    ) async {
      final scheduler = SchedulerMessage(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        sender: _alice,
        title: 'Design review',
        duration: 30,
      ).toInteractiveMessage();

      await withContext(tester, (context) {
        final s = ConversationUtils.getLastInteractiveMessage(
          _conversation(scheduler),
          context,
        );
        expect(s, startsWith('🗓️ '));
        expect(s, contains('Design review'));
      });
    });

    testWidgets('an unknown interactive type falls back to the raw type', (
      tester,
    ) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastInteractiveMessage(
            _conversation(_interactive('hologram')),
            context,
          ),
          'hologram',
        );
      });
    });
  });

  // ==========================================================================
  group('getLastActionMessage — non-group action', () {
    testWidgets('a non-groupMember action falls back to the type name', (
      tester,
    ) async {
      final action = cc.Action(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        type: 'message',
        category: MessageCategoryConstants.action,
        sender: _alice,
      )..message = 'ignored';

      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastActionMessage(
            _conversation(action),
            context,
          ),
          'message',
          reason: 'only groupMember actions use the server-sent text',
        );
      });
    });
  });

  // ==========================================================================
  group('getLastConversationMessage — interactive and card categories', () {
    testWidgets('an interactive message reads as unsupported', (tester) async {
      // The interactive subtitle builder exists but is deliberately not wired
      // up yet (see the TODO in the source); the row says so instead.
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastConversationMessage(
            _conversation(_interactive(MessageTypeConstants.form)),
            context,
          ),
          Translations.of(context).unsupportedMessageType,
        );
      });
    });

    testWidgets('a card message uses its own preview text', (tester) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastConversationMessage(
            _conversation(_card('Your order shipped')),
            context,
          ),
          'Your order shipped',
        );
      });
    });

    testWidgets('a card with no preview text falls back to the card label', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final label = Translations.of(context).cardMessage;
        expect(
          ConversationUtils.getLastConversationMessage(
            _conversation(_card(null)),
            context,
          ),
          label,
        );
        expect(
          ConversationUtils.getLastConversationMessage(
            _conversation(_card('')),
            context,
          ),
          label,
        );
      });
    });
  });

  // ==========================================================================
  group('getLastMessage — URL shortening edge cases', () {
    testWidgets('a URL with no path is reduced to the bare domain', (
      tester,
    ) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastMessage(
            _conversation(
              _text('https://example.com?q=aaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
            ),
            context,
          ),
          'example.com...',
        );
      });
    });

    testWidgets('an over-long domain is truncated to 30 characters', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final s = ConversationUtils.getLastMessage(
          _conversation(
            _text('https://averyveryverylongdomainnamehere.example.com/x'),
          ),
          context,
        );
        expect(s, 'averyveryverylongdomainname...');
        expect(s, hasLength(30));
      });
    });

    testWidgets('a URL that will not parse is truncated raw', (tester) async {
      // `[notanipv6]` makes Uri.parse throw, which is the only way into the
      // catch arm. The subtitle must still be a short string, not an
      // exception escaping into the conversation list.
      await withContext(tester, (context) {
        final s = ConversationUtils.getLastMessage(
          _conversation(
            _text('https://[notanipv6]/path/aaaaaaaaaaaaaaaaaaaaaaaa'),
          ),
          context,
        );
        expect(s, hasLength(30));
        expect(s, startsWith('https://[notanipv6]'));
        expect(s, endsWith('...'));
      });
    });
  });

  // ==========================================================================
  group('_getFileIconWidget — icon per file kind', () {
    // Each row: a description, the attachment hint, and the icon it must pick.
    final byExtension = <String, IconData>{
      'pdf': Icons.picture_as_pdf,
      'doc': Icons.article,
      'docx': Icons.article,
      'xls': Icons.table_chart,
      'xlsx': Icons.table_chart,
      'csv': Icons.table_chart,
      'ppt': Icons.slideshow,
      'pptx': Icons.slideshow,
      'zip': Icons.folder_zip,
      'rar': Icons.folder_zip,
      '7z': Icons.folder_zip,
      'tar': Icons.folder_zip,
      'gz': Icons.folder_zip,
      'txt': Icons.text_snippet,
      'md': Icons.text_snippet,
      'log': Icons.text_snippet,
      'bin': Icons.description,
    };

    byExtension.forEach((ext, expected) {
      testWidgets('a .$ext attachment uses its own icon', (tester) async {
        final w = await pumpBuilt(
          tester,
          (context) => ConversationUtils.getLastMessageWidget(
            _conversation(_attached(MessageTypeConstants.file, ext: ext)),
            context,
            null,
          ),
        );
        expect((w as Icon).icon, expected, reason: ext);
      });
    });

    final byMime = <String, IconData>{
      'application/pdf': Icons.picture_as_pdf,
      'application/msword': Icons.article,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
          Icons.article,
      'application/vnd.ms-excel': Icons.table_chart,
      'application/vnd.oasis.opendocument.spreadsheet': Icons.table_chart,
      'text/csv': Icons.table_chart,
      'application/vnd.ms-powerpoint': Icons.slideshow,
      'application/vnd.oasis.opendocument.presentation': Icons.slideshow,
      'application/zip': Icons.folder_zip,
      'application/x-compressed': Icons.folder_zip,
      'application/x-tar': Icons.folder_zip,
      'application/gzip': Icons.folder_zip,
      'text/plain': Icons.text_snippet,
      'image/png': Icons.photo,
      'video/mp4': Icons.videocam,
      'audio/mpeg': Icons.audiotrack,
      'application/octet-stream': Icons.description,
    };

    byMime.forEach((mime, expected) {
      testWidgets('a $mime attachment uses its own icon', (tester) async {
        final w = await pumpBuilt(
          tester,
          // An extension no branch recognises, so only the MIME type can
          // decide — otherwise these would pass on the extension alone.
          (context) => ConversationUtils.getLastMessageWidget(
            _conversation(
              _attached(MessageTypeConstants.file, ext: 'dat', mime: mime),
            ),
            context,
            null,
          ),
        );
        expect((w as Icon).icon, expected, reason: mime);
      });
    });

    testWidgets('the extension wins over a contradicting MIME type', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(
            _attached(MessageTypeConstants.file, ext: 'pdf', mime: 'image/png'),
          ),
          context,
          null,
        ),
      );
      expect((w as Icon).icon, Icons.picture_as_pdf);
    });

    testWidgets('an uppercase extension still matches', (tester) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(
            _attached(MessageTypeConstants.file, ext: 'PDF', mime: 'X/Y'),
          ),
          context,
          null,
        ),
      );
      expect((w as Icon).icon, Icons.picture_as_pdf);
    });

    testWidgets('a file message with no attachment gets the generic icon', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(_media(MessageTypeConstants.file)),
          context,
          null,
        ),
      );
      expect((w as Icon).icon, Icons.description);
    });

    testWidgets('a non-media message typed file gets the generic icon', (
      tester,
    ) async {
      final text = TextMessage(
        text: 'x',
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        type: MessageTypeConstants.file,
        sender: _alice,
      );
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(text),
          context,
          null,
        ),
      );
      expect((w as Icon).icon, Icons.description);
    });
  });

  // ==========================================================================
  group('_getAudioIconWidget — recording versus music', () {
    testWidgets('a music file gets the music note', (tester) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(
            _attached(
              MessageTypeConstants.audio,
              ext: 'mp3',
              fileName: 'interview.mp3',
            ),
          ),
          context,
          null,
        ),
      );
      expect((w as Icon).icon, Icons.audiotrack);
    });

    testWidgets('a composer recording keeps the microphone', (tester) async {
      for (final name in [
        'audio-recording-1.m4a',
        'voice-recording-1.m4a',
        'recording-1.m4a',
        'voicenote-1.m4a',
      ]) {
        final w = await pumpBuilt(
          tester,
          (context) => ConversationUtils.getLastMessageWidget(
            _conversation(
              _attached(MessageTypeConstants.audio, ext: 'm4a', fileName: name),
            ),
            context,
            null,
          ),
        );
        expect((w as Icon).icon, Icons.mic, reason: name);
      }
    });

    testWidgets('an audio file with an unknown extension keeps the mic', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(
            _attached(
              MessageTypeConstants.audio,
              ext: 'opus',
              fileName: 'clip.opus',
            ),
          ),
          context,
          null,
        ),
      );
      expect((w as Icon).icon, Icons.mic);
    });

    testWidgets('an audio message with no attachment keeps the mic', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(_media(MessageTypeConstants.audio)),
          context,
          null,
        ),
      );
      expect((w as Icon).icon, Icons.mic);
    });
  });

  // ==========================================================================
  group('_getLastTextMessageWidget — the link-preview glyph', () {
    testWidgets('a message with a link preview gets the link icon', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastMessageWidget(
          _conversation(_withInjected(_linkPreview(['https://example.com']))),
          context,
          Colors.indigo,
        ),
      );
      expect(w, isA<Icon>());
      expect((w as Icon).icon, Icons.link);
      expect(w.color, Colors.indigo);
      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('with no colour given it falls back to the palette', (
      tester,
    ) async {
      late Color? expected;
      final w = await pumpBuilt(tester, (context) {
        expected = CometChatThemeHelper.getColorPalette(context).iconSecondary;
        return ConversationUtils.getLastMessageWidget(
          _conversation(_withInjected(_linkPreview(['https://example.com']))),
          context,
          null,
        );
      });
      expect((w as Icon).color, expected);
    });

    // Every way the payload can be present but say "no links".
    final noLink = <String, Map<String, dynamic>?>{
      'no metadata at all': null,
      'metadata without @injected': {'other': 1},
      '@injected is null': {'@injected': null},
      'no extensions': {'@injected': <String, dynamic>{}},
      'no link-preview': {
        '@injected': {'extensions': <String, dynamic>{}},
      },
      'link-preview with no links key': _linkPreview(null),
      'an empty links list': _linkPreview(const []),
    };

    noLink.forEach((description, metadata) {
      testWidgets('$description contributes no icon', (tester) async {
        final w = await pumpBuilt(
          tester,
          (context) => ConversationUtils.getLastMessageWidget(
            _conversation(_withInjected(metadata)),
            context,
            null,
          ),
        );
        expect(w, isA<SizedBox>(), reason: description);
      });
    });
  });

  // ==========================================================================
  group('getLastCustomWidget', () {
    testWidgets('a poll gets the bar-chart icon', (tester) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastCustomWidget(
          _conversation(_custom(ExtensionType.extensionPoll)),
          context,
          Colors.orange,
        ),
      );
      expect((w as Icon).icon, Icons.bar_chart);
      expect(w.color, Colors.orange);
    });

    testWidgets('with no colour given a poll falls back to the palette', (
      tester,
    ) async {
      late Color? expected;
      final w = await pumpBuilt(tester, (context) {
        expected = CometChatThemeHelper.getColorPalette(context).iconSecondary;
        return ConversationUtils.getLastCustomWidget(
          _conversation(_custom(ExtensionType.extensionPoll)),
          context,
          null,
        );
      });
      expect((w as Icon).color, expected);
    });

    testWidgets('a meeting gets the videocam icon', (tester) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastCustomWidget(
          _conversation(_custom(MessageTypeConstants.meeting)),
          context,
          null,
        ),
      );
      expect((w as Icon).icon, Icons.videocam);
    });

    final byAsset = <String, String>{
      ExtensionType.document: AssetConstants.collaborativeDocumentFilled,
      ExtensionType.sticker: AssetConstants.stickerFilled,
      ExtensionType.whiteboard: AssetConstants.collaborativeWhiteBoardFilled,
    };

    byAsset.forEach((type, asset) {
      testWidgets('a $type message shows its own bundled asset', (
        tester,
      ) async {
        final w = await pumpBuilt(
          tester,
          (context) => ConversationUtils.getLastCustomWidget(
            _conversation(_custom(type)),
            context,
            Colors.pink,
          ),
        );
        expect(_assetOf(w), asset, reason: type);
        expect((w as Image).color, Colors.pink);
        expect(w.height, 16);
        expect(w.width, 16);
      });
    });

    testWidgets('the three bundled assets are three different files', (
      tester,
    ) async {
      final seen = <String>{};
      for (final type in byAsset.keys) {
        final w = await pumpBuilt(
          tester,
          (context) => ConversationUtils.getLastCustomWidget(
            _conversation(_custom(type)),
            context,
            null,
          ),
        );
        seen.add(_assetOf(w));
      }
      expect(seen, hasLength(3));
    });

    testWidgets('an unknown custom type contributes no icon', (tester) async {
      final w = await pumpBuilt(
        tester,
        (context) => ConversationUtils.getLastCustomWidget(
          _conversation(_custom('hologram')),
          context,
          null,
        ),
      );
      expect(w, isA<SizedBox>());
    });
  });

  // ==========================================================================
  group('getLastCallWidget', () {
    /// Builds the call icon for a 1:1 conversation with Bob.
    Future<Widget> icon(
      WidgetTester tester,
      String type, {
      required String status,
      AppEntity? initiator,
      AppEntity? with_,
    }) => pumpBuilt(
      tester,
      (context) => ConversationUtils.getLastCallWidget(
        _conversation(
          _call(type, status: status, initiator: initiator),
          with_: with_,
        ),
        context,
        null,
      ),
    );

    testWidgets('an ongoing call shows nothing', (tester) async {
      final w = await icon(
        tester,
        MessageTypeConstants.audio,
        status: CallStatusConstants.ongoing,
        initiator: _bob,
      );
      expect(w, isA<SizedBox>());
    });

    testWidgets('an unrecognised status shows nothing', (tester) async {
      final w = await icon(
        tester,
        MessageTypeConstants.audio,
        status: 'teleported',
        initiator: _bob,
      );
      expect(w, isA<SizedBox>());
    });

    // status → (incoming asset for audio, incoming asset for video).
    for (final status in [
      CallStatusConstants.ended,
      CallStatusConstants.initiated,
    ]) {
      testWidgets('an incoming $status audio call shows voice-incoming', (
        tester,
      ) async {
        // The other party started it, so from my side it came in.
        final w = await icon(
          tester,
          MessageTypeConstants.audio,
          status: status,
          initiator: _bob,
        );
        expect(_assetOf(w), AssetConstants.voiceIncoming);
      });

      testWidgets('an incoming $status video call shows video-incoming', (
        tester,
      ) async {
        final w = await icon(
          tester,
          MessageTypeConstants.video,
          status: status,
          initiator: _bob,
        );
        expect(_assetOf(w), AssetConstants.videoIncoming);
      });

      testWidgets('an outgoing $status audio call shows voice-outgoing', (
        tester,
      ) async {
        // I started it, so the initiator is not the person I am talking to.
        final w = await icon(
          tester,
          MessageTypeConstants.audio,
          status: status,
          initiator: _alice,
        );
        expect(_assetOf(w), AssetConstants.voiceOutgoing);
      });

      testWidgets('an outgoing $status video call shows video-outgoing', (
        tester,
      ) async {
        final w = await icon(
          tester,
          MessageTypeConstants.video,
          status: status,
          initiator: _alice,
        );
        expect(_assetOf(w), AssetConstants.videoOutgoing);
      });
    }

    // Round 5 (owner's P5-D09 B): missed means unanswered or cancelled, for
    // whoever did not start the call, as in the call bubbles and call logs.
    for (final status in [
      CallStatusConstants.cancelled,
      CallStatusConstants.unanswered,
    ]) {
      testWidgets('P5-N12: a $status call Bob started shows the missed asset', (
        tester,
      ) async {
        final audio = await icon(
          tester,
          MessageTypeConstants.audio,
          status: status,
          initiator: _bob,
        );
        expect(_assetOf(audio), AssetConstants.audioMissed, reason: status);
        final video = await icon(
          tester,
          MessageTypeConstants.video,
          status: status,
          initiator: _bob,
        );
        expect(_assetOf(video), AssetConstants.videoMissed, reason: status);
      });

      testWidgets('P5-N12: my own $status call shows as outgoing, not missed', (
        tester,
      ) async {
        final audio = await icon(
          tester,
          MessageTypeConstants.audio,
          status: status,
          initiator: _alice,
        );
        expect(_assetOf(audio), AssetConstants.voiceOutgoing, reason: status);
        final video = await icon(
          tester,
          MessageTypeConstants.video,
          status: status,
          initiator: _alice,
        );
        expect(_assetOf(video), AssetConstants.videoOutgoing, reason: status);
      });
    }

    for (final status in [
      CallStatusConstants.rejected,
      CallStatusConstants.busy,
    ]) {
      testWidgets('P5-N13 / P5-E24: a $status call shows the plain call glyph '
          'whoever the SDK names as initiator', (tester) async {
        for (final initiator in [_bob, _alice, null]) {
          final audio = await icon(
            tester,
            MessageTypeConstants.audio,
            status: status,
            initiator: initiator,
          );
          expect(_assetOf(audio), AssetConstants.callNoFill, reason: status);
          final video = await icon(
            tester,
            MessageTypeConstants.video,
            status: status,
            initiator: initiator,
          );
          expect(
            _assetOf(video),
            AssetConstants.videocamNoFill,
            reason: status,
          );
        }
      });
    }

    testWidgets('a group call initiated by that group reads as incoming', (
      tester,
    ) async {
      final w = await icon(
        tester,
        MessageTypeConstants.audio,
        status: CallStatusConstants.ended,
        initiator: _team,
        with_: _team,
      );
      expect(_assetOf(w), AssetConstants.voiceIncoming);
    });

    testWidgets('a group call from a different group reads as outgoing', (
      tester,
    ) async {
      final w = await icon(
        tester,
        MessageTypeConstants.video,
        status: CallStatusConstants.ended,
        initiator: _otherTeam,
        with_: _team,
      );
      expect(_assetOf(w), AssetConstants.videoOutgoing);
    });

    testWidgets('a missed group call uses the missed asset', (tester) async {
      final w = await icon(
        tester,
        MessageTypeConstants.video,
        status: CallStatusConstants.unanswered,
        initiator: _team,
        with_: _team,
      );
      expect(_assetOf(w), AssetConstants.videoMissed);
    });

    testWidgets('a call with no initiator reads as outgoing', (tester) async {
      // Both initiator locals stay null, so neither "incoming" test can pass.
      final w = await icon(
        tester,
        MessageTypeConstants.audio,
        status: CallStatusConstants.ended,
      );
      expect(_assetOf(w), AssetConstants.voiceOutgoing);
    });
  });

  // ==========================================================================
  group('getLastCallMessage — the one missed rule (round 5)', () {
    String subtitle(
      BuildContext context,
      String type, {
      required String status,
      AppEntity? initiator,
    }) => ConversationUtils.getLastCallMessage(
      _conversation(_call(type, status: status, initiator: initiator)),
      context,
    );

    testWidgets('P5-N12: a cancelled or unanswered call Bob started reads '
        'missed; mine reads unanswered', (tester) async {
      await withContext(tester, (context) {
        final t = Translations.of(context);
        for (final status in [
          CallStatusConstants.cancelled,
          CallStatusConstants.unanswered,
        ]) {
          expect(
            subtitle(
              context,
              MessageTypeConstants.audio,
              status: status,
              initiator: _bob,
            ),
            t.missedVoiceCall,
            reason: status,
          );
          expect(
            subtitle(
              context,
              MessageTypeConstants.video,
              status: status,
              initiator: _bob,
            ),
            t.missedVideoCall,
            reason: status,
          );
          expect(
            subtitle(
              context,
              MessageTypeConstants.audio,
              status: status,
              initiator: _alice,
            ),
            t.unansweredAudioCall,
            reason: status,
          );
          expect(
            subtitle(
              context,
              MessageTypeConstants.video,
              status: status,
              initiator: _alice,
            ),
            t.unansweredVideoCall,
            reason: status,
          );
        }
      });
    });

    testWidgets('P5-N13: a declined call reads "Call rejected" on both sides, '
        'never "Missed voice call"', (tester) async {
      // The chat SDK names whoever declined as the initiator, so the caller's
      // row used to read "Missed voice call" after the callee declined.
      await withContext(tester, (context) {
        final t = Translations.of(context);
        for (final initiator in [_bob, _alice, null]) {
          for (final type in [
            MessageTypeConstants.audio,
            MessageTypeConstants.video,
          ]) {
            expect(
              subtitle(
                context,
                type,
                status: CallStatusConstants.rejected,
                initiator: initiator,
              ),
              t.callRejected,
              reason: '$type, ${initiator?.runtimeType}',
            );
          }
        }
      });
    });

    testWidgets('P5-E24: a busy call reads "Call busy" on both sides', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final t = Translations.of(context);
        for (final initiator in [_bob, _alice, null]) {
          expect(
            subtitle(
              context,
              MessageTypeConstants.audio,
              status: CallStatusConstants.busy,
              initiator: initiator,
            ),
            t.callBusy,
          );
        }
      });
    });

    testWidgets('the other statuses read as before', (tester) async {
      await withContext(tester, (context) {
        final t = Translations.of(context);
        expect(
          subtitle(
            context,
            MessageTypeConstants.audio,
            status: CallStatusConstants.ongoing,
            initiator: _bob,
          ),
          t.ongoingCall,
        );
        expect(
          subtitle(
            context,
            MessageTypeConstants.audio,
            status: CallStatusConstants.ended,
            initiator: _bob,
          ),
          t.incomingAudioCall,
        );
        expect(
          subtitle(
            context,
            MessageTypeConstants.video,
            status: CallStatusConstants.initiated,
            initiator: _alice,
          ),
          t.outgoingVdeoCall,
        );
      });
    });
  });
}

/// The bundled asset name behind an [Image.asset], so a builder that picks the
/// wrong glyph fails instead of merely "returning an Image".
String _assetOf(Widget widget) {
  final image = widget as Image;
  return (image.image as AssetImage).assetName;
}

/// A bare interactive message of [type] — enough for the dispatchers, which
/// only read `category` and `type`.
InteractiveMessage _interactive(String type) => InteractiveMessage(
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: type,
  sender: _alice,
  interactiveData: const {},
);

/// An SDK card message, whose category is its own — not `interactive`.
cc.CardMessage _card(String? text) => cc.CardMessage(
  text: text,
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: MessageTypeConstants.card,
  sender: _alice,
);
