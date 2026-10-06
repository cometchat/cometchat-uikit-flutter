import '../../../helpers/golden_config.dart';
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// Whether we're running in CI (GitHub Actions sets CI=true).
/// When true, skip platform-specific golden variants (Linux/macOS/Windows)
/// and only run the CI variant (Ahem font, platform-agnostic).
// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------
//
// We deliberately build fakes with `lastMessage == null` so that the widget's
// subtitle-formatter / moderation / mentions chain is not exercised. Those
// chains reach deep into production infrastructure (CometChatMentionsFormatter,
// ModerationCheckUtil, CometChatUIKit.loggedInUser, etc.) and pulling all of
// them into a unit-level golden test would make the tests brittle. The visual
// states we *do* want to pin (avatar layout, title, status/group indicators,
// unread badge, selection checkbox) are all independent of last-message content.

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
// Harness
// ---------------------------------------------------------------------------

Widget _row(Widget child) => SizedBox(
  width: 375,
  height: 80,
  child: Material(color: const Color(0xFFFFFFFF), child: child),
);

Widget _themedRow({required Brightness brightness, required Widget item}) {
  return MediaQuery(
    data: MediaQueryData(platformBrightness: brightness),
    child: Theme(
      data: brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light(),
      // Wrap in Directionality so list-item Row layouts work outside MaterialApp.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: _row(item),
      ),
    ),
  );
}

Widget _buildItem(
  Conversation conv, {
  bool isSelected = false,
  SelectionMode selectionMode = SelectionMode.none,
}) {
  return CometChatConversationListItem(
    conversation: conv,
    onItemClick: (_) {},
    isSelected: isSelected,
    selectionMode: selectionMode,
  );
}

// ---------------------------------------------------------------------------
// Variant factories
// ---------------------------------------------------------------------------

Conversation _userReadConv() => _FakeConversation(
  conversationWith: _FakeUser(name: 'Alice', uid: 'alice'),
  conversationId: 'user_alice',
);

Conversation _userUnreadConv() => _FakeConversation(
  conversationWith: _FakeUser(name: 'Bob', uid: 'bob'),
  conversationId: 'user_bob',
  unreadMessageCount: 3,
);

Conversation _userUnreadManyConv() => _FakeConversation(
  conversationWith: _FakeUser(name: 'Beatrice', uid: 'beatrice'),
  conversationId: 'user_beatrice',
  unreadMessageCount: 99,
);

Conversation _userOnlineConv() => _FakeConversation(
  conversationWith: _FakeUser(name: 'Carol', uid: 'carol', status: 'online'),
  conversationId: 'user_carol',
);

Conversation _groupPublicConv() => _FakeConversation(
  conversationWith: _FakeGroup(
    name: 'Public Room',
    type: CometChatGroupType.public,
    guid: 'public_room',
  ),
  conversationId: 'group_public',
);

Conversation _groupPrivateConv() => _FakeConversation(
  conversationWith: _FakeGroup(
    name: 'Private Room',
    type: CometChatGroupType.private,
    guid: 'private_room',
  ),
  conversationId: 'group_private',
);

Conversation _groupPasswordConv() => _FakeConversation(
  conversationWith: _FakeGroup(
    name: 'Protected Room',
    type: CometChatGroupType.password,
    guid: 'protected_room',
  ),
  conversationId: 'group_password',
);

// ---------------------------------------------------------------------------
// Goldens — 8 variants × (light + dark) = 16 scenarios in 8 PNGs.
// ---------------------------------------------------------------------------

void main() {
  // In CI, disable platform-specific golden variants (Linux/Windows).
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      _variantGolden(
        'list_item_user_read',
        convBuilder: _userReadConv,
        description: '1-1 user conversation, read (no unread badge)',
      );
      _variantGolden(
        'list_item_user_unread',
        convBuilder: _userUnreadConv,
        description: '1-1 user conversation with unread badge (count 3)',
      );
      _variantGolden(
        'list_item_user_unread_many',
        convBuilder: _userUnreadManyConv,
        description: '1-1 user conversation with multi-digit unread badge',
      );
      _variantGolden(
        'list_item_user_online',
        convBuilder: _userOnlineConv,
        description: '1-1 user conversation, online status indicator',
      );
      _variantGolden(
        'list_item_group_public',
        convBuilder: _groupPublicConv,
        description: 'group conversation, public (no indicator)',
      );
      _variantGolden(
        'list_item_group_private',
        convBuilder: _groupPrivateConv,
        description: 'group conversation, private (shield indicator)',
      );
      _variantGolden(
        'list_item_group_password',
        convBuilder: _groupPasswordConv,
        description: 'group conversation, password-protected (lock indicator)',
      );
      _variantGolden(
        'list_item_user_selected',
        convBuilder: _userReadConv,
        description: '1-1 user conversation in multi-select, checked',
        isSelected: true,
        selectionMode: SelectionMode.multiple,
      );
    }, // end run
  ); // end AlchemistConfig.runWithConfig
}

void _variantGolden(
  String fileName, {
  required Conversation Function() convBuilder,
  required String description,
  bool isSelected = false,
  SelectionMode selectionMode = SelectionMode.none,
}) {
  goldenTest(
    description,
    fileName: fileName,
    builder: () => Localizations(
      locale: const Locale('en'),
      delegates: Translations.localizationsDelegates,
      child: GoldenTestGroup(
        scenarioConstraints: const BoxConstraints.tightFor(
          width: 375,
          height: 80,
        ),
        children: [
          GoldenTestScenario(
            name: 'light',
            child: _themedRow(
              brightness: Brightness.light,
              item: _buildItem(
                convBuilder(),
                isSelected: isSelected,
                selectionMode: selectionMode,
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'dark',
            child: _themedRow(
              brightness: Brightness.dark,
              item: _buildItem(
                convBuilder(),
                isSelected: isSelected,
                selectionMode: selectionMode,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
