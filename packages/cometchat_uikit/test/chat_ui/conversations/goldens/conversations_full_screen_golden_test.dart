import '../../../helpers/golden_config.dart';
import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Whether we're running in CI.
// ---------------------------------------------------------------------------
// Fakes
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
}

class _FakeConversation extends Fake implements Conversation {
  // Pin Conversation fields — read by the trailing view's pin glyph.
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

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

List<Conversation> _buildConversationList() => [
  _FakeConversation(
    conversationWith: _FakeUser(
      name: 'Alice Johnson',
      uid: 'alice',
      status: 'online',
    ),
    conversationId: 'c1',
    unreadMessageCount: 3,
  ),
  _FakeConversation(
    conversationWith: _FakeUser(name: 'Bob Smith', uid: 'bob'),
    conversationId: 'c2',
  ),
  _FakeConversation(
    conversationWith: _FakeGroup(
      name: 'Flutter Devs',
      type: CometChatGroupType.public,
      guid: 'flutter_devs',
    ),
    conversationId: 'c3',
    unreadMessageCount: 12,
  ),
  _FakeConversation(
    conversationWith: _FakeUser(
      name: 'Carol Williams',
      uid: 'carol',
      status: 'online',
    ),
    conversationId: 'c4',
  ),
  _FakeConversation(
    conversationWith: _FakeGroup(
      name: 'Private Team',
      type: CometChatGroupType.private,
      guid: 'private_team',
    ),
    conversationId: 'c5',
    unreadMessageCount: 1,
  ),
  _FakeConversation(
    conversationWith: _FakeUser(name: 'David Brown', uid: 'david'),
    conversationId: 'c6',
  ),
  _FakeConversation(
    conversationWith: _FakeGroup(
      name: 'Secret Channel',
      type: CometChatGroupType.password,
      guid: 'secret',
    ),
    conversationId: 'c7',
  ),
  _FakeConversation(
    conversationWith: _FakeUser(
      name: 'Eve Davis',
      uid: 'eve',
      status: 'online',
    ),
    conversationId: 'c8',
    unreadMessageCount: 42,
  ),
];

// ---------------------------------------------------------------------------
// Full-screen widget builder
// ---------------------------------------------------------------------------

Widget _fullScreenConversations({required Brightness brightness}) {
  final conversations = _buildConversationList();

  return MediaQuery(
    data: const MediaQueryData(size: Size(412, 915)),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light(),
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Chats'),
          centerTitle: false,
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
          ],
        ),
        body: ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) => CometChatConversationListItem(
            conversation: conversations[index],
            onItemClick: (_) {},
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Golden tests
// ---------------------------------------------------------------------------

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      goldenTest(
        'full screen conversations - light mode',
        fileName: 'full_screen_conversations_light',
        builder: () => GoldenTestGroup(
          scenarioConstraints: const BoxConstraints.tightFor(
            width: 412,
            height: 915,
          ),
          children: [
            GoldenTestScenario(
              name: 'light',
              child: _fullScreenConversations(brightness: Brightness.light),
            ),
          ],
        ),
      );

      goldenTest(
        'full screen conversations - dark mode',
        fileName: 'full_screen_conversations_dark',
        builder: () => GoldenTestGroup(
          scenarioConstraints: const BoxConstraints.tightFor(
            width: 412,
            height: 915,
          ),
          children: [
            GoldenTestScenario(
              name: 'dark',
              child: _fullScreenConversations(brightness: Brightness.dark),
            ),
          ],
        ),
      );
    },
  );
}
