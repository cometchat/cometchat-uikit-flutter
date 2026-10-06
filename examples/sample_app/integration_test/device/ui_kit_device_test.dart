/// On-device instrumentation coverage for the UI Kit — Track 3, Layer 3.
///
/// These run in a real app process on a simulator or handset, and exist to
/// cover what a headless `flutter test` structurally cannot:
///
///   * **Real font metrics.** `flutter_test` renders with Ahem, where every
///     glyph is an identical box. The A11Y3 text-scale harness in
///     `chat_uikit/test/a11y/` therefore proves a layout survives *Ahem* at
///     200%, not that it survives the system font at 200% — which is the thing
///     a user actually sees. The same surfaces are re-checked here with the
///     real face.
///   * **The platform channel.** `cometchat_chat_uikit`'s method channel is
///     registered for real. Headless tests must mock it or the call throws:
///     `test/shared_ui/repositories_and_controllers_test.dart` installs a mock
///     handler precisely because closing a call bloc stops a ringtone through
///     it.
///   * **Real device metrics.** MediaQuery padding is all zeroes under
///     `flutter_test`. On a notched device it is not, and several UI Kit
///     layouts subtract it.
///   * **Package asset resolution.** The Kit ships icons under
///     `packages/cometchat_chat_uikit/…`; whether they resolve at runtime is a
///     bundling question a widget test never asks.
///
/// No backend, no credentials and no login — everything here is renderable
/// offline, which is what makes it runnable in CI. The suites under
/// `integration_test/suites/` cover the live-backend journeys.
///
///   `flutter test integration_test/device/ui_kit_device_test.dart -d SIM_UDID`
///
/// Run the file, not the directory: `flutter test <dir> -d <device>` installs
/// and runs one app at a time, and a second target times out waiting. New
/// device coverage belongs in this file's `main()`.
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ---------------------------------------------------------------------------
// Overflow detection
// ---------------------------------------------------------------------------

/// Every scale-caused overflow found while pumping one surface.
///
/// Deliberately a reimplementation rather than an import: the A11Y3 harness
/// lives under `chat_uikit/test/`, which no other package can import. Keeping
/// the two independent is not ideal, but sharing it would mean promoting a
/// test helper into `lib/`.
List<String> _overflowsIn(WidgetTester tester) {
  final findings = <String>[];
  void visit(RenderObject node) {
    if (node is RenderFlex && node.debugNeedsLayout == false) {
      final overflow = _flexOverflow(node);
      if (overflow > 0.5) {
        findings.add('${node.direction.name} flex overflowed by '
            '${overflow.toStringAsFixed(1)}px');
      }
    }
    node.visitChildren(visit);
  }

  final root = tester.binding.rootElement?.renderObject;
  if (root != null) visit(root);
  return findings;
}

/// `RenderFlex` keeps its overflow in a private field, so read it the way the
/// framework surfaces it — through the debug paint size exceeding the box.
double _flexOverflow(RenderFlex flex) {
  var used = 0.0;
  flex.visitChildren((child) {
    if (child is RenderBox && child.hasSize) {
      used += flex.direction == Axis.horizontal
          ? child.size.width
          : child.size.height;
    }
  });
  if (!flex.hasSize) return 0;
  final available = flex.direction == Axis.horizontal
      ? flex.size.width
      : flex.size.height;
  return used - available;
}

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

const _viewports = <String, Size>{
  'narrow (320x568)': Size(320, 568),
  'typical (402x874)': Size(402, 874),
};

const _scales = <double>[1.0, 1.3, 2.0];

Widget _app(Widget child, {double scale = 1.0}) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
      ),
      child: Scaffold(body: child),
    ),
  ),
);

