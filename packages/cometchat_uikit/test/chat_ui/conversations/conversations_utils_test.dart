import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/conversations/utils/debouncer.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/utils/preview_cache.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/utils/status_indicator_helper.dart';

// ---------------------------------------------------------------------------
// Fakes — minimal SDK doubles for the utils under test
// ---------------------------------------------------------------------------

class FakeConversation extends Fake implements Conversation {
  // Pin Conversation fields — read by the trailing view's pin glyph.
  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;
  final AppEntity _with;
  FakeConversation(this._with);

  @override
  AppEntity get conversationWith => _with;
}

class FakeUser extends Fake implements User {
  final String _status;
  FakeUser({String status = CometChatUserStatus.offline}) : _status = status;

  @override
  String get status => _status;

  @override
  String get uid => 'u1';

  @override
  String get name => 'Alice';
}

class FakeGroup extends Fake implements Group {
  final String _type;
  FakeGroup({String type = CometChatGroupType.public}) : _type = type;

  @override
  String get type => _type;

  @override
  String get guid => 'g1';

  @override
  String get name => 'Group';
}

void main() {
  // ========================================================================
  // Debouncer
  // ========================================================================

  group('Debouncer', () {
    test('fires callback after duration elapses', () async {
      final d = Debouncer(duration: const Duration(milliseconds: 20));
      var called = 0;

      d.call(() => called++);
      expect(called, 0);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(called, 1);
      d.dispose();
    });

    test('coalesces rapid calls into a single invocation', () async {
      final d = Debouncer(duration: const Duration(milliseconds: 30));
      var called = 0;

      for (var i = 0; i < 10; i++) {
        d.call(() => called++);
        await Future.delayed(const Duration(milliseconds: 5));
      }

      await Future.delayed(const Duration(milliseconds: 60));
      expect(called, 1);
      d.dispose();
    });

    test('cancel prevents pending callback from firing', () async {
      final d = Debouncer(duration: const Duration(milliseconds: 20));
      var called = 0;

      d.call(() => called++);
      d.cancel();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(called, 0);
      d.dispose();
    });

    test('dispose cancels any pending callback', () async {
      final d = Debouncer(duration: const Duration(milliseconds: 20));
      var called = 0;

      d.call(() => called++);
      d.dispose();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(called, 0);
    });
  });

  group('AsyncDebouncer', () {
    test('fires async callback once after coalescing', () async {
      final d = AsyncDebouncer(duration: const Duration(milliseconds: 20));
      var called = 0;

      Future<void> cb() async {
        called++;
      }

      // Fire and forget — the first future is cancelled by the second call.
      // Use unawaited semantics explicitly.
      // ignore: unawaited_futures
      d.call(cb);
      // ignore: unawaited_futures
      d.call(cb);
      await d.call(cb);

      expect(called, 1);
      d.dispose();
    });

    test('cancel prevents async callback execution', () async {
      final d = AsyncDebouncer(duration: const Duration(milliseconds: 20));
      var called = 0;

      // ignore: unawaited_futures
      d.call(() async {
        called++;
      });
      d.cancel();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(called, 0);
      d.dispose();
    });
  });

  // ========================================================================
  // PreviewCache
  // ========================================================================

  group('PreviewCache', () {
    test('put and get round-trip returns same preview', () {
      final cache = PreviewCache();
      final preview = CachedPreview(formattedText: 'hello');

      cache.put('m1', preview);

      expect(cache.get('m1'), same(preview));
      expect(cache.size, 1);
    });

    test('get returns null for unknown key', () {
      final cache = PreviewCache();
      expect(cache.get('nope'), isNull);
    });

    test('get returns null for expired entry and evicts it', () {
      final cache = PreviewCache();
      final past = DateTime.now().subtract(const Duration(minutes: 10));
      final preview = CachedPreview(
        formattedText: 'stale',
        cachedAt: past,
        ttl: const Duration(minutes: 5),
      );

      cache.put('m1', preview);
      expect(cache.size, 1);

      expect(cache.get('m1'), isNull);
      expect(cache.size, 0);
    });

    test('evicts oldest entry when exceeding maxCacheSize', () {
      final cache = PreviewCache(maxCacheSize: 2);
      cache.put('a', CachedPreview(formattedText: 'a'));
      cache.put('b', CachedPreview(formattedText: 'b'));
      cache.put('c', CachedPreview(formattedText: 'c')); // evicts 'a'

      expect(cache.size, 2);
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), isNotNull);
      expect(cache.get('c'), isNotNull);
    });

    test('remove drops a specific entry', () {
      final cache = PreviewCache();
      cache.put('a', CachedPreview(formattedText: 'a'));
      cache.put('b', CachedPreview(formattedText: 'b'));

      cache.remove('a');

      expect(cache.get('a'), isNull);
      expect(cache.get('b'), isNotNull);
      expect(cache.size, 1);
    });

    test('clear empties the cache', () {
      final cache = PreviewCache();
      cache.put('a', CachedPreview(formattedText: 'a'));
      cache.put('b', CachedPreview(formattedText: 'b'));

      cache.clear();

      expect(cache.size, 0);
    });
  });

  group('CachedPreview', () {
    test('isExpired is false when within TTL', () {
      final p = CachedPreview(
        formattedText: 'hi',
        ttl: const Duration(minutes: 5),
      );
      expect(p.isExpired, isFalse);
    });

    test('isExpired is true when past TTL', () {
      final p = CachedPreview(
        formattedText: 'hi',
        cachedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ttl: const Duration(minutes: 5),
      );
      expect(p.isExpired, isTrue);
    });
  });

  // ========================================================================
  // StatusIndicatorHelper
  // ========================================================================

  group('StatusIndicatorHelper', () {
    test('user online → shows green indicator', () {
      final conv = FakeConversation(
        FakeUser(status: CometChatUserStatus.online),
      );

      final result = StatusIndicatorHelper.getStatusIndicator(
        conversation: conv,
        hideUserStatus: false,
        hideGroupType: false,
      );

      expect(result.show, isTrue);
      expect(result.color, Colors.green);
      expect(result.icon, isNull);
    });

    test('user offline → hidden', () {
      final conv = FakeConversation(
        FakeUser(status: CometChatUserStatus.offline),
      );

      final result = StatusIndicatorHelper.getStatusIndicator(
        conversation: conv,
        hideUserStatus: false,
        hideGroupType: false,
      );

      expect(result.show, isFalse);
    });

    test('user online but hideUserStatus=true → hidden', () {
      final conv = FakeConversation(
        FakeUser(status: CometChatUserStatus.online),
      );

      final result = StatusIndicatorHelper.getStatusIndicator(
        conversation: conv,
        hideUserStatus: true,
        hideGroupType: false,
      );

      expect(result.show, isFalse);
    });

    test('private group → shield icon', () {
      final conv = FakeConversation(
        FakeGroup(type: CometChatGroupType.private),
      );

      final result = StatusIndicatorHelper.getStatusIndicator(
        conversation: conv,
        hideUserStatus: false,
        hideGroupType: false,
      );

      expect(result.show, isTrue);
      expect(result.icon, isA<Icon>());
      expect((result.icon as Icon).icon, Icons.shield);
    });

    test('password-protected group → lock icon', () {
      final conv = FakeConversation(
        FakeGroup(type: CometChatGroupType.password),
      );

      final result = StatusIndicatorHelper.getStatusIndicator(
        conversation: conv,
        hideUserStatus: false,
        hideGroupType: false,
      );

      expect(result.show, isTrue);
      expect(result.icon, isA<Icon>());
      expect((result.icon as Icon).icon, Icons.lock);
    });

    test('public group → hidden', () {
      final conv = FakeConversation(FakeGroup(type: CometChatGroupType.public));

      final result = StatusIndicatorHelper.getStatusIndicator(
        conversation: conv,
        hideUserStatus: false,
        hideGroupType: false,
      );

      expect(result.show, isFalse);
    });

    test('private group but hideGroupType=true → hidden', () {
      final conv = FakeConversation(
        FakeGroup(type: CometChatGroupType.private),
      );

      final result = StatusIndicatorHelper.getStatusIndicator(
        conversation: conv,
        hideUserStatus: false,
        hideGroupType: true,
      );

      expect(result.show, isFalse);
    });
  });
}
