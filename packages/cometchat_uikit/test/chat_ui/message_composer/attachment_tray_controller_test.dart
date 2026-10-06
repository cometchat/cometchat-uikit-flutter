/// Behaviour of [AttachmentTrayController] — the composer's staging model over
/// the SDK's multi-upload surface.
///
/// The controller is driven through a fake [FakeUploadSdkClient] registered in
/// the SDK registry, so `CometChat.createUploadFileRequest` hands it a real
/// `UploadFileRequest` over a recording repository. Per-file upload events are
/// then pushed by hand through the batch listener the tray registered.
///
///   flutter test test/chat_ui/message_composer/attachment_tray_controller_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_upload_sdk.dart';
import '../../helpers/fake_video_player_platform.dart';

UploadFile _file(
  String name, {
  String mime = 'application/pdf',
  int size = 1000,
  String? path,
  List<int>? bytes,
}) => UploadFile(
  name: name,
  size: size,
  mimeType: mime,
  path: bytes == null ? (path ?? '/tmp/$name') : null,
  bytes: bytes,
);

Attachment _attachment(
  String name, {
  String ext = 'pdf',
  String mime = 'application/pdf',
  String url = 'https://cdn.example.com/a.pdf',
}) => Attachment(url, name, ext, mime, 1000);

CometChatException _error({
  String? message,
  String? details,
  String code = 'E',
}) => CometChatException(code, details, message);