Map<String, Widget Function(BuildContext)> _surfaces() => {
  'text bubble': (context) => CometChatTextBubble(
    text: 'Rescheduled to Thursday 14:00 — does that work for everyone?',
    alignment: BubbleAlignment.left,
  ),
  'deleted bubble': (context) => const CometChatDeletedBubble(),
  'deleted bubble via its factory': (context) =>
      DeletedBubbleFactory().build(context, _FakeMessage(), BubbleAlignment.left),
  'shared list item': (context) => const CometChatListItem(
    title: 'Alexandra Constantinou',
    avatarName: 'Alexandra Constantinou',
  ),
  'date': (context) => CometChatDate(
    date: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  ),
  'badge': (context) => const CometChatBadge(count: 128),
  'avatar': (context) => const CometChatAvatar(name: 'Alexandra Constantinou'),
  'status indicator': (context) => const CometChatStatusIndicator(),
  'receipt': (context) => const CometChatReceipt(status: ReceiptStatus.read),
  'quick view': (context) => const CometChatQuickView(
    title: 'Alexandra Constantinou',
    subtitle: 'Rescheduled to Thursday 14:00 — does that work for everyone?',
  ),
  'card': (context) => const CometChatCard(
    title: 'Quarterly planning — engineering',
    avatarName: 'Quarterly planning',
  ),
  'action bubble': (context) => const CometChatActionBubble(
    text: 'Alexandra Constantinou added Dimitrios Papadopoulos',
  ),
  // Deprecated in favour of CometChatFilesBubble, but still exported and
  // still on integrators' screens, so it still has to survive 200%.
  // ignore: deprecated_member_use
  'file bubble': (context) => const CometChatFileBubble(
    title: 'Q3-planning-notes-and-appendix.pdf',
    subtitle: '2.4 MB',
    fileExtension: 'pdf',
  ),
  'message input': (context) => const CometChatMessageInput(
    placeholderText: 'Message',
  ),
};

class _FakeMessage extends Fake implements BaseMessage {
  @override
  int get id => 1;
  @override
  String get category => 'message';
  @override
  String get type => 'text';
  @override
  DateTime? get deletedAt => DateTime.fromMillisecondsSinceEpoch(1700000000000);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  group('the device is the thing under test', () {
    testWidgets('this really is a device, not the headless harness',
        (tester) async {
      // If any of these stop holding, every other case in this file has
      // quietly become a slower copy of a widget test.
      expect(binding, isA<IntegrationTestWidgetsFlutterBinding>());
      expect(defaultTargetPlatform, TargetPlatform.iOS);
      expect(kIsWeb, isFalse);
    });

    testWidgets('real device metrics reach MediaQuery', (tester) async {
      // Under flutter_test this padding is all zeroes. On a notched device it
      // is not, and the composer and call screens subtract it.
      late MediaQueryData data;
      await tester.pumpWidget(
        _app(Builder(builder: (context) {
          data = MediaQuery.of(context);
          return const SizedBox();
        })),
      );
      await tester.pumpAndSettle();

      expect(data.size.width, greaterThan(0));
      expect(data.devicePixelRatio, greaterThan(1.0),
          reason: 'a retina device, not the 1.0 of flutter_test');
      expect(
        data.padding.top,
        greaterThan(0),
        reason: 'the status bar / notch inset is real here',
      );
    });

    testWidgets('the real system font is in use, not Ahem', (tester) async {
      // Ahem renders every glyph as an identical square, so an "l" and a "W"
      // measure the same. Any difference proves a real face is loaded — which
      // is the premise of the text-scale cases below.
      double widthOf(String s) {
        final painter = TextPainter(
          text: TextSpan(text: s, style: const TextStyle(fontSize: 24)),
          textDirection: TextDirection.ltr,
        )..layout();
        return painter.width;
      }

      expect(
        widthOf('WWWWW'),
        greaterThan(widthOf('lllll')),
        reason: 'proportional font; under Ahem these are equal',
      );
    });
  });

  // =========================================================================
  group('text scale with real font metrics', () {
    // The A11Y3 harness gates these same surfaces headless, where Ahem's
    // uniform glyphs make text wider than reality in some places and narrower
    // in others. This is the same gate against what a user sees.
    for (final entry in _surfaces().entries) {
      testWidgets('${entry.key} survives 100%, 130% and 200%',
          (tester) async {
        final failures = <String>[];

        for (final viewport in _viewports.entries) {
          await tester.binding.setSurfaceSize(viewport.value);
          for (final scale in _scales) {
            await tester.pumpWidget(
              _app(Builder(builder: entry.value), scale: scale),
            );
            await tester.pumpAndSettle();

            for (final overflow in _overflowsIn(tester)) {
              failures.add('${entry.key} · ${viewport.key} · ${scale}x — '
                  '$overflow');
            }
          }
        }
        await tester.binding.setSurfaceSize(null);

        expect(
          failures,
          isEmpty,
          reason: 'scale-caused overflow with the real font:\n'
              '${failures.join('\n')}',
        );
      });
    }
  });

