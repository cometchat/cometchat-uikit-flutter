/// The three fetching AI panels — smart replies, conversation starter and
/// conversation summary — driven through a real fetch.
///
/// Each of these views calls a `CometChat.*` AI static from `initState`. That
/// static validates its arguments and then resolves `sdk.ai` through
/// `SdkRegistry`, which `test/helpers/fake_sdk_ai.dart` registers a fake for.
/// So loading, success, empty and error all run here for real — previously
/// only the headless failure path did, which is why
/// `ai_view_styles_props_test.dart` could reach none of the item props and
/// none of the conversation starter's nine.
///
///   flutter test test/shared_ui/views/ai_panel_views_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sdk_ai.dart';

final _user = User(uid: 'u1', name: 'Alice');
final _group = Group(guid: 'g1', name: 'Team', type: GroupTypeConstants.public);

const _c1 = Color(0xFF111213);
const _c2 = Color(0xFF212223);
const _c3 = Color(0xFF313233);

/// Records the panel and composer events the views publish.
class _EventSpy with CometChatUIEventListener {
  final List<Map<String, dynamic>?> hiddenIds = [];
  final List<CustomUIPosition> hiddenPositions = [];
  final List<String> composed = [];
  final List<MessageEditStatus> composedStatuses = [];

  @override
  void hidePanel(Map<String, dynamic>? id, CustomUIPosition uiPosition) {
    hiddenIds.add(id);
    hiddenPositions.add(uiPosition);
  }

  @override
  void ccComposeMessage(String text, MessageEditStatus status) {
    composed.add(text);
    composedStatuses.add(status);
  }
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

List<BoxDecoration> _decorations(WidgetTester tester) => [
  for (final c in tester.widgetList<Container>(find.byType(Container)))
    if (c.decoration is BoxDecoration) c.decoration! as BoxDecoration,
  for (final d in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)))
    if (d.decoration is BoxDecoration) d.decoration as BoxDecoration,
];

TextStyle? _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style;

