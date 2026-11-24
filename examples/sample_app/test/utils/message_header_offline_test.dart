/// W8 (ENG-41131): a chat opened by id (push, deep link) never blocks offline.
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/utils/message_header_offline.dart';

final _bob = User(uid: 'u2', name: 'Bob');
final _team = Group(guid: 'g1', name: 'Team', type: 'public');
final _offline = CometChatException('ERR_CONNECTION', 'offline', 'offline');

void main() {
  final calls = <String>[];
  void Function(ConversationDetailsListener l)? onGetConversation;

  setUp(() {
    calls.clear();
    onGetConversation = null;
    MessageHeaderOfflineSeams.getConversation = (id, type, l) async {
      calls.add('conversation:$type:$id');
      onGetConversation?.call(l);
    };
    MessageHeaderOfflineSeams.getUser = (uid, onSuccess, onError) async {
      calls.add('getUser:$uid');
      onError(_offline);
    };
    MessageHeaderOfflineSeams.getGroup = (guid, onSuccess, onError) async {
      calls.add('getGroup:$guid');
      onSuccess(_team);
    };
  });

  tearDown(() {
    MessageHeaderOfflineSeams.reset();
    CometChat.debugSetOfflineEnabledOverride(null);
  });

  Future<(User?, Group?, CometChatException?)> open(
    String id,
    String type,
  ) async {
    User? user;
    Group? group;
    CometChatException? error;
    await MessageHeaderOffline.fetchChatById(
      id,
      type,
      onUser: (u) => user = u,
      onGroup: (g) => group = g,
      onError: (e) => error = e,
    );
    return (user, group, error);
  }

  test('OFF: today\'s getUser / getGroup only', () async {
    CometChat.debugSetOfflineEnabledOverride(false);
    await open('u2', 'user');
    await open('g1', 'group');
    expect(calls, ['getUser:u2', 'getGroup:g1']);
  });

  test('ON offline: the cached conversation opens the chat, no server wait, '
      'no fallback', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    late ConversationDetailsListener held;
    onGetConversation = (l) {
      held = l;
      l.onCachedConversation(
        Conversation(conversationType: 'user', conversationWith: _bob),
      );
    };
    final (user, group, error) = await open('u2', 'user');
    expect(user?.uid, 'u2');
    expect(group, isNull);
    expect(error, isNull);
    // The server round fails later: nothing more happens.
    held.onError(_offline);
    expect(calls, ['conversation:user:u2']);
  });

  test('ON: opens once even when both rounds deliver', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    var opens = 0;
    onGetConversation = (l) {
      final c = Conversation(
        conversationType: 'group',
        conversationWith: _team,
      );
      l.onCachedConversation(c);
      l.onServerConversation(c);
    };
    await MessageHeaderOffline.fetchChatById(
      'g1',
      'group',
      onUser: (_) {},
      onGroup: (_) => opens++,
      onError: (_) {},
    );
    expect(opens, 1);
  });

  test('ON: nothing cached and the server fails → today\'s call', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    onGetConversation = (l) => l.onError(_offline);
    final (user, _, error) = await open('u2', 'user');
    expect(user, isNull);
    expect(error?.code, 'ERR_CONNECTION');
    expect(calls, ['conversation:user:u2', 'getUser:u2']);
  });

  test('ON: the SDK call ends with no callback (its general catch skips '
      'onError) → today\'s call, no hang', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    // As the SDK's `catch (e)` in getConversation: the failure is swallowed
    // and the listener hears nothing.
    onGetConversation = (_) {};
    final (user, _, error) = await open(
      'u2',
      'user',
    ).timeout(const Duration(seconds: 2));
    expect(user, isNull);
    expect(error?.code, 'ERR_CONNECTION');
    expect(calls, ['conversation:user:u2', 'getUser:u2']);
  });

  test('ON: a conversation read that never ends falls back after the '
      'timeout', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    MessageHeaderOfflineSeams.settleTimeout = const Duration(milliseconds: 50);
    MessageHeaderOfflineSeams.getConversation = (id, type, l) {
      calls.add('conversation:$type:$id');
      return Completer<void>().future;
    };
    final (_, group, error) = await open(
      'g1',
      'group',
    ).timeout(const Duration(seconds: 2));
    expect(group?.guid, 'g1');
    expect(error, isNull);
    expect(calls, ['conversation:group:g1', 'getGroup:g1']);
  });

  test(
    'ON: a conversation read that throws falls back to today\'s call',
    () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      MessageHeaderOfflineSeams.getConversation = (id, type, l) =>
          throw StateError('boom');
      final (_, group, _) = await open(
        'g1',
        'group',
      ).timeout(const Duration(seconds: 2));
      expect(group?.guid, 'g1');
      expect(calls, ['getGroup:g1']);
    },
  );

  test('ON: an onUser that throws surfaces its error after the read, never '
      'a hang', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    onGetConversation = (l) => l.onCachedConversation(
      Conversation(conversationType: 'user', conversationWith: _bob),
    );
    await expectLater(
      MessageHeaderOffline.fetchChatById(
        'u2',
        'user',
        onUser: (_) => throw StateError('caller'),
        onGroup: (_) {},
        onError: (_) {},
      ).timeout(const Duration(seconds: 2)),
      throwsA(isA<StateError>()),
    );
    expect(calls, ['conversation:user:u2']);
  });

  testWidgets('open by id offline resolves the user inside a widget test', (
    tester,
  ) async {
    CometChat.debugSetOfflineEnabledOverride(true);
    onGetConversation = (l) => l.onCachedConversation(
      Conversation(conversationType: 'user', conversationWith: _bob),
    );
    User? resolved;
    await tester.runAsync(() async {
      await MessageHeaderOffline.fetchChatById(
        'u2',
        'user',
        onUser: (u) => resolved = u,
        onGroup: (_) {},
        onError: (_) {},
      );
    });
    expect(resolved?.uid, 'u2');
    expect(calls, ['conversation:user:u2']);
  });
}
