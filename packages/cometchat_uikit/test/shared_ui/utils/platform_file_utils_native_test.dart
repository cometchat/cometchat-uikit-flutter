/// Behaviour tests for the native file utilities —
/// `platform_utils/platform_file_utils_native.dart`.
///
/// Everything here runs against a real filesystem (a temp directory) and the
/// real `cometchat_chat_uikit` method channel with a mock handler, so the
/// download / save / cache-lookup paths execute rather than being faked away.
/// `path_provider` is pointed at a temp directory with the existing
/// `test/helpers/fake_path_provider.dart` seam; without it every one of those
/// paths collapses onto "not downloaded" on a desktop host — which is itself
/// pinned, in `platform_file_utils_no_plugin_test.dart`.
///
///   flutter test test/shared_ui/utils/platform_file_utils_native_test.dart
library;

import 'dart:async';
import 'dart:io';

import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/utils/download_cache_key.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/utils/platform_utils/platform_file_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cometchat_chat_uikit');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory root;

  setUpAll(() {
    // The download root is cached in a file-level variable the first time it
    // is asked for, so this has to be in place before the first call.
    root = installFakePathProvider(prefix: 'cc_native_file_utils');
  });

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  // -------------------------------------------------------------------------
  group('web-only stubs', () {
    test('pickFilesWeb has nothing to pick natively', () async {
      expect(await pickFilesWeb(accept: 'image/*', multiple: true), isEmpty);
    });

    test('objectUrlFromBytes has no native equivalent', () {
      expect(objectUrlFromBytes(const [1, 2, 3], 'image/png'), isNull);
    });

    test('revokeObjectUrl is a no-op rather than an error', () {
      expect(() => revokeObjectUrl('blob:whatever'), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  group('local file inspection', () {
    late File file;

    setUp(() {
      file = File('${root.path}/probe file.txt')
        ..writeAsBytesSync(List<int>.filled(11, 0x41));
    });

    tearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    test('fileSizeOf reports the byte length', () {
      expect(fileSizeOf(file.path), 11);
    });

    test('fileSizeOf decodes a percent-encoded path', () {
      // Paths arrive from pickers already encoded; a raw lookup would miss.
      expect(fileSizeOf(file.path.replaceAll(' ', '%20')), 11);
    });

    test('fileSizeOf reports zero for a file that is not there', () {
      expect(fileSizeOf('${root.path}/absent.txt'), 0);
      expect(fileSizeOf(''), 0);
    });

    test('isLocalFileAvailable follows the same decoding rule', () {
      expect(isLocalFileAvailable(file.path), isTrue);
      expect(isLocalFileAvailable(file.path.replaceAll(' ', '%20')), isTrue);
      expect(isLocalFileAvailable('${root.path}/absent.txt'), isFalse);
      expect(isLocalFileAvailable(''), isFalse);
    });

    test('fileExistsSync does not decode — it takes the path as given', () {
      expect(fileExistsSync(file.path), isTrue);
      expect(
        fileExistsSync(file.path.replaceAll(' ', '%20')),
        isFalse,
        reason: 'the encoded form is a different literal path',
      );
    });

    test('videoControllerForPath builds a controller for a local file', () {
      final controller = videoControllerForPath(file.path);
      expect(controller, isNotNull);
      // The controller holds a file: URI, so the space comes back encoded.
      expect(controller!.dataSource, startsWith('file://'));
      expect(controller.dataSource, contains('probe%20file.txt'));
    });

    // probeMediaDuration is deliberately not covered: `initialize()` on a
    // VideoPlayerController never completes when video_player has no platform
    // implementation registered, so any test of it hangs rather than failing.
  });

  // -------------------------------------------------------------------------
  group('writeBytesToTempFile', () {
    test('writes the bytes and hands back the path', () async {
      final path = await writeBytesToTempFile(const [
        1,
        2,
        3,
        4,
      ], 'cc_write_probe.bin');
      expect(path, isNotNull);
      final written = File(path!);
      addTearDown(() {
        if (written.existsSync()) written.deleteSync();
      });
      expect(written.readAsBytesSync(), [1, 2, 3, 4]);
      expect(path, startsWith(Directory.systemTemp.path));
    });

    test('an unwritable name reports null rather than throwing', () async {
      // A name with a directory separator points at a directory that is not
      // there, so the write fails.
      expect(
        await writeBytesToTempFile(const [1], 'no_such_dir/cc_probe.bin'),
        isNull,
      );
    });

    test('an empty payload still produces a file', () async {
      final path = await writeBytesToTempFile(const [], 'cc_empty_probe.bin');
      expect(path, isNotNull);
      final written = File(path!);
      addTearDown(() {
        if (written.existsSync()) written.deleteSync();
      });
      expect(written.lengthSync(), 0);
    });
  });

  // -------------------------------------------------------------------------
  group('getDownloadedFilePath', () {
    const url = 'https://media.example.test/a/invoice.pdf?Expires=1&Sig=x';

    String bucketDir(String fileUrl) =>
        '${root.path}/${DownloadCacheKey.bucketFor(fileUrl)}';

    test('finds a file inside its attachment bucket', () async {
      final dir = Directory(bucketDir(url))..createSync(recursive: true);
      final file = File('${dir.path}/invoice.pdf')..writeAsStringSync('pdf');
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(
        await getDownloadedFilePath('invoice.pdf', fileUrl: url),
        file.path,
      );
    });

    test('a refreshed signature still resolves to the same bucket', () async {
      // The query is stripped before hashing, so the same file behind a new
      // signed URL is found rather than downloaded again.
      final dir = Directory(bucketDir(url))..createSync(recursive: true);
      File('${dir.path}/invoice.pdf').writeAsStringSync('pdf');
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(
        await getDownloadedFilePath(
          'invoice.pdf',
          fileUrl: 'https://media.example.test/a/invoice.pdf?Expires=999',
        ),
        isNotNull,
      );
    });

    test('another attachment with the same name is not handed back', () async {
      // The defect buckets exist to prevent: two senders' invoice.pdf.
      final dir = Directory(bucketDir(url))..createSync(recursive: true);
      File('${dir.path}/invoice.pdf').writeAsStringSync('pdf');
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(
        await getDownloadedFilePath(
          'invoice.pdf',
          fileUrl: 'https://media.example.test/b/invoice.pdf',
        ),
        isNull,
      );
    });

    test('with no url it looks in the flat legacy root', () async {
      final file = File('${root.path}/legacy.pdf')..writeAsStringSync('pdf');
      addTearDown(() => file.deleteSync());

      expect(await getDownloadedFilePath('legacy.pdf'), file.path);
      // ...and a bucketed file is invisible to a url-less lookup.
      expect(await getDownloadedFilePath('invoice.pdf'), isNull);
    });

    test('a file that was never downloaded is null, not an error', () async {
      expect(
        await getDownloadedFilePath('never-seen.pdf', fileUrl: url),
        isNull,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('downloadFileToLocal', () {
    // flutter_test replaces HttpOverrides with a client that answers 400 to
    // everything, which is exactly the "signed link expired" case the guard
    // below exists for.
    const url = 'https://media.example.test/c/photo.png';

    test('a non-200 response writes nothing and reports failure', () async {
      final bucket = Directory(
        '${root.path}/${DownloadCacheKey.bucketFor(url)}',
      );
      addTearDown(() {
        if (bucket.existsSync()) bucket.deleteSync(recursive: true);
      });

      expect(await downloadFileToLocal(url, 'photo.png'), isNull);
      // The guard runs before the file is opened, so no truncated file is
      // left behind for the "already downloaded" checks to trip over.
      expect(File('${bucket.path}/photo.png').existsSync(), isFalse);
      expect(await getDownloadedFilePath('photo.png', fileUrl: url), isNull);
    });

    test('a url that cannot be parsed is reported, not thrown', () async {
      expect(
        await downloadFileToLocal('https://[notanipv6]/x.png', 'x.png'),
        isNull,
      );
    });

    test('a 200 response is written into the attachment bucket', () async {
      const body = [0x89, 0x50, 0x4E, 0x47, 0x0D];
      final bucket = Directory(
        '${root.path}/${DownloadCacheKey.bucketFor(url)}',
      );
      addTearDown(() {
        if (bucket.existsSync()) bucket.deleteSync(recursive: true);
      });

      final path = await HttpOverrides.runZoned(
        () => downloadFileToLocal(url, 'photo.png'),
        createHttpClient: (_) => _FakeHttpClient(body, 200),
      );

      // Off Android there is no public Downloads collection to publish to, so
      // the app-local path is what comes back.
      expect(path, '${bucket.path}/photo.png');
      expect(File(path!).readAsBytesSync(), body);
      // ...and the cache lookup now agrees the attachment is on the device.
      expect(await getDownloadedFilePath('photo.png', fileUrl: url), path);
    });

    test('a dropped connection deletes the truncated file', () async {
      // Otherwise the half-written file makes the row look downloaded and
      // then fails to open.
      final bucket = Directory(
        '${root.path}/${DownloadCacheKey.bucketFor(url)}',
      );
      addTearDown(() {
        if (bucket.existsSync()) bucket.deleteSync(recursive: true);
      });

      final path = await HttpOverrides.runZoned(
        () => downloadFileToLocal(url, 'photo.png'),
        createHttpClient: (_) =>
            _FakeHttpClient(const [1, 2, 3], 200, failMidStream: true),
      );

      expect(path, isNull);
      expect(File('${bucket.path}/photo.png').existsSync(), isFalse);
      expect(await getDownloadedFilePath('photo.png', fileUrl: url), isNull);
    });

    test('a 403 leaves no file behind for the cache to trip over', () async {
      // Media URLs are signed and time-limited; piping an expired link's
      // error body into "photo.png" used to report success.
      final bucket = Directory(
        '${root.path}/${DownloadCacheKey.bucketFor(url)}',
      );
      addTearDown(() {
        if (bucket.existsSync()) bucket.deleteSync(recursive: true);
      });

      final path = await HttpOverrides.runZoned(
        () => downloadFileToLocal(url, 'photo.png'),
        createHttpClient: (_) =>
            _FakeHttpClient(const [60, 101, 114, 114, 62], 403),
      );

      expect(path, isNull);
      expect(File('${bucket.path}/photo.png').existsSync(), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('saveFileWithPicker', () {
    test('a path from the platform counts as saved', () async {
      MethodCall? seen;
      messenger.setMockMethodCallHandler(channel, (call) async {
        seen = call;
        return '/storage/emulated/0/Download/report.pdf';
      });

      expect(
        await saveFileWithPicker(
          'https://x/report.pdf',
          'report.pdf',
          'application/pdf',
        ),
        isTrue,
      );
      expect(seen!.method, 'saveFileWithPicker');
      final args = seen!.arguments as Map<dynamic, dynamic>;
      expect(args['url'], 'https://x/report.pdf');
      expect(args['fileName'], 'report.pdf');
      expect(args['mimeType'], 'application/pdf');
      expect(
        args.containsKey('path'),
        isFalse,
        reason: 'no cached copy was offered, so no path is sent',
      );
    });

    test('a cached copy is offered so the platform need not re-download', () {
      MethodCall? seen;
      messenger.setMockMethodCallHandler(channel, (call) async {
        seen = call;
        return '/somewhere/report.pdf';
      });

      return saveFileWithPicker(
        'https://x/report.pdf',
        'report.pdf',
        'application/pdf',
        localPath: '/cache/report.pdf',
      ).then((saved) {
        expect(saved, isTrue);
        expect(
          (seen!.arguments as Map<dynamic, dynamic>)['path'],
          '/cache/report.pdf',
        );
      });
    });

    test('an empty local path is not offered', () async {
      MethodCall? seen;
      messenger.setMockMethodCallHandler(channel, (call) async {
        seen = call;
        return '/somewhere/report.pdf';
      });

      await saveFileWithPicker(
        'https://x/r.pdf',
        'r.pdf',
        '*/*',
        localPath: '',
      );
      expect(
        (seen!.arguments as Map<dynamic, dynamic>).containsKey('path'),
        isFalse,
      );
    });

    test('a cancelled picker reports false', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(
        await saveFileWithPicker('https://x/r.pdf', 'r.pdf', '*/*'),
        isFalse,
      );
    });

    test('an empty path from the platform reports false', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => '');
      expect(
        await saveFileWithPicker('https://x/r.pdf', 'r.pdf', '*/*'),
        isFalse,
      );
    });

    test(
      'a platform exception reports false rather than propagating',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'ERR', message: 'no picker');
        });
        expect(
          await saveFileWithPicker('https://x/r.pdf', 'r.pdf', '*/*'),
          isFalse,
        );
      },
    );

    test('with no handler at all it reports false', () async {
      messenger.setMockMethodCallHandler(channel, null);
      expect(
        await saveFileWithPicker('https://x/r.pdf', 'r.pdf', '*/*'),
        isFalse,
      );
    });
  });
}

/// Minimal `HttpClient` that answers every GET with a fixed status and body.
///
/// `downloadFileToLocal` builds its own `HttpClient()` — there is no injection
/// point — so the only seam is `HttpOverrides`. Only the three members the
/// function actually touches are implemented; anything else throws, which is
/// what `noSuchMethod` inherited from Object does.
class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this.body, this.statusCode, {this.failMidStream = false});

  final List<int> body;
  final int statusCode;

  /// Emits the first chunk and then errors, like a connection dropped
  /// halfway through a download.
  final bool failMidStream;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeHttpClientRequest(body, statusCode, failMidStream: failMidStream);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(
    this.body,
    this.statusCode, {
    this.failMidStream = false,
  });

  final List<int> body;
  final int statusCode;
  final bool failMidStream;

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpClientResponse(body, statusCode, failMidStream: failMidStream);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(
    this.body,
    this.statusCode, {
    this.failMidStream = false,
  });

  final List<int> body;
  final bool failMidStream;

  @override
  final int statusCode;

  Stream<List<int>> _body() async* {
    yield body;
    if (failMidStream) {
      throw const SocketException('connection reset');
    }
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _body().listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
