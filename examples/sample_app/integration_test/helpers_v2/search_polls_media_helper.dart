import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../config/test_credentials.dart';
import 'pump_helper.dart';

/// Strict finders and SDK probes shared by the search / polls / media-viewer
/// suites (E2E-130 … E2E-159).
///
/// Everything here is traceable to a widget, Semantics label or string read in
/// `chat_uikit/lib` — the source file is cited next to each finder. Nothing in
/// this file degrades to "the screen is still alive": callers get a real
/// finder, or a thrown error.
class KitFinders {
  KitFinders._();

  /// A `Semantics` *widget* whose label is exactly [label].
  ///
  /// Deliberately not `find.bySemanticsLabel`: that one reads the semantics
  /// *tree*, which is only built when semantics are enabled on the device, so
  /// it silently finds nothing on a plain `flutter test -d <device>` run. The
  /// widget is always in the element tree.
  static Finder semanticsLabel(String label, {bool skipOffstage = true}) {
    return find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
      skipOffstage: skipOffstage,
    );
  }

  /// A `Semantics` widget whose label starts with [prefix].
  static Finder semanticsLabelStartsWith(
    String prefix, {
    bool skipOffstage = true,
  }) {
    return find.byWidgetPredicate(
      (w) => w is Semantics && (w.properties.label ?? '').startsWith(prefix),
      skipOffstage: skipOffstage,
    );
  }

  /// Any `RichText` (every `Text` builds one) whose plain text contains
  /// [text].
  static Finder richTextContaining(String text, {bool skipOffstage = true}) {
    return find.byWidgetPredicate((w) {
      if (w is! RichText) return false;
      try {
        return w.text.toPlainText().contains(text);
      } catch (_) {
        return false;
      }
    }, skipOffstage: skipOffstage);
  }

  /// A `TextField` whose `InputDecoration.hintText` is exactly [hint].
  static Finder textFieldWithHint(String hint) {
    return find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == hint,
    );
  }

  // ─── Composer: attachment overlay ─────────────────────────────────────────

  /// The composer's "+" button.
  /// Source: message_composer_secondary_buttons.dart — `_buildAttachmentButton`
  /// wraps the icon in `Semantics(label: 'Add attachment', button: true)`.
  static Finder attachmentButton() => semanticsLabel('Add attachment');

  /// The open attachment popup.
  /// Source: attachment_options_overlay.dart — the popup body is wrapped in
  /// `Semantics(label: 'Attachment options menu opened')`.
  static Finder attachmentOverlay() =>
      semanticsLabel('Attachment options menu opened');

  /// One row of the open attachment popup, by its visible title.
  /// Source: attachment_options_overlay.dart `_buildActionItem` — each row is
  /// an `InkWell` holding `Text(item.title)`.
  static Finder attachmentOption(String title) {
    return find.descendant(
      of: attachmentOverlay(),
      matching: find.widgetWithText(InkWell, title),
    );
  }

  /// Tap the composer "+" and wait for the popup. Fails the test when the
  /// button is missing or the popup never opens.
  static Future<void> openAttachmentOverlay(WidgetTester tester) async {
    final button = attachmentButton();
    expect(
      button,
      findsOneWidget,
      reason: 'composer must expose the "Add attachment" button',
    );
    await tester.tap(button);
    final opened = await pumpUntilFound(
      tester,
      attachmentOverlay(),
      timeout: const Duration(seconds: 5),
    );
    expect(
      opened,
      isTrue,
      reason: 'tapping "Add attachment" must open the attachment popup',
    );
    // Let the spring-open animation (attachment_options_overlay.dart
    // `_runSpringOpen`) finish so rows are at their final, tappable position.
    await pumpFor(tester, const Duration(seconds: 1));
  }

  // ─── Text input hygiene ───────────────────────────────────────────────────

  /// Drop keyboard focus so the FocusTrap overlay cannot swallow the next tap
  /// (see README §4 "FocusTrap / AbsorbPointer").
  static Future<void> dropFocus(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// In-process CometChat SDK reads, made as the logged-in User A.
///
/// The app under test and the test body share one isolate, so once
/// `AppLauncher.launchAndLogin` has returned the SDK is initialised and these
/// calls hit the real backend. They are used for two things the REST harness
/// cannot do reliably:
///   * asking the server which extensions are enabled for the app, and
///   * reading back the message that actually went out after a UI action.
class SdkProbe {
  SdkProbe._();

  /// Whether extension [slug] is enabled on the app under test.
  ///
  /// `CometChat.isExtensionEnabled` returns `false` both for "disabled" and for
  /// "could not tell" (it swallows the error into `onError`). Those must not be
  /// confused — the first is a legitimate skip, the second is a broken run —
  /// so a lookup error is rethrown.
  static Future<bool> isExtensionEnabled(String slug) async {
    CometChatException? failure;
    final enabled = await CometChat.isExtensionEnabled(
      slug,
      onError: (e) => failure = e,
    );
    if (failure != null) {
      throw StateError(
        'Could not determine whether the "$slug" extension is enabled: '
        '${failure!.code} ${failure!.message}',
      );
    }
    return enabled;
  }

  /// The latest [limit] messages of the A↔B conversation, oldest first, as the
  /// server returns them to User A. Throws when the fetch fails.
  ///
  /// Same request shape `SearchBloc._buildMessagesRequest` uses
  /// (`MessagesRequestBuilder` + `fetchPrevious`).
  static Future<List<BaseMessage>> latestMessagesWithUserB({
    List<String>? categories,
    List<String>? types,
    int limit = 30,
  }) async {
    final builder = MessagesRequestBuilder()
      ..uid = TestCredentials.userBUid
      ..limit = limit;
    if (categories != null) builder.categories = categories;
    if (types != null) builder.types = types;

    final completer = Completer<List<BaseMessage>>();
    unawaited(
      builder.build().fetchPrevious(
        onSuccess: (List<BaseMessage> messages) {
          if (!completer.isCompleted) completer.complete(messages);
        },
        onError: (CometChatException e) {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError('fetchPrevious failed: ${e.code} ${e.message}'),
            );
          }
        },
      ),
    );
    return completer.future.timeout(const Duration(seconds: 20));
  }

  /// Poll [latestMessagesWithUserB] until a custom message of [type] sent by
  /// User A satisfies [where], and return it. Fails the test on timeout — a
  /// UI action that produced no server-side message is a broken feature.
  static Future<CustomMessage> waitForCustomMessageFromA({
    required String type,
    required bool Function(CustomMessage message) where,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (true) {
      final messages = await latestMessagesWithUserB(
        categories: [MessageCategoryConstants.custom],
        types: [type],
      );
      for (final m in messages.reversed) {
        if (m is CustomMessage &&
            m.sender?.uid == TestCredentials.userAUid &&
            where(m)) {
          return m;
        }
      }
      if (DateTime.now().isAfter(end)) {
        fail(
          'No "$type" custom message from User A matched on the server '
          'within ${timeout.inSeconds}s',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
}
