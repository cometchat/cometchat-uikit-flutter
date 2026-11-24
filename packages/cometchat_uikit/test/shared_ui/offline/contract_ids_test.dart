import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatMessageInput, Translations;
import 'package:cometchat_chat_uikit/shared_ui/src/offline/contract_ids.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every `Semantics` node that carries a state-contract identifier.
Finder _contractNodes() => find.byWidgetPredicate(
  (w) => w is Semantics && (w.properties.identifier?.startsWith('cc') ?? false),
);

void main() {
  tearDown(() => CometChat.debugSetOfflineEnabledOverride(null));

  test('message row identifier carries render key and state, no text', () {
    expect(
      ContractIds.messageRowId('l-123', 'sending'),
      'cc.message.l-123.sending',
    );
  });

  testWidgets(
    'contractNode exposes the identifier without changing the child',
    (tester) async {
      CometChat.debugSetOfflineEnabledOverride(true);
      await tester.pumpWidget(
        MaterialApp(
          home: contractNode(
            identifier: ContractIds.notice,
            child: const Text('hello'),
          ),
        ),
      );
      expect(find.text('hello'), findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.identifier == ContractIds.notice,
        ),
      );
      expect(semantics.properties.identifier, 'cc-notice');
    },
  );

  testWidgets('with offline off contractNode adds no Semantics node: it '
      'builds the child itself', (tester) async {
    CometChat.debugSetOfflineEnabledOverride(false);
    const child = Text('hello');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: contractNode(identifier: ContractIds.notice, child: child),
      ),
    );
    expect(find.byType(Semantics), findsNothing);
    expect(tester.widget(find.byType(Text)), same(child));
  });

  Widget composer() => MaterialApp(
    localizationsDelegates: Translations.localizationsDelegates,
    supportedLocales: const [Locale('en')],
    home: const Scaffold(body: CometChatMessageInput()),
  );

  testWidgets('with offline off the composer input has no extra Semantics '
      'node', (tester) async {
    CometChat.debugSetOfflineEnabledOverride(false);
    await tester.pumpWidget(composer());
    await tester.pump();
    expect(_contractNodes(), findsNothing);
  });

  testWidgets('with offline on the composer input carries its identifier', (
    tester,
  ) async {
    CometChat.debugSetOfflineEnabledOverride(true);
    await tester.pumpWidget(composer());
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.identifier == ContractIds.composerInput,
      ),
      findsOneWidget,
    );
  });

  // The wrapper is decided once per element: a gate flip mid-screen (a
  // logout, a login) must not swap it, which would rebuild the composer input
  // and drop its focus.
  Widget composerWith(String placeholder) => MaterialApp(
    localizationsDelegates: Translations.localizationsDelegates,
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: CometChatMessageInput(placeholderText: placeholder)),
  );

  Future<void> expectFlipKeepsInput(
    WidgetTester tester, {
    required bool from,
  }) async {
    CometChat.debugSetOfflineEnabledOverride(from);
    await tester.pumpWidget(composerWith('a'));
    await tester.pump();
    await tester.showKeyboard(find.byType(EditableText));
    await tester.pump();
    final before = tester.state<EditableTextState>(find.byType(EditableText));
    expect(before.widget.focusNode.hasFocus, isTrue);
    final nodes = tester.widgetList(_contractNodes()).length;

    CometChat.debugSetOfflineEnabledOverride(!from);
    await tester.pumpWidget(composerWith('b')); // rebuilds the input
    await tester.pump();
    final after = tester.state<EditableTextState>(find.byType(EditableText));
    expect(after, same(before), reason: 'the input was not rebuilt');
    expect(after.widget.focusNode.hasFocus, isTrue);
    expect(tester.widgetList(_contractNodes()).length, nodes);
  }

  testWidgets('a gate flip from on to off mid-screen does not rebuild the '
      'composer input or drop its focus', (tester) async {
    await expectFlipKeepsInput(tester, from: true);
  });

  testWidgets('a gate flip from off to on mid-screen does not rebuild the '
      'composer input or add a Semantics node', (tester) async {
    await expectFlipKeepsInput(tester, from: false);
    expect(_contractNodes(), findsNothing);
  });
}