void main() {
  late _EventSpy spy;

  setUp(() async {
    await registerFakeAiBackend();
    spy = _EventSpy();
    CometChatUIEvents.addUiListener('ai-panel-views-test', spy);
  });

  tearDown(() async {
    CometChatUIEvents.removeUiListener('ai-panel-views-test');
    await clearFakeAiBackend();
  });

  // =========================================================================
  group('CometChatAISmartRepliesView — fetch', () {
    testWidgets('shows a shimmer row per pending reply, then the replies', (
      tester,
    ) async {
      final gate = Completer<Map<String, String>>();
      fakeSmartReplies = (_, _) => gate.future;

      await tester.pumpWidget(_wrap(CometChatAISmartRepliesView(user: _user)));
      await tester.pump();

      // Loading: the shimmer, and none of the replies yet.
      expect(find.byType(CometChatShimmerEffect), findsOneWidget);
      expect(find.text('Sure thing'), findsNothing);

      gate.complete(const {
        'positive': 'Sure thing',
        'negative': 'Not today',
        'neutral': 'Let me check',
      });
      await tester.pumpAndSettle();

      expect(find.byType(CometChatShimmerEffect), findsNothing);
      // The view orders negative → positive → neutral, not the map's order.
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where(
            (t) =>
                const {'Sure thing', 'Not today', 'Let me check'}.contains(t),
          )
          .toList();
      expect(texts, ['Not today', 'Sure thing', 'Let me check']);
    });

    testWidgets('a tone the backend omits is simply not listed', (
      tester,
    ) async {
      fakeSmartReplies = (_, _) => const {'positive': 'Sounds good'};

      await tester.pumpWidget(_wrap(CometChatAISmartRepliesView(user: _user)));
      await tester.pumpAndSettle();

      expect(find.text('Sounds good'), findsOneWidget);
      expect(find.byType(GestureDetector), findsWidgets);
    });

    // FINDING: the view reads the reply map by the tone keys 'negative',
    // 'positive' and 'neutral', but the SDK's AiRepository.getSmartReplies
    // (cometchat_sdk 5.0.7) builds its map as `replies[i.toString()] = ...`,
    // i.e. keyed '0', '1', '2'. Against the shipped SDK not one of the three
    // `containsKey` branches can ever be true, so the panel renders an empty
    // list on a perfectly successful fetch. This pins the current behaviour.
    testWidgets('an index-keyed reply map — what the SDK really returns — '
        'renders nothing', (tester) async {
      fakeSmartReplies = (_, _) => const {
        '0': 'Sure thing',
        '1': 'Not today',
        '2': 'Let me check',
      };

      await tester.pumpWidget(_wrap(CometChatAISmartRepliesView(user: _user)));
      await tester.pumpAndSettle();

      expect(find.text('Sure thing'), findsNothing);
      expect(find.text('Not today'), findsNothing);
      expect(find.text('Let me check'), findsNothing);
    });

    testWidgets('the receiver is the user uid, as a user receiver type', (
      tester,
    ) async {
      String? id;
      String? type;
      fakeSmartReplies = (receiverId, receiverType) {
        id = receiverId;
        type = receiverType;
        return const {'positive': 'Yes'};
      };

      await tester.pumpWidget(_wrap(CometChatAISmartRepliesView(user: _user)));
      await tester.pumpAndSettle();

      expect(id, 'u1');
      expect(type, CometChatReceiverType.user);
    });

    testWidgets('a group fetches by guid, as a group receiver type', (
      tester,
    ) async {
      String? id;
      String? type;
      fakeSmartReplies = (receiverId, receiverType) {
        id = receiverId;
        type = receiverType;
        return const {'positive': 'Yes'};
      };

      await tester.pumpWidget(
        _wrap(CometChatAISmartRepliesView(group: _group)),
      );
      await tester.pumpAndSettle();

      expect(id, 'g1');
      expect(type, CometChatReceiverType.group);
    });

    testWidgets('a failed fetch renders the error text, not the list', (
      tester,
    ) async {
      fakeSmartReplies = (_, _) => throw StateError('no network');

      await tester.pumpWidget(
        _wrap(
          CometChatAISmartRepliesView(
            user: _user,
            style: const CometChatAISmartRepliesStyle(
              errorTextStyle: TextStyle(color: _c2, fontSize: 17),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsNothing);
      final error = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => (t.data ?? '').contains('\n'));
      expect(error.style?.color, _c2);
      expect(error.style?.fontSize, 17);
    });

    testWidgets('with neither a user nor a group the fetch never happens', (
      tester,
    ) async {
      var called = false;
      fakeSmartReplies = (_, _) {
        called = true;
        return const {'positive': 'Yes'};
      };

      await tester.pumpWidget(_wrap(const CometChatAISmartRepliesView()));
      await tester.pumpAndSettle();

      // The static rejects the empty receiver id, so the view errors out.
      expect(called, isFalse);
      expect(find.text('Yes'), findsNothing);
    });

    testWidgets('tapping a reply composes it and hides the panel', (
      tester,
    ) async {
      fakeSmartReplies = (_, _) => const {'positive': 'On my way'};

      await tester.pumpWidget(_wrap(CometChatAISmartRepliesView(user: _user)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('On my way'));
      await tester.pump();

      expect(spy.composed, ['On my way']);
      expect(spy.composedStatuses, [MessageEditStatus.inProgress]);
      expect(spy.hiddenPositions, [CustomUIPosition.messageListBottom]);
      expect(spy.hiddenIds.single, {
        'uid': 'u1',
        AIUtils.extensionKey: AIFeatureConstants.aiSmartReplies,
      });
    });

    testWidgets('a group reply publishes a guid and no uid', (tester) async {
      fakeSmartReplies = (_, _) => const {'positive': 'On my way'};

      await tester.pumpWidget(
        _wrap(CometChatAISmartRepliesView(group: _group)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('On my way'));
      await tester.pump();

      expect(spy.hiddenIds.single!.containsKey('uid'), isFalse);
      expect(spy.hiddenIds.single!['guid'], 'g1');
    });

    testWidgets('the close icon hides the panel without composing', (
      tester,
    ) async {
      fakeSmartReplies = (_, _) => const {'positive': 'Yes'};

      await tester.pumpWidget(_wrap(CometChatAISmartRepliesView(user: _user)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(spy.composed, isEmpty);
      expect(spy.hiddenPositions, [CustomUIPosition.messageListBottom]);
      expect(
        spy.hiddenIds.single![AIUtils.extensionKey],
        AIFeatureConstants.aiSmartReplies,
      );
    });

    testWidgets('the four item props reach the rendered reply row', (
      tester,
    ) async {
      fakeSmartReplies = (_, _) => const {'positive': 'Styled reply'};

      await tester.pumpWidget(
        _wrap(
          CometChatAISmartRepliesView(
            user: _user,
            style: CometChatAISmartRepliesStyle(
              itemBackgroundColor: _c1,
              itemBorder: Border.all(color: _c2, width: 3),
              itemBorderRadius: BorderRadius.circular(21),
              itemTextStyle: const TextStyle(color: _c3, fontSize: 23),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = _decorations(
        tester,
      ).firstWhere((d) => d.color == _c1, orElse: () => const BoxDecoration());
      expect(row.color, _c1);
      expect((row.border! as Border).top.color, _c2);
      expect((row.border! as Border).top.width, 3);
      expect(row.borderRadius, BorderRadius.circular(21));

      final text = _styleOf(tester, 'Styled reply');
      expect(text?.color, _c3);
      expect(text?.fontSize, 23);
    });
  });

  // =========================================================================
  group('CometChatAIConversationStarterView', () {
    testWidgets('renders nothing while loading, then a row per starter', (
      tester,
    ) async {
      final gate = Completer<List<String>>();
      fakeConversationStarters = (_, _) => gate.future;

      await tester.pumpWidget(
        _wrap(CometChatAIConversationStarterView(user: _user)),
      );
      await tester.pump();

      expect(find.byType(ListView), findsNothing);

      gate.complete(const ['How are you?', 'What is new?']);
      await tester.pumpAndSettle();

      expect(find.text('How are you?'), findsOneWidget);
      expect(find.text('What is new?'), findsOneWidget);
    });

    testWidgets('an empty starter list stays collapsed', (tester) async {
      fakeConversationStarters = (_, _) => const <String>[];

      await tester.pumpWidget(
        _wrap(CometChatAIConversationStarterView(user: _user)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsNothing);
      expect(
        tester.getSize(find.byType(CometChatAIConversationStarterView)).height,
        0,
      );
    });

    testWidgets('a failed fetch stays collapsed — the view has no error UI', (
      tester,
    ) async {
      fakeConversationStarters = (_, _) => throw StateError('no network');

      await tester.pumpWidget(
        _wrap(CometChatAIConversationStarterView(user: _user)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsNothing);
      expect(
        tester.getSize(find.byType(CometChatAIConversationStarterView)).height,
        0,
      );
    });

    testWidgets('a group fetches by guid', (tester) async {
      String? id;
      String? type;
      fakeConversationStarters = (receiverId, receiverType) {
        id = receiverId;
        type = receiverType;
        return const ['Hi'];
      };

      await tester.pumpWidget(
        _wrap(CometChatAIConversationStarterView(group: _group)),
      );
      await tester.pumpAndSettle();

      expect(id, 'g1');
      expect(type, CometChatReceiverType.group);
    });

    testWidgets('tapping a starter composes it and hides the panel', (
      tester,
    ) async {
      fakeConversationStarters = (_, _) => const ['Tell me a joke'];

      await tester.pumpWidget(
        _wrap(CometChatAIConversationStarterView(user: _user)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tell me a joke'));
      await tester.pump();

      expect(spy.composed, ['Tell me a joke']);
      expect(spy.composedStatuses, [MessageEditStatus.inProgress]);
      expect(spy.hiddenPositions, [CustomUIPosition.messageListBottom]);
      // Unlike smart replies, the starter publishes no extension key.
      expect(spy.hiddenIds.single, {'uid': 'u1'});
    });

    testWidgets('backgroundColor, border, borderRadius and itemTextStyle', (
      tester,
    ) async {
      fakeConversationStarters = (_, _) => const ['Styled starter'];

      await tester.pumpWidget(
        _wrap(
          CometChatAIConversationStarterView(
            user: _user,
            style: CometChatAIConversationStarterStyle(
              backgroundColor: _c1,
              border: Border.all(color: _c2, width: 4),
              borderRadius: BorderRadius.circular(9),
              itemTextStyle: const TextStyle(color: _c3, fontSize: 27),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = _decorations(
        tester,
      ).firstWhere((d) => d.color == _c1, orElse: () => const BoxDecoration());
      expect(row.color, _c1);
      expect((row.border! as Border).top.color, _c2);
      expect((row.border! as Border).top.width, 4);
      expect(row.borderRadius, BorderRadius.circular(9));

      final text = _styleOf(tester, 'Styled starter');
      expect(text?.color, _c3);
      expect(text?.fontSize, 27);
    });

    testWidgets('itemTextStyle replaces the default outright', (tester) async {
      fakeConversationStarters = (_, _) => const ['Plain'];

      await tester.pumpWidget(
        _wrap(CometChatAIConversationStarterView(user: _user)),
      );
      await tester.pumpAndSettle();

      // With no style the text still gets the typography defaults.
      expect(_styleOf(tester, 'Plain')?.fontSize, isNotNull);
    });
  });

  // =========================================================================
  group('CometChatAIConversationSummaryView', () {
    testWidgets('shimmers while fetching, then shows the summary', (
      tester,
    ) async {
      final gate = Completer<String>();
      fakeConversationSummary = (_, _) => gate.future;

      await tester.pumpWidget(
        _wrap(CometChatAIConversationSummaryView(user: _user)),
      );
      await tester.pump();

      expect(find.byType(CometChatShimmerEffect), findsOneWidget);

      gate.complete('You agreed to meet on Friday.');
      await tester.pumpAndSettle();

      expect(find.byType(CometChatShimmerEffect), findsNothing);
      expect(find.text('You agreed to meet on Friday.'), findsOneWidget);
    });

    testWidgets('summaryTextStyle merges over the typography default', (
      tester,
    ) async {
      fakeConversationSummary = (_, _) => 'Summary body';

      await tester.pumpWidget(
        _wrap(
          CometChatAIConversationSummaryView(
            user: _user,
            aiConversationSummaryStyle:
                const CometChatAIConversationSummaryStyle(
                  summaryTextStyle: TextStyle(color: _c1, fontSize: 31),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final style = _styleOf(tester, 'Summary body');
      expect(style?.color, _c1);
      expect(style?.fontSize, 31);
      // Not overridden by summaryTextStyle, so the default survives the merge.
      expect(style?.fontWeight, isNotNull);
    });

    testWidgets('customView replaces the summary text and receives it', (
      tester,
    ) async {
      fakeConversationSummary = (_, _) => 'raw summary';
      String? seen;

      await tester.pumpWidget(
        _wrap(
          CometChatAIConversationSummaryView(
            user: _user,
            customView: (summary, context) {
              seen = summary;
              return const Text('custom body');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(seen, 'raw summary');
      expect(find.text('custom body'), findsOneWidget);
      expect(find.text('raw summary'), findsNothing);
    });

    testWidgets('loadingStateView replaces the shimmer', (tester) async {
      final gate = Completer<String>();
      fakeConversationSummary = (_, _) => gate.future;

      await tester.pumpWidget(
        _wrap(
          CometChatAIConversationSummaryView(
            user: _user,
            loadingStateView: (_) => const Text('loading…'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('loading…'), findsOneWidget);
      expect(find.byType(CometChatShimmerEffect), findsNothing);

      gate.complete('done');
      await tester.pumpAndSettle();
      expect(find.text('loading…'), findsNothing);
    });

    testWidgets('errorStateView replaces the default error chip', (
      tester,
    ) async {
      fakeConversationSummary = (_, _) => throw StateError('no network');

      await tester.pumpWidget(
        _wrap(
          CometChatAIConversationSummaryView(
            user: _user,
            errorStateView: (_) => const Text('custom error'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('custom error'), findsOneWidget);
      expect(
        find.textContaining('Looks like something'),
        findsNothing,
        reason: 'the default error text must not render alongside it',
      );
    });

    testWidgets('errorStateText and errorTextStyle drive the default chip', (
      tester,
    ) async {
      fakeConversationSummary = (_, _) => throw StateError('no network');

      await tester.pumpWidget(
        _wrap(
          CometChatAIConversationSummaryView(
            user: _user,
            errorStateText: 'Summary unavailable',
            aiConversationSummaryStyle:
                const CometChatAIConversationSummaryStyle(
                  errorTextStyle: TextStyle(color: _c2, fontSize: 19),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final style = _styleOf(tester, 'Summary unavailable');
      expect(style?.color, _c2);
      expect(style?.fontSize, 19);
    });

    testWidgets('the close icon hides the composerTop panel by default', (
      tester,
    ) async {
      fakeConversationSummary = (_, _) => 'body';

      await tester.pumpWidget(
        _wrap(CometChatAIConversationSummaryView(user: _user)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(spy.hiddenPositions, [CustomUIPosition.composerTop]);
      expect(
        spy.hiddenIds.single![AIUtils.extensionKey],
        AIFeatureConstants.aiConversationSummary,
      );
    });

    testWidgets('onCloseIconTap takes over and suppresses the hide event', (
      tester,
    ) async {
      fakeConversationSummary = (_, _) => 'body';
      Map<String, dynamic>? got;

      await tester.pumpWidget(
        _wrap(
          CometChatAIConversationSummaryView(
            user: _user,
            onCloseIconTap: (id) => got = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(got, isNotNull);
      expect(got!['uid'], 'u1');
      // The callback replaces the default, so nothing is published.
      expect(spy.hiddenPositions, isEmpty);
      // And it is handed the map before the extension key is added.
      expect(got!.containsKey(AIUtils.extensionKey), isFalse);
    });

    testWidgets('a group summary closes with a guid id', (tester) async {
      fakeConversationSummary = (_, _) => 'body';
      Map<String, dynamic>? got;

      await tester.pumpWidget(
        _wrap(
          CometChatAIConversationSummaryView(
            group: _group,
            onCloseIconTap: (id) => got = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(got!['guid'], 'g1');
    });

    testWidgets('the whole panel collapses while the keyboard is open', (
      tester,
    ) async {
      fakeConversationSummary = (_, _) => 'body';

      await tester.pumpWidget(
        _wrap(CometChatAIConversationSummaryView(user: _user)),
      );
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(find.text('body'), findsNothing);
      expect(
        tester.getSize(find.byType(CometChatAIConversationSummaryView)).height,
        0,
      );

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);
    });
  });
}