void main() {
  // `VideoPlayerController.initialize` registers a WidgetsBinding observer, so
  // the duration probe needs a binding even though nothing renders here.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeUploadSdkClient sdk;

  setUp(() async {
    sdk = await registerFakeUploadSdk(maxFileCount: 3, maxFileSize: 5000);
  });

  tearDown(clearFakeUploadSdk);

  AttachmentTrayController newController() =>
      AttachmentTrayController(receiverId: 'bob', receiverType: 'user');

  group('AttachmentStageException', () {
    test('prints the reason, and the cause when it has one', () {
      expect(
        AttachmentStageException('no conversation').toString(),
        'AttachmentStageException: no conversation',
      );
      expect(
        AttachmentStageException('no conversation', 'boom').toString(),
        'AttachmentStageException: no conversation (cause: boom)',
      );
    });
  });

  group('staging', () {
    test('an empty batch is a no-op — no request, no batch id', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([]);

      expect(c.tiles, isEmpty);
      expect(c.batchId, isNull);
      expect(sdk.repo.log, isEmpty);
    });

    test(
      'staging without a bound conversation throws instead of presigning',
      () async {
        for (final c in [
          AttachmentTrayController(),
          AttachmentTrayController(receiverId: '', receiverType: 'user'),
          AttachmentTrayController(receiverId: 'bob', receiverType: ''),
          AttachmentTrayController(receiverId: 'bob'),
        ]) {
          addTearDown(c.dispose);
          await expectLater(
            c.stage([_file('a.pdf')]),
            throwsA(
              isA<AttachmentStageException>().having(
                (e) => e.message,
                'message',
                contains('No conversation context'),
              ),
            ),
          );
          expect(c.tiles, isEmpty);
        }
        expect(sdk.repo.log, isEmpty, reason: 'nothing reached the SDK');
      },
    );

    test(
      'each staged file becomes a 0% tile under an id the tray supplies',
      () async {
        final c = newController();
        addTearDown(c.dispose);
        var notifications = 0;
        c.addListener(() => notifications++);

        await c.stage([
          _file('a.pdf', size: 400, path: '/tmp/a.pdf'),
          _file('b.pdf', size: 600, path: '/tmp/b.pdf'),
        ]);

        expect(c.tiles.map((t) => t.fileId), ['tile_0', 'tile_1']);
        expect(c.tiles.map((t) => t.name), ['a.pdf', 'b.pdf']);
        expect(c.tiles.map((t) => t.size), [400, 600]);
        expect(c.tiles.map((t) => t.loaded), [0, 0]);
        expect(c.tiles.map((t) => t.percent), [0, 0]);
        expect(
          c.tiles.every((t) => t.status == AttachmentTileStatus.uploading),
          isTrue,
        );
        // A path-based file previews from its local path.
        expect(c.tiles.map((t) => t.thumbUrl), ['/tmp/a.pdf', '/tmp/b.pdf']);
        expect(notifications, 1, reason: 'one notify for the whole batch');

        // The batch materialized against the bound conversation, and both files
        // went to the SDK under the tray's ids.
        expect(c.batchId, 'batch_0');
        expect(sdk.repo.receivers, ['bob/user']);
        expect(sdk.repo.uploadedIds, ['tile_0', 'tile_1']);
        expect(sdk.repo.uploadedFiles.map((f) => f.name), ['a.pdf', 'b.pdf']);
      },
    );

    test(
      'a second stage accumulates into the SAME batch and keeps counting up',
      () async {
        final c = newController();
        addTearDown(c.dispose);
        await c.stage([_file('a.pdf')]);
        final first = c.batchId;
        await c.stage([_file('b.pdf')]);

        expect(c.batchId, first);
        expect(c.tiles.map((t) => t.fileId), ['tile_0', 'tile_1']);
        expect(sdk.repo.batchIds, ['batch_0'], reason: 'one batch id only');
      },
    );

    test('a bytes-only file off web gets no local preview', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([
        _file('c.png', mime: 'image/png', bytes: const [1, 2, 3]),
      ]);
      // objectUrlFromBytes is a web-only affordance; off web there is nothing
      // to preview until the upload finishes.
      expect(c.tiles.single.thumbUrl, isNull);
    });

    test(
      'tiles returned by the getter cannot be mutated by the caller',
      () async {
        final c = newController();
        addTearDown(c.dispose);
        await c.stage([_file('a.pdf')]);
        expect(() => c.tiles.clear(), throwsUnsupportedError);
      },
    );
  });

  group('upload events', () {
    late AttachmentTrayController c;
    late UploadFileListener listener;

    setUp(() async {
      c = newController();
      addTearDown(c.dispose);
      await c.stage([_file('a.pdf', size: 1000), _file('b.pdf', size: 1000)]);
      listener = sdk.repo.globalListener!;
    });

    test('progress moves loaded and percent, and notifies', () {
      var notifications = 0;
      c.addListener(() => notifications++);

      listener.onFileProgress('tile_0', 250, 1000, 25);
      expect(c.tiles.first.loaded, 250);
      expect(c.tiles.first.percent, 25);
      expect(notifications, 1);

      // Percent is derived from the tray's own size, not the reported one.
      listener.onFileProgress('tile_0', 2000, 1000, 200);
      expect(c.tiles.first.percent, 100, reason: 'clamped to 100');
    });

    test('a zero-byte tile reports 0% instead of dividing by zero', () async {
      final empty = newController();
      addTearDown(empty.dispose);
      await empty.stage([_file('zero.pdf', size: 0)]);
      expect(empty.tiles.single.percent, 0);
    });

    test('progress for an unknown file id is ignored', () {
      var notifications = 0;
      c.addListener(() => notifications++);
      listener.onFileProgress('tile_99', 10, 20, 50);
      expect(notifications, 0);
      expect(c.tiles.every((t) => t.loaded == 0), isTrue);
    });

    test('onFileUploaded completes the tile and keeps the local preview', () {
      final a = _attachment('a.pdf', url: 'https://cdn/a.pdf');
      listener.onFileUploaded('tile_0', a);

      final tile = c.tiles.first;
      expect(tile.status, AttachmentTileStatus.done);
      expect(tile.loaded, tile.size, reason: 'a done tile reads 100%');
      expect(tile.percent, 100);
      expect(tile.attachment, same(a));
      expect(
        tile.thumbUrl,
        '/tmp/a.pdf',
        reason: 'the local path is kept — the CDN url may not be live yet',
      );
    });

    test('a tile with no local preview adopts the uploaded url', () async {
      final web = newController();
      addTearDown(web.dispose);
      await web.stage([
        _file('c.png', mime: 'image/png', bytes: const [1, 2, 3]),
      ]);
      sdk.repo.globalListener!.onFileUploaded(
        'tile_0',
        _attachment(
          'c.png',
          ext: 'png',
          mime: 'image/png',
          url: 'https://cdn/c.png',
        ),
      );
      expect(web.tiles.single.thumbUrl, 'https://cdn/c.png');
    });

    test('onFileError rejects the tile (not retryable) with a reason', () {
      listener.onFileError('tile_0', _error(message: 'too big'));
      expect(c.tiles.first.status, AttachmentTileStatus.rejected);
      expect(c.tiles.first.errorMessage, 'too big');
      expect(c.tiles.first.hasError, isTrue);
    });

    test('onFileFailure fails the tile (retryable) with a reason', () {
      listener.onFileFailure('tile_0', _error(message: 'network down'));
      expect(c.tiles.first.status, AttachmentTileStatus.failed);
      expect(c.tiles.first.errorMessage, 'network down');
      expect(c.tiles.first.hasError, isTrue);
    });

    test('the reason falls back message → details → code', () {
      listener.onFileError('tile_0', _error(details: 'detail text'));
      expect(c.tiles.first.errorMessage, 'detail text');

      listener.onFileFailure('tile_1', _error(code: 'ERR_CODE'));
      expect(c.tiles[1].errorMessage, 'ERR_CODE');
    });

    test('events for an unknown file id never create a tile', () {
      listener.onFileUploaded('ghost', _attachment('g.pdf'));
      listener.onFileError('ghost', _error(message: 'x'));
      listener.onFileFailure('ghost', _error(message: 'x'));
      expect(c.tiles.length, 2);
    });

    test('onComplete re-evaluates the tray without touching tiles', () {
      var notifications = 0;
      c.addListener(() => notifications++);
      listener.onComplete(
        const UploadResult(
          batchId: 'batch_0',
          successful: [],
          rejected: [],
          failed: [],
        ),
      );
      expect(notifications, 1);
      expect(
        c.tiles.every((t) => t.status == AttachmentTileStatus.uploading),
        isTrue,
      );
    });

    test('aggregate is byte-weighted across every tile', () {
      listener.onFileProgress('tile_0', 400, 1000, 40);
      expect(c.aggregate, [400, 2000]);
      listener.onFileUploaded('tile_1', _attachment('b.pdf'));
      expect(c.aggregate, [1400, 2000]);
    });
  });

  group('canSend / error gating', () {
    late AttachmentTrayController c;
    late UploadFileListener listener;

    setUp(() async {
      c = newController();
      addTearDown(c.dispose);
      await c.stage([_file('a.pdf'), _file('b.pdf')]);
      listener = sdk.repo.globalListener!;
    });

    test('an empty tray cannot send', () {
      final empty = newController();
      addTearDown(empty.dispose);
      expect(empty.canSend, isFalse);
    });

    test('send stays blocked while anything is still uploading', () {
      listener.onFileUploaded('tile_0', _attachment('a.pdf'));
      expect(c.canSend, isFalse, reason: 'tile_1 still uploading');
      listener.onFileUploaded('tile_1', _attachment('b.pdf'));
      expect(c.canSend, isTrue);
    });

    test('one errored tile blocks the whole send', () {
      listener.onFileUploaded('tile_0', _attachment('a.pdf'));
      listener.onFileFailure('tile_1', _error(message: 'nope'));
      expect(c.hasErrors, isTrue);
      expect(c.errorTiles.map((t) => t.fileId), ['tile_1']);
      expect(c.canSend, isFalse);

      // Removing the offender unblocks it.
      c.cancelOrRemove('tile_1');
      expect(c.hasErrors, isFalse);
      expect(c.canSend, isTrue);
    });

    test('a tray of nothing but errors cannot send', () {
      listener.onFileError('tile_0', _error(message: 'x'));
      listener.onFileError('tile_1', _error(message: 'y'));
      expect(c.canSend, isFalse);
      expect(c.errorTiles.length, 2);
    });
  });

  group('limits', () {
    test('the count and size caps come from the cached app settings', () {
      final c = newController();
      addTearDown(c.dispose);
      expect(c.maxFileCount, 3);
      expect(c.maxFileSize, 5000);
    });

    test(
      'with no cached settings the documented client defaults apply',
      () async {
        sdk = await registerFakeUploadSdk();
        final c = newController();
        addTearDown(c.dispose);
        expect(c.maxFileCount, 10);
        expect(c.maxFileSize, 100 * 1024 * 1024);
      },
    );

    test('with no SDK at all the caps fall back instead of throwing', () async {
      await clearFakeUploadSdk();
      final c = AttachmentTrayController(
        receiverId: 'bob',
        receiverType: 'user',
      );
      addTearDown(c.dispose);
      expect(c.maxFileCount, 10);
      expect(c.maxFileSize, 100 * 1024 * 1024);
    });

    test('rejected tiles do not consume slots', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([_file('a.pdf'), _file('b.pdf')]);

      expect(c.activeCount, 2);
      expect(c.remainingSlots, 1);
      expect(c.canAddMore, isTrue);

      c.addLimitRejected(_file('huge.pdf'), 'File is too large');
      expect(c.tiles.length, 3);
      expect(c.activeCount, 2, reason: 'a rejected tile is not staged');
      expect(c.remainingSlots, 1);
    });

    test('remaining slots never go negative once the tray is full', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([
        _file('a.pdf'),
        _file('b.pdf'),
        _file('c.pdf'),
        _file('d.pdf'),
      ]);
      expect(c.activeCount, 4);
      expect(c.remainingSlots, 0, reason: 'clamped, not -1');
      expect(c.canAddMore, isFalse);
    });

    test(
      'addLimitRejected stages a removable, non-uploading error tile',
      () async {
        final c = newController();
        addTearDown(c.dispose);
        var notifications = 0;
        c.addListener(() => notifications++);

        c.addLimitRejected(_file('huge.pdf', size: 99999), 'File is too large');
        c.addLimitRejected(_file('huge2.pdf'), 'Too many files');

        expect(c.tiles.map((t) => t.fileId), [
          'local_reject_0',
          'local_reject_1',
        ]);
        expect(c.tiles.first.status, AttachmentTileStatus.rejected);
        expect(c.tiles.first.errorMessage, 'File is too large');
        expect(c.tiles.first.thumbUrl, '/tmp/huge.pdf');
        expect(notifications, 2);
        expect(c.hasErrors, isTrue);
        expect(c.canSend, isFalse);
        // Never reached the SDK.
        expect(sdk.repo.log, isEmpty);
      },
    );

    test('a bytes-only rejected file has nothing to preview off web', () {
      final c = newController();
      addTearDown(c.dispose);
      c.addLimitRejected(
        _file('huge.png', mime: 'image/png', bytes: const [1, 2]),
        'File is too large',
      );
      expect(c.tiles.single.thumbUrl, isNull);
    });
  });

  group('removal, retry and clearing', () {
    test('removing a staged tile drops it and cancels it in the SDK', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([_file('a.pdf'), _file('b.pdf')]);

      await c.cancelOrRemove('tile_0');
      expect(c.tiles.map((t) => t.fileId), ['tile_1']);
      expect(sdk.repo.log, contains('remove:tile_0'));
    });

    test('removing a locally-rejected tile never reaches the SDK', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([_file('a.pdf')]);
      c.addLimitRejected(_file('huge.pdf'), 'too large');
      sdk.repo.log.clear();

      await c.cancelOrRemove('local_reject_0');
      expect(c.tiles.map((t) => t.fileId), ['tile_0']);
      expect(sdk.repo.log, isEmpty);
    });

    test('removing an unknown id changes nothing', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([_file('a.pdf')]);
      await c.cancelOrRemove('tile_77');
      expect(c.tiles.length, 1);
    });

    test('retry resets the tile to 0% uploading and re-asks the SDK', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([_file('a.pdf', size: 1000)]);
      final listener = sdk.repo.globalListener!;
      listener.onFileProgress('tile_0', 600, 1000, 60);
      listener.onFileFailure('tile_0', _error(message: 'network'));
      expect(c.tiles.single.status, AttachmentTileStatus.failed);

      await c.retry('tile_0');
      expect(c.tiles.single.status, AttachmentTileStatus.uploading);
      expect(c.tiles.single.loaded, 0);
      expect(sdk.repo.log, contains('retry:tile_0'));
    });

    test('an over-limit tile is not retryable', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([_file('a.pdf')]);
      c.addLimitRejected(_file('huge.pdf'), 'too large');
      sdk.repo.log.clear();

      await c.retry('local_reject_0');
      expect(c.tiles[1].status, AttachmentTileStatus.rejected);
      expect(sdk.repo.log, isEmpty);
    });

    test(
      'retry is a no-op for an unknown id, and before any batch exists',
      () async {
        final fresh = newController();
        addTearDown(fresh.dispose);
        await fresh.retry('tile_0');
        expect(sdk.repo.log, isEmpty);

        final c = newController();
        addTearDown(c.dispose);
        await c.stage([_file('a.pdf')]);
        sdk.repo.log.clear();
        await c.retry('nope');
        expect(sdk.repo.log, isEmpty);
      },
    );

    test('clear empties the tray, the caption and the batch', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([_file('a.pdf')]);
      c.setCaption('look at this');
      expect(c.caption, 'look at this');

      var notifications = 0;
      c.addListener(() => notifications++);
      await c.clear();

      expect(c.tiles, isEmpty);
      expect(c.caption, '');
      expect(c.batchId, isNull);
      expect(notifications, 1);
      expect(sdk.repo.log, contains('clearAll:batch_0'));
    });

    test(
      'the next stage after a clear re-binds to the CURRENT conversation',
      () async {
        final c = newController();
        addTearDown(c.dispose);
        await c.stage([_file('a.pdf')]);
        await c.clear();

        c
          ..receiverId = 'team'
          ..receiverType = 'group';
        await c.stage([_file('b.pdf')]);

        expect(c.batchId, 'batch_1', reason: 'a fresh batch');
        expect(sdk.repo.receivers, ['bob/user', 'team/group']);
      },
    );

    test(
      'dispose releases the batch and silences further notifications',
      () async {
        final c = newController();
        await c.stage([_file('a.pdf')]);
        final listener = sdk.repo.globalListener!;

        var notifications = 0;
        c.addListener(() => notifications++);
        c.dispose();

        expect(sdk.repo.log, contains('clearAll:batch_0'));
        // A late upload event after disposal must not notify a dead listener.
        listener.onFileProgress('tile_0', 10, 1000, 1);
        listener.onFileUploaded('tile_0', _attachment('a.pdf'));
        expect(notifications, 0);
      },
    );
  });

  group('buildBatchMessages', () {
    late AttachmentTrayController c;

    setUp(() {
      c = newController();
      addTearDown(c.dispose);
    });

    Future<void> stageAndFinish(List<(String, String, String)> files) async {
      await c.stage([for (final f in files) _file(f.$1, mime: f.$2)]);
      final listener = sdk.repo.globalListener!;
      for (var i = 0; i < files.length; i++) {
        listener.onFileUploaded(
          'tile_$i',
          Attachment(
            'https://cdn/${files[i].$1}',
            files[i].$1,
            files[i].$3,
            files[i].$2,
            1000,
          ),
        );
      }
    }

    test('an empty tray builds nothing', () {
      expect(
        c.buildBatchMessages(receiverUid: 'bob', receiverType: 'user'),
        isEmpty,
      );
    });

    test('a tray with nothing done builds nothing', () async {
      await c.stage([_file('a.pdf')]);
      expect(
        c.buildBatchMessages(receiverUid: 'bob', receiverType: 'user'),
        isEmpty,
      );
      expect(c.doneAttachments, isEmpty);
    });

    test('one kind produces one message keyed by the plain batch id', () async {
      await stageAndFinish([
        ('a.jpg', 'image/jpeg', 'jpg'),
        ('b.jpg', 'image/jpeg', 'jpg'),
      ]);
      c.setCaption('  holiday  ');

      final msgs = c.buildBatchMessages(
        receiverUid: 'bob',
        receiverType: 'user',
      );
      expect(msgs.length, 1);
      final m = msgs.single;
      expect(m.type, 'image');
      expect(m.muid, c.batchId, reason: 'single kind ⇒ no _kind suffix');
      expect(m.attachments?.length, 2);
      expect(m.attachment?.fileName, 'a.jpg');
      expect(m.caption, 'holiday', reason: 'trimmed');
      expect(m.metadata?[UploadMetadataKeys.batchId], c.batchId);
      expect(m.metadata?['batchIndex'], 0);
      expect(m.metadata?['batchSize'], 1);
      expect(m.metadata?.containsKey('audioDurationsMs'), isFalse);
    });

    test('an empty caption is dropped rather than sent blank', () async {
      await stageAndFinish([('a.jpg', 'image/jpeg', 'jpg')]);
      c.setCaption('   ');
      final msgs = c.buildBatchMessages(
        receiverUid: 'bob',
        receiverType: 'user',
      );
      expect(msgs.single.caption, isNull);
    });

    test(
      'mixed kinds fan out image → video → audio → file, in that order',
      () async {
        await stageAndFinish([
          ('doc.pdf', 'application/pdf', 'pdf'),
          ('clip.mp4', 'video/mp4', 'mp4'),
          ('song.mp3', 'audio/mpeg', 'mp3'),
          ('pic.jpg', 'image/jpeg', 'jpg'),
        ]);
        c.setCaption('everything');

        final msgs = c.buildBatchMessages(
          receiverUid: 'bob',
          receiverType: 'user',
        );
        expect(msgs.map((m) => m.type), ['image', 'video', 'audio', 'file']);
        expect(
          msgs.map((m) => m.muid),
          ['image', 'video', 'audio', 'file'].map((k) => '${c.batchId}_$k'),
          reason: 'multi-kind ⇒ per-kind muid',
        );
        expect(msgs.map((m) => m.metadata?['batchIndex']), [0, 1, 2, 3]);
        expect(msgs.every((m) => m.metadata?['batchSize'] == 4), isTrue);
        expect(
          msgs.every(
            (m) => m.metadata?[UploadMetadataKeys.batchId] == c.batchId,
          ),
          isTrue,
        );
        // The caption rides on the LAST message only.
        expect(msgs.map((m) => m.caption), [null, null, null, 'everything']);
        // sentAt increases with the kind order so the list keeps them together.
        for (var i = 1; i < msgs.length; i++) {
          expect(msgs[i].sentAt!.isAfter(msgs[i - 1].sentAt!), isTrue);
        }
      },
    );

    test(
      'audio carries a per-attachment duration list, index-aligned',
      () async {
        await stageAndFinish([
          ('one.mp3', 'audio/mpeg', 'mp3'),
          ('two.mp3', 'audio/mpeg', 'mp3'),
        ]);
        c.tiles.first.durationMillis = 4200;

        final m = c
            .buildBatchMessages(receiverUid: 'bob', receiverType: 'user')
            .single;
        expect(m.type, 'audio');
        expect(m.metadata?['audioDurationsMs'], [4200, null]);
      },
    );

    test('the sender rides on every fanned-out message', () async {
      await stageAndFinish([
        ('pic.jpg', 'image/jpeg', 'jpg'),
        ('doc.pdf', 'application/pdf', 'pdf'),
      ]);
      final sender = User(uid: 'me', name: 'Me');

      final msgs = c.buildBatchMessages(
        receiverUid: 'bob',
        receiverType: 'user',
        sender: sender,
      );
      expect(msgs.every((m) => m.sender == sender), isTrue);
      expect(msgs.every((m) => m.receiverUid == 'bob'), isTrue);
    });

    test('a removed tile drops out of the sent set', () async {
      await stageAndFinish([
        ('pic.jpg', 'image/jpeg', 'jpg'),
        ('doc.pdf', 'application/pdf', 'pdf'),
      ]);
      await c.cancelOrRemove('tile_1');

      final msgs = c.buildBatchMessages(
        receiverUid: 'bob',
        receiverType: 'user',
      );
      expect(msgs.map((m) => m.type), ['image']);
    });
  });

  group('tile kind', () {
    test('a staged tile classifies by mimeType OR extension', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([
        _file('pic.jpg', mime: 'image/jpeg'),
        _file('clip.mp4', mime: 'video/mp4'),
        _file('song.mp3', mime: 'audio/mpeg'),
        _file('doc.pdf'),
        // A generic mimeType must not beat an unambiguous extension: these are
        // the mismatches that made the tray preview disagree with what was
        // actually sent.
        _file('clip.m4v', mime: 'application/octet-stream'),
        _file('tune.flac', mime: 'application/octet-stream'),
        // Ogg is registered as both audio/* and video/*; audio wins.
        _file('voice.ogg', mime: 'video/ogg'),
      ]);

      String kindOf(AttachmentTile t) => t.isImage
          ? 'image'
          : t.isVideo
          ? 'video'
          : t.isAudio
          ? 'audio'
          : 'file';

      expect(c.tiles.map(kindOf), [
        'image',
        'video',
        'audio',
        'file',
        'video',
        'audio',
        'audio',
      ]);
    });
  });

  // Declared last: `VideoPlayerPlatform.instance` has no un-set, so the fake
  // stays installed for everything after it.
  group('duration probing', () {
    setUp(() {
      installFakeVideoPlayerPlatform(duration: const Duration(seconds: 12));
    });

    test(
      'a staged video tile learns its duration from the local source',
      () async {
        final c = newController();
        addTearDown(c.dispose);
        var notifications = 0;
        c.addListener(() => notifications++);

        await c.stage([_file('clip.mp4', mime: 'video/mp4')]);
        expect(c.tiles.single.durationMillis, isNull, reason: 'probe is async');
        expect(notifications, 1);

        await pumpEventQueue();
        expect(c.tiles.single.durationMillis, 12000);
        expect(notifications, 2, reason: 'the probe notifies when it lands');
      },
    );

    test(
      'a staged audio tile probes too, and carries it into the message',
      () async {
        final c = newController();
        addTearDown(c.dispose);
        await c.stage([_file('song.mp3', mime: 'audio/mpeg')]);
        await pumpEventQueue();

        sdk.repo.globalListener!.onFileUploaded(
          'tile_0',
          Attachment(
            'https://cdn/song.mp3',
            'song.mp3',
            'mp3',
            'audio/mpeg',
            1000,
          ),
        );
        final m = c
            .buildBatchMessages(receiverUid: 'bob', receiverType: 'user')
            .single;
        expect(m.metadata?['audioDurationsMs'], [12000]);
      },
    );

    test(
      'a tile removed before the probe lands never gains a duration',
      () async {
        final c = newController();
        addTearDown(c.dispose);
        await c.stage([_file('clip.mp4', mime: 'video/mp4')]);
        final tile = c.tiles.single;
        await c.cancelOrRemove('tile_0');

        await pumpEventQueue();
        expect(tile.durationMillis, isNull);
        expect(c.tiles, isEmpty);
      },
    );

    test('a plain file is never probed', () async {
      final c = newController();
      addTearDown(c.dispose);
      await c.stage([_file('doc.pdf')]);
      await pumpEventQueue();
      expect(c.tiles.single.durationMillis, isNull);
    });
  });
}
