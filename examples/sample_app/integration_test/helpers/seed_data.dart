import 'dart:convert';
import 'package:http/http.dart' as http;

/// Creates and cleans up test data via CometChat REST API.
///
/// Credentials are compiled in via --dart-define or use hardcoded defaults
/// for the internal test app. Platform.environment is NOT available on device.
class SeedData {
  static const String _appId = String.fromEnvironment(
    'COMETCHAT_APP_ID',
    defaultValue: '',
  );
  static const String _region = String.fromEnvironment(
    'COMETCHAT_REGION',
    defaultValue: '',
  );
  /// The REST key is NOT defaulted. It used to carry a live key for the
  /// internal test app, which put a working credential in source on every
  /// branch that has this file. Pass it in:
  ///
  ///   flutter test … --dart-define=COMETCHAT_REST_API_KEY=YOUR_KEY
  ///
  /// CI injects it from the COMETCHAT_REST_API_KEY repository secret. An
  /// empty value fails loudly in [_assertConfigured] rather than producing a
  /// 401 nobody can read.
  static const String _restApiKey = String.fromEnvironment(
    'COMETCHAT_REST_API_KEY',
  );
  static const String _testUserUid = String.fromEnvironment(
    'TEST_USER_UID',
    defaultValue: '',
  );
  static const String _testPeerUid = String.fromEnvironment(
    'TEST_PEER_UID',
    defaultValue: '',
  );

  /// Peer for conversations a test intends to destroy. Deliberately NOT
  /// [_testPeerUid]: the delete-flow test used to remove whichever
  /// conversation sorted first, which is always the most recently seeded one
  /// — the fixture the message-list suite reads. Giving destructive tests
  /// their own peer keeps them from eating another suite's data.
  static const String _disposablePeerUid = String.fromEnvironment(
    'TEST_DISPOSABLE_PEER_UID',
    defaultValue: '',
  );

  /// UID of the peer used for conversations a test is going to delete.
  static String get disposablePeerUid => _disposablePeerUid;

  /// UID of the user the integration test logs in as.
  static String get testUserUid => _testUserUid;

  /// UID of the peer used as the "other side" of the seeded conversation.
  /// Tests render `CometChatMessageList(user: User(uid: testPeerUid))` to view
  /// messages exchanged with this peer.
  static String get testPeerUid => _testPeerUid;

  static String get _baseUrl => 'https://$_appId.api-$_region.cometchat.io/v3';

  /// Fails with a message that says what to do, instead of letting an empty
  /// key reach the API and come back as an opaque 401.
  static void _assertConfigured() {
    if (_restApiKey.isEmpty) {
      throw StateError(
        'COMETCHAT_REST_API_KEY is not set. The E2E suites seed their fixtures '
        'over REST and cannot run without it. Pass '
        '--dart-define=COMETCHAT_REST_API_KEY=<key> (CI reads the repository '
        'secret of the same name).',
      );
    }
  }

  static Map<String, String> get _headers {
    _assertConfigured();
    return {
      'Content-Type': 'application/json',
      'apiKey': _restApiKey,
      'appId': _appId,
    };
  }

  /// Send a text message from TEST_PEER_UID to TEST_USER_UID so that
  /// a conversation exists when the test starts.
  static Future<void> createTestConversation() async {
    await _sendTextMessage(
      fromUid: _testPeerUid,
      toUid: _testUserUid,
      text: 'E2E seed message ${DateTime.now().toIso8601String()}',
    );
  }

  /// Seed [count] messages in the 1:1 conversation between the test user and
  /// the peer. Messages alternate sender so the list shows both incoming and
  /// outgoing bubbles.
  ///
  /// Uses the same REST endpoint as [createTestConversation] but issues
  /// multiple requests with a small delay so message ordering is stable.
  static Future<void> seedMessages({int count = 5}) async {
    for (var i = 0; i < count; i++) {
      final fromPeer = i.isEven;
      await _sendTextMessage(
        fromUid: fromPeer ? _testPeerUid : _testUserUid,
        toUid: fromPeer ? _testUserUid : _testPeerUid,
        text: 'E2E msg #${i + 1} ${DateTime.now().toIso8601String()}',
      );
      // Avoid identical timestamps which can scramble list ordering.
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  static Future<void> _sendTextMessage({
    required String fromUid,
    required String toUid,
    required String text,
  }) async {
    final url = Uri.parse('$_baseUrl/messages');
    final body = jsonEncode({
      'receiver': toUid,
      'receiverType': 'user',
      'category': 'message',
      'type': 'text',
      'data': {'text': text},
    });

    final response = await http.post(
      url,
      headers: {..._headers, 'onBehalfOf': fromUid},
      body: body,
    );

    if (response.statusCode != 200) {
      throw StateError(
        'Failed to seed message ($fromUid → $toUid): '
        '${response.statusCode} ${response.body}',
      );
    }
  }

  /// Seed a conversation the caller intends to delete, and return the unique
  /// marker written into its last message.
  ///
  /// The marker is what makes the delete assertable: the row can be found by
  /// it before the delete and confirmed absent after, which is a statement
  /// about the conversation that was actually targeted. Counting rendered
  /// rows is not — the count is not 1:1 with conversations, and it does not
  /// move when the list has not refreshed yet.
  static Future<String> createDisposableConversation() async {
    // Short on purpose: this needle has to survive the conversation row's
    // subtitle truncation to be findable, so it is a tag rather than a
    // sentence.
    final marker = 'E2E-DEL-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    await _sendTextMessage(
      fromUid: _disposablePeerUid,
      toUid: _testUserUid,
      text: marker,
    );
    return marker;
  }

  /// Remove the disposable conversation, whether or not the test deleted it
  /// through the UI. Best-effort: the test deleting it is the normal path.
  static Future<void> cleanupDisposable() async {
    final url = Uri.parse(
      '$_baseUrl/users/$_testUserUid/conversation/user_$_disposablePeerUid',
    );
    try {
      await http.delete(
        url,
        headers: {..._headers, 'onBehalfOf': _testUserUid},
      );
    } catch (_) {
      // Ignore cleanup failures.
    }
  }

  /// Delete the conversation between test user and peer to clean up.
  /// Non-fatal if it fails (conversation may already be deleted by the test).
  static Future<void> cleanup() async {
    final url = Uri.parse(
      '$_baseUrl/users/$_testUserUid/conversation/user_$_testPeerUid',
    );

    // Best-effort cleanup — don't throw on failure.
    try {
      await http.delete(
        url,
        headers: {..._headers, 'onBehalfOf': _testUserUid},
      );
    } catch (_) {
      // Ignore cleanup failures.
    }
  }
}
