import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_helper.dart';

/// STRICT navigation for the iOS-parity suites (E2E-160 … E2E-199).
///
/// `NavigationHelper` is tolerant on purpose: when it cannot find what it was
/// asked to open it opens the first row instead, or does nothing. That is how a
/// suite ends up asserting on the wrong conversation and still going green.
/// Everything here `fail()`s with the reason instead, so a test that reaches
/// its assertion is known to be standing on the screen it names.
///
/// Every finder below is traceable to the source file cited beside it.
class ScreenReach {
  ScreenReach._();

  // ─── Tabs ─────────────────────────────────────────────────────────────────

  /// Switch bottom tab. Labels come from `master_app/lib/screens/
  /// home_screen.dart` (`BottomNavigationBarItem.label`): Chats, Calls, Users,
  /// Groups, Notifications.
  static Future<void> goToTab(WidgetTester tester, String label) async {
    final inNavBar = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(label),
    );
    if (!await pumpUntilFound(tester, inNavBar)) {
      fail(
        'Bottom tab "$label" is not on screen — the app is not on '
        'HomeScreen (login failed, or a route is still covering it).',
      );
    }
    await tester.tap(inNavBar.first);
    await pumpFor(tester, const Duration(seconds: 2));
  }

  // ─── Conversations ────────────────────────────────────────────────────────

  /// The conversation row for [name], scoped to the conversations list so a
  /// same-named Text elsewhere (app bar, another tab kept alive by the
  /// IndexedStack) can never be the thing that gets tapped.
  ///
  /// `CometChatConversationListItem` renders the title as a plain `Text`
  /// (chat_uikit/lib/chat_ui/src/conversations/widgets/
  /// cometchat_conversation_list_item.dart, `_getConversationTitle`).
  static Finder conversationRowNamed(String name) => find.ancestor(
    of: find.text(name),
    matching: find.byType(CometChatConversationListItem),
  );

  /// The conversation row whose peer is the user [uid] — matched on the model
  /// the row was built from, not on rendered text.
  static Finder conversationRowForUser(String uid) =>
      find.byWidgetPredicate((w) {
        if (w is! CometChatConversationListItem) return false;
        final peer = w.conversation.conversationWith;
        return peer is User && peer.uid == uid;
      });

  /// Open the conversation called [name] from the Chats tab, or fail.
  static Future<void> openConversationNamed(
    WidgetTester tester,
    String name, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await goToTab(tester, 'Chats');
    final row = conversationRowNamed(name);
    if (!await pumpUntilFound(tester, row, timeout: timeout)) {
      fail(
        'No conversation row named "$name" appeared in the Chats list '
        'within ${timeout.inSeconds}s. The fixture that should have put it '
        'there (a seeded message) did not land, or the list did not load.',
      );
    }
    await tester.tap(row.first);
    // CometChatMessageComposer is the one widget only a messages screen has.
    if (!await pumpUntilFound(
      tester,
      find.byType(CometChatMessageComposer),
      timeout: const Duration(seconds: 15),
    )) {
      fail('Tapping the "$name" conversation did not open a messages screen.');
    }
    await pumpFor(tester, const Duration(seconds: 2));
  }

  /// Leave the current pushed route through its own back affordance.
  ///
  /// The message header, the pinned list and the saved list all label their
  /// back button with `Translations.back` = 'Back'
  /// (chat_uikit/lib/shared_ui/l10n/translations_en.dart).
  static Future<void> goBack(WidgetTester tester) async {
    final back = find.byTooltip('Back');
    if (back.evaluate().isEmpty) {
      fail('No "Back" button on screen to leave the current route with.');
    }
    await tester.tap(back.first);
    await pumpFor(tester, const Duration(seconds: 2));
  }

  // ─── Message header ⋯ menu ────────────────────────────────────────────────

  /// Open the header's ⋯ overflow menu and choose [entry].
  ///
  /// The button is an `IconButton(tooltip: Translations.more)` = 'More' inside
  /// a `MenuAnchor`; entries are `MenuItemButton`s whose child is
  /// `Text(entry.label)` — 'Search', 'Pinned Messages', 'User Info' /
  /// 'Group Info' (chat_uikit/lib/chat_ui/src/message_header/
  /// cometchat_message_header.dart, `_buildOverflowMenu`).
  static Future<void> chooseHeaderMenuEntry(
    WidgetTester tester,
    String entry,
  ) async {
    final more = find.descendant(
      of: find.byType(CometChatMessageHeader),
      matching: find.byTooltip('More'),
    );
    if (!await pumpUntilFound(tester, more)) {
      fail(
        'The message header has no ⋯ (More) menu. It renders only when '
        'pinned messages are enabled or the host passes onInfoTap / '
        'onSearchTap.',
      );
    }
    await tester.tap(more.first);
    final item = find.widgetWithText(MenuItemButton, entry);
    if (!await pumpUntilFound(
      tester,
      item,
      timeout: const Duration(seconds: 5),
    )) {
      fail('The header ⋯ menu has no "$entry" entry.');
    }
    await tester.tap(item.first);
    await pumpFor(tester, const Duration(seconds: 2));
  }

  /// Header ⋯ → Pinned Messages; waits for the pinned screen to finish its
  /// fetch (its body is a bare `CircularProgressIndicator` while `_loading`).
  static Future<void> openPinnedMessages(WidgetTester tester) async {
    await chooseHeaderMenuEntry(tester, 'Pinned Messages');
    final screen = find.byType(CometChatPinnedMessages);
    if (!await pumpUntilFound(tester, screen)) {
      fail('Choosing "Pinned Messages" did not open CometChatPinnedMessages.');
    }
    final spinner = find.descendant(
      of: screen,
      matching: find.byType(CircularProgressIndicator),
    );
    if (!await pumpUntilGone(
      tester,
      spinner,
      timeout: const Duration(seconds: 20),
    )) {
      fail('The pinned-messages screen never left its loading state.');
    }
  }

  /// Profile avatar menu → 'Saved Messages'
  /// (master_app/lib/screens/home_screen.dart, `_buildProfileMenu`: a
  /// `PopupMenuButton<String>` whose '/saved' item is `Text('Saved Messages')`).
  static Future<void> openSavedMessages(WidgetTester tester) async {
    final menu = find.byType(PopupMenuButton<String>);
    if (!await pumpUntilFound(tester, menu)) {
      fail('The HomeScreen profile menu is not on screen.');
    }
    await tester.tap(menu.first);
    // Tapped before the saved screen exists, so its same-worded title cannot
    // be what matches.
    final item = find.text('Saved Messages');
    if (!await pumpUntilFound(
      tester,
      item,
      timeout: const Duration(seconds: 5),
    )) {
      fail('The profile menu has no "Saved Messages" item.');
    }
    await tester.tap(item.first);
    final screen = find.byType(CometChatSavedMessages);
    if (!await pumpUntilFound(tester, screen)) {
      fail('Choosing "Saved Messages" did not open CometChatSavedMessages.');
    }
    final spinner = find.descendant(
      of: screen,
      matching: find.byType(CircularProgressIndicator),
    );
    if (!await pumpUntilGone(
      tester,
      spinner,
      timeout: const Duration(seconds: 20),
    )) {
      fail('The saved-messages screen never left its loading state.');
    }
  }

  // ─── Long-press options ───────────────────────────────────────────────────

  /// The long-press options overlay.
  ///
  /// `CometChatMessageActionOverlay` (chat_uikit/lib/chat_ui/src/message_list/
  /// widgets/cometchat_message_action_overlay.dart) is not exported from the
  /// package barrel, so it is matched by runtime type name rather than by an
  /// `implementation_imports` reach into `src/`.
  static Finder get messageOptionsOverlay => find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == 'CometChatMessageActionOverlay',
    description: 'CometChatMessageActionOverlay',
  );

  /// Long-press [messageText] and wait for the options overlay.
  static Future<void> openMessageOptions(
    WidgetTester tester,
    String messageText,
  ) async {
    final center = centerOfText(
      tester,
      messageText,
      within: find.byType(CometChatMessageList),
    );
    if (center == null) {
      fail(
        'Message "$messageText" is not laid out in the message list, so it '
        'cannot be long-pressed.',
      );
    }
    await tester.longPressAt(center);
    if (!await pumpUntilFound(
      tester,
      messageOptionsOverlay,
      timeout: const Duration(seconds: 5),
    )) {
      fail('Long-pressing "$messageText" did not open the options overlay.');
    }
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  /// Long-press [messageText] and choose an option from the overlay's SECOND
  /// page.
  ///
  /// The overlay is two pages. Reply / Reply in thread / Copy / Edit / Delete
  /// are on the first; everything else — Save, Pin, Info, Share, Mark as
  /// unread — is behind the 'More' row
  /// (chat_uikit/lib/chat_ui/src/message_list/widgets/
  /// cometchat_message_action_overlay.dart, `_primaryActionOrder`). Looking
  /// for 'Info' on the first page, as 1TO1-079 does, can never find it.
  static Future<void> chooseMoreOption(
    WidgetTester tester,
    String messageText,
    String optionTitle,
  ) async {
    await openMessageOptions(tester, messageText);
    final overlay = messageOptionsOverlay;
    final more = find.descendant(of: overlay, matching: find.text('More'));
    if (more.evaluate().isEmpty) {
      fail(
        'The options overlay for "$messageText" has no "More" row, so it '
        'offers no second-page options at all ("$optionTitle" included).',
      );
    }
    await tester.tap(more.first);
    await pumpFor(tester, const Duration(milliseconds: 600));
    final option = find.descendant(
      of: overlay,
      matching: find.text(optionTitle),
    );
    if (option.evaluate().isEmpty) {
      fail(
        'The "More" page of the options overlay does not offer '
        '"$optionTitle" for "$messageText".',
      );
    }
    await tester.tap(option.first);
    await pumpFor(tester, const Duration(seconds: 1));
  }

  // ─── Scoped text lookups ──────────────────────────────────────────────────

  /// Whether [text] is rendered (as `Text` or `RichText`) somewhere under
  /// [scope]. Message bubbles are sliver-built `RichText`, which `find.text`
  /// does not match, so this walks the element tree — but only under [scope],
  /// so "the pinned list shows X" cannot be satisfied by the message list
  /// underneath it showing X.
  static bool textWithin(WidgetTester tester, Finder scope, String text) {
    for (final root in scope.evaluate()) {
      if (_elementContaining(root, text) != null) return true;
    }
    return false;
  }

  /// Poll [textWithin] until true or [timeout].
  static Future<bool> waitForTextWithin(
    WidgetTester tester,
    Finder scope,
    String text, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (textWithin(tester, scope, text)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return textWithin(tester, scope, text);
  }

  /// Poll until [text] is no longer rendered under [scope].
  static Future<bool> waitForTextGoneWithin(
    WidgetTester tester,
    Finder scope,
    String text, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (!textWithin(tester, scope, text)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return !textWithin(tester, scope, text);
  }

  /// Global centre of the first render box under [within] that renders [text],
  /// or null when it is not laid out.
  static Offset? centerOfText(
    WidgetTester tester,
    String text, {
    required Finder within,
  }) {
    final rect = rectOfText(tester, text, within: within);
    return rect?.center;
  }

  /// Global rect of the first render box under [within] that renders [text].
  static Rect? rectOfText(
    WidgetTester tester,
    String text, {
    required Finder within,
  }) {
    for (final root in within.evaluate()) {
      final hit = _elementContaining(root, text);
      final box = hit?.renderObject;
      if (box is RenderBox && box.hasSize && box.attached) {
        return box.localToGlobal(Offset.zero) & box.size;
      }
    }
    return null;
  }

  /// Every plain `Text` string inside the nearest enclosing [T] of the widget
  /// that renders [text] under [within] — e.g. all captions of the
  /// `CometChatMessageBubble` that holds a given message. Null when [text] is
  /// not rendered or has no [T] ancestor.
  static List<String>? textsInEnclosing<T extends Widget>(
    WidgetTester tester,
    String text, {
    required Finder within,
  }) {
    for (final root in within.evaluate()) {
      final hit = _elementContaining(root, text);
      if (hit == null) continue;
      Element? enclosing;
      hit.visitAncestorElements((a) {
        if (a.widget is T) {
          enclosing = a;
          return false;
        }
        return true;
      });
      if (enclosing == null) return null;
      final out = <String>[];
      void walk(Element el) {
        final w = el.widget;
        if (w is Text && w.data != null) out.add(w.data!);
        el.visitChildren(walk);
      }

      walk(enclosing!);
      return out;
    }
    return null;
  }

  static Element? _elementContaining(Element root, String text) {
    Element? found;
    void walk(Element el) {
      if (found != null) return;
      final w = el.widget;
      if (w is RichText) {
        if (w.text.toPlainText().contains(text)) {
          found = el;
          return;
        }
      } else if (w is Text) {
        final plain = w.data ?? w.textSpan?.toPlainText() ?? '';
        if (plain.contains(text)) {
          found = el;
          return;
        }
      }
      el.visitChildren(walk);
    }

    walk(root);
    return found;
  }
}
