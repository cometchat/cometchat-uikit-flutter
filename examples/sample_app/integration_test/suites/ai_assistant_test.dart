import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/pump_helper.dart';

/// AI assistant E2E (E2E-189 → E2E-191) — a surface with no coverage before.
///
/// What the sample app exposes (master_app/lib/screens/messages_screen.dart):
/// when the peer's role is 'ai' / '@agentic', MessagesScreen swaps the composer
/// placeholder for 'Ask anything...' and adds two header buttons through
/// `trailingView` — `IconButton(tooltip: 'New Chat')` and
/// `IconButton(tooltip: 'AI Chat History')`; the latter pushes
/// `CometChatAIAssistantChatHistory` (title 'Chat History', a ✕ close button,
/// then a list, or 'No conversation history found.', or the 'Oops!' error).
///
/// What it does NOT expose: a way to LIST agents. `HomeScreen.
/// _openAiAssistantScreen` (an Agents-only CometChatUsers) exists but nothing
/// calls it. So the agent is looked up with the same `UsersRequestBuilder`
/// roles filter that dead method uses, and the chat is opened through the
/// app's own `CometChatUIEvents.openChat` hook, which HomeScreen listens to and
/// routes to `_pushMessages` (the mention-tap path).
///
///   E2E-189  Opening an AI agent chat shows the agent composer placeholder
///            and the AI Chat History header button
///   E2E-190  The AI Chat History button opens the chat-history screen, which
///            settles into its list or its real empty state — never the error
///   E2E-191  Closing the chat-history screen returns to the agent chat
///
/// All three skip visibly when the backend has no '@agentic' user.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final history = find.byType(CometChatAIAssistantChatHistory);
  Finder inHistory(Finder f) => find.descendant(of: history, matching: f);

  /// Launch, find an agent, open its chat. Returns null after marking the
  /// test skipped when the backend has no agent.
  Future<User?> openAgentChat(WidgetTester tester) async {
    await AppLauncher.launchAndLogin(tester);
    if (!await pumpUntilFound(
      tester,
      find.byType(BottomNavigationBar),
      timeout: const Duration(seconds: 20),
    )) {
      fail('The app did not reach HomeScreen after login.');
    }

    CometChatException? error;
    final request =
        (UsersRequestBuilder()
              ..limit = 30
              ..roles = [AIConstants.aiRole])
            .build();
    final agents = await request.fetchNext(
      onSuccess: null,
      onError: (e) => error = e,
    );
    if (error != null) {
      fail('Could not query agents: ${error!.code} ${error!.message}');
    }
    if (agents.isEmpty) {
      markTestSkipped(
        'This CometChat app has no user with the '
        '"${AIConstants.aiRole}" role, so there is no AI assistant to open.',
      );
      return null;
    }

    final agent = agents.first;
    CometChatUIEvents.openChat(agent, null);
    if (!await pumpUntilFound(
      tester,
      find.byType(CometChatMessageComposer),
      timeout: const Duration(seconds: 15),
    )) {
      fail(
        'CometChatUIEvents.openChat did not open a messages screen for '
        'agent "${agent.name}".',
      );
    }
    await pumpFor(tester, const Duration(seconds: 2));
    return agent;
  }

  Future<void> openHistory(WidgetTester tester) async {
    final button = find.byTooltip('AI Chat History');
    if (button.evaluate().isEmpty) {
      fail('The agent chat header has no "AI Chat History" button.');
    }
    await tester.tap(button.first);
    if (!await pumpUntilFound(
      tester,
      history,
      timeout: const Duration(seconds: 10),
    )) {
      fail('"AI Chat History" did not open CometChatAIAssistantChatHistory.');
    }
  }

  group('AI assistant', () {
    testWidgets(
      'E2E-189: Opening an AI agent chat shows the agent composer and the '
      'chat history button',
      (tester) async {
        final agent = await openAgentChat(tester);
        if (agent == null) return;

        expect(
          find.descendant(
            of: find.byType(CometChatMessageHeader),
            matching: find.text(agent.name),
          ),
          findsWidgets,
          reason: 'The header should name the agent that was opened',
        );
        final askAnything = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Ask anything...',
        );
        expect(
          askAnything,
          findsOneWidget,
          reason: 'An agent chat should use the "Ask anything..." composer',
        );
        expect(
          find.byTooltip('AI Chat History'),
          findsOneWidget,
          reason: 'An agent chat should offer the AI Chat History button',
        );
      },
    );

    testWidgets(
      'E2E-190: The AI Chat History button opens the history list or its '
      'real empty state',
      (tester) async {
        final agent = await openAgentChat(tester);
        if (agent == null) return;
        await openHistory(tester);

        expect(
          inHistory(find.text('Chat History')),
          findsOneWidget,
          reason: 'The screen should be titled "Chat History"',
        );

        // Both data states render the "New Chat" row (`_buildEmpty` and
        // `_buildList` each call `_buildNewChatButton`); loading (shimmer) and
        // error ('Oops!') do not — so its arrival means the fetch settled well.
        final settled = await pumpUntilFound(
          tester,
          inHistory(find.text('New Chat')),
          timeout: const Duration(seconds: 30),
        );
        if (!settled) {
          final oops = inHistory(find.text('Oops!')).evaluate().isNotEmpty;
          fail(
            oops
                ? 'The chat-history screen rendered its ERROR state.'
                : 'The chat-history screen never left its loading shimmer.',
          );
        }
      },
    );

    testWidgets(
      'E2E-191: Closing the chat-history screen returns to the agent chat',
      (tester) async {
        final agent = await openAgentChat(tester);
        if (agent == null) return;
        await openHistory(tester);

        // The default back icon is a ✕ wrapped in Semantics(label: close) whose
        // onTap is the host's onClose → Navigator.pop.
        final close = inHistory(find.byIcon(Icons.close));
        expect(
          close,
          findsOneWidget,
          reason: 'The chat-history screen should offer a close button',
        );
        await tester.tap(close);

        expect(
          await pumpUntilGone(tester, history),
          isTrue,
          reason: 'Close should dismiss the chat-history screen',
        );
        expect(
          find.descendant(
            of: find.byType(CometChatMessageHeader),
            matching: find.text(agent.name),
          ),
          findsWidgets,
          reason: 'Closing history should land back on the agent chat',
        );
      },
    );
  });
}