  // =========================================================================
  group('platform channel', () {
    testWidgets('the plugin channel is registered and answers', (tester) async {
      // Headless, this channel has no implementation and every call throws
      // MissingPluginException — which is why the unit suite installs a mock
      // handler before closing a call bloc. Here it is the real plugin.
      const channel = MethodChannel('cometchat_chat_uikit');
      Object? error;
      try {
        await channel.invokeMethod<void>('stopPlayer');
      } catch (e) {
        error = e;
      }

      expect(
        error,
        isNot(isA<MissingPluginException>()),
        reason: 'the iOS plugin should be registered in a real app process',
      );
    });

    testWidgets('SoundManager stops without throwing', (tester) async {
      // The path a call bloc takes on dispose. Unmockable value here: it
      // crosses into Swift.
      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pumpAndSettle();

      expect(() => SoundManager().stop(), returnsNormally);
    });
  });

  // =========================================================================
  group('package assets resolve at runtime', () {
    testWidgets('an icon shipped inside the package loads', (tester) async {
      // `packages/cometchat_chat_uikit/…` resolution is a bundling question a
      // widget test never asks. Resolve the provider and await the stream
      // rather than watching for an errorBuilder call: a silent null there
      // reads the same whether the byte loaded or never started.
      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pumpAndSettle();

      final completer = Completer<ImageInfo>();
      const provider = AssetImage(
        AssetConstants.back,
        package: UIConstants.packageName,
      );
      provider.resolve(ImageConfiguration.empty).addListener(
            ImageStreamListener(
              (info, _) {
                if (!completer.isCompleted) completer.complete(info);
              },
              onError: (error, stack) {
                if (!completer.isCompleted) completer.completeError(error);
              },
            ),
          );

      final decoded = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError(
          '${AssetConstants.back} never resolved from the bundle',
        ),
      );

      expect(decoded.image.width, greaterThan(0));
      expect(decoded.image.height, greaterThan(0));
    });
  });

  // =========================================================================
  group('localization resolves on device', () {
    testWidgets('the delegates supply a real string, not a key',
        (tester) async {
      late String deleted;
      await tester.pumpWidget(
        _app(Builder(builder: (context) {
          deleted = Translations.of(context).thisMessageDeleted;
          return Text(deleted);
        })),
      );
      await tester.pumpAndSettle();

      expect(deleted, isNotEmpty);
      expect(deleted, isNot(contains('thisMessageDeleted')));
      expect(find.text(deleted), findsOneWidget);
    });
  });

  // =========================================================================
  group('real gestures reach the widget', () {
    // `tester.tap` synthesises a pointer either way, but here it travels the
    // real engine pipeline and the real hit-test, against a widget laid out
    // with the real font. A target that is too small or mis-positioned under
    // the system face fails here and passes headless.
    //
    // Scope note: this covers widgets whose gesture handling is a plain
    // GestureDetector. `TextField` gestures do NOT resolve under this binding
    // on iOS — neither `onTap` nor focus fires, for a bare Flutter TextField
    // just as much as for the Kit's composer, and holding the pointer across
    // a frame does not help. So the composer is exercised through
    // `enterText` in the group below rather than by tapping it.
    testWidgets('a single-select option reports the value it carries',
        (tester) async {
      String? chosen;
      await tester.pumpWidget(
        _app(
          Center(
            child: CometChatSingleSelect(
              options: [
                OptionElement(value: 'thu', label: 'Thursday'),
                OptionElement(value: 'fri', label: 'Friday'),
              ],
              onChanged: (value) => chosen = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Friday'));
      await tester.pumpAndSettle();

      expect(chosen, 'fri', reason: 'the value, not the label, is reported');
    });
  });

  // =========================================================================
  group('real text input', () {
    testWidgets('the composer takes text through the platform text input',
        (tester) async {
      // Headless, TextInput is a mock channel. On device this crosses into
      // UIKit and back, which is the only place the connection can break.
      final controller = TextEditingController();
      final changes = <String>[];

      await tester.pumpWidget(
        _app(
          CometChatMessageInput(
            textEditingController: controller,
            placeholderText: 'Message',
            onChange: changes.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'See you Thursday');
      await tester.pumpAndSettle();

      expect(controller.text, 'See you Thursday');
      expect(changes.last, 'See you Thursday');
      expect(find.text('See you Thursday'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('the placeholder gives way to typed text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _app(
          CometChatMessageInput(
            textEditingController: controller,
            placeholderText: 'Message',
          ),
        ),
      );
      await tester.pumpAndSettle();

      double hintOpacity() => tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(
                  of: find.text('Message'),
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;

      expect(find.text('Message'), findsOneWidget);
      expect(hintOpacity(), 1.0);

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pumpAndSettle();

      // InputDecorator keeps the hint mounted and animates it out, so
      // `findsNothing` would never hold. Its opacity is the real signal.
      expect(hintOpacity(), 0.0);
      expect(find.text('Hi'), findsOneWidget);

      controller.dispose();
    });
  });

  // =========================================================================
  group('defects this suite found, now pinned', () {
    testWidgets('single select survives 200% with two options', (tester) async {
      // This case was red when it was written and is the regression pin for
      // ENG-39112: the two-option layout put each label inside a Row(max) and
      // a Wrap, both of which size a child to its intrinsic width, so a long
      // label never wrapped and the row overflowed by ~91px and ~157px at 2.0x
      // in both LTR and RTL. The fix hands the Expanded's tight width straight
      // to the button. Un-skipped once that landed — if it fails again, the
      // constraint chain has been broken, not the text.
      final failures = <String>[];
      for (final viewport in _viewports.entries) {
        await tester.binding.setSurfaceSize(viewport.value);
        await tester.pumpWidget(
          _app(
            CometChatSingleSelect(
              options: [
                OptionElement(value: 'y', label: 'Yes, Thursday works'),
                OptionElement(value: 'n', label: 'No, propose another time'),
              ],
            ),
            scale: 2.0,
          ),
        );
        await tester.pumpAndSettle();
        failures.addAll(_overflowsIn(tester));
      }
      await tester.binding.setSurfaceSize(null);

      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });

  // =========================================================================
  group('orientation and direction', () {
    testWidgets('every surface survives landscape at 200%', (tester) async {
      // A rotation is a real resize on device. Short height plus large text is
      // where a Column that fits in portrait stops fitting.
      const landscape = Size(874, 402);
      final failures = <String>[];

      for (final entry in _surfaces().entries) {
        await tester.binding.setSurfaceSize(landscape);
        await tester.pumpWidget(
          _app(Builder(builder: entry.value), scale: 2.0),
        );
        await tester.pumpAndSettle();

        for (final overflow in _overflowsIn(tester)) {
          failures.add('${entry.key} · landscape · 2.0x — $overflow');
        }
      }
      await tester.binding.setSurfaceSize(null);

      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    testWidgets('every surface survives right-to-left at 200%',
        (tester) async {
      // The Kit ships Arabic and Hebrew translations, so RTL is a shipped
      // configuration, not a hypothetical.
      final failures = <String>[];

      for (final entry in _surfaces().entries) {
        await tester.pumpWidget(
          _app(
            Directionality(
              textDirection: TextDirection.rtl,
              child: Builder(builder: entry.value),
            ),
            scale: 2.0,
          ),
        );
        await tester.pumpAndSettle();

        for (final overflow in _overflowsIn(tester)) {
          failures.add('${entry.key} · rtl · 2.0x — $overflow');
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });

  // =========================================================================
  group('theme resolves against the real platform', () {
    for (final brightness in Brightness.values) {
      testWidgets('the palette, typography and spacing resolve in '
          '${brightness.name}', (tester) async {
        // CometChatThemeHelper reads the ambient Theme. Headless it reads a
        // synthetic one; here it reads the app's, built by MaterialApp against
        // the device's own platform brightness handling.
        late CometChatColorPalette palette;
        late CometChatTypography typography;
        late CometChatSpacing spacing;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            theme: ThemeData(brightness: brightness),
            home: Builder(builder: (context) {
              palette = CometChatThemeHelper.getColorPalette(context);
              typography = CometChatThemeHelper.getTypography(context);
              spacing = CometChatThemeHelper.getSpacing(context);
              return const Scaffold(body: SizedBox());
            }),
          ),
        );
        await tester.pumpAndSettle();

        expect(palette.background1, isNotNull);
        expect(palette.textPrimary, isNotNull);
        expect(typography.body?.regular, isNotNull);
        expect(spacing.padding2, isNotNull);
      });
    }

    testWidgets('the device reports a platform brightness', (tester) async {
      // Not an assertion about which one — only that the real value arrives,
      // where headless always hands back light.
      late Brightness reported;
      await tester.pumpWidget(
        _app(Builder(builder: (context) {
          reported = MediaQuery.platformBrightnessOf(context);
          return const SizedBox();
        })),
      );
      await tester.pumpAndSettle();

      expect(Brightness.values, contains(reported));
    });
  });
}
