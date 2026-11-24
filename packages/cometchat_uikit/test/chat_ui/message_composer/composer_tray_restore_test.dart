/// W8 (ENG-41131): composer upload-tray restore (BEH-UPLOAD-14).
///
/// Restore runs once per settled triple (thread composers included), maps
/// every SDK file state to a tile, never clobbers a live tray, never uploads.
/// Retry picks by file presence. A triple change with offline on detaches
/// (the batch survives); with offline off it destroys the batch, as today.
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_composer_offline.dart';
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/upload/upload_repository.dart'
    as sdk;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_upload_sdk.dart';

/// The repository behind a restored request: serves [files], logs calls.
class _RestoredRepo extends Fake implements sdk.UploadRepository {
  _RestoredRepo(this.files);

  final List<UploadFileView> files;
  final List<String> log = [];
  UploadFileListener? globalListener;

  @override
  List<UploadFileView> viewFiles(String batchId) => files;

  @override
  void setGlobalListener(String batchId, UploadFileListener? listener) {
    globalListener = listener;
    log.add(listener == null ? 'listener:off' : 'listener:on');
  }

  @override
  void upload(
    String batchId,
    List<({String fileId, UploadFile file})> files,
    UploadFileListener? listener,
  ) => log.add('upload:${files.map((f) => f.fileId).join(',')}');

  @override
  void retryAttachment(String batchId, String fileId) =>
      log.add('retry:$fileId');

  @override
  void removeAttachment(String batchId, String fileId) =>
      log.add('remove:$fileId');

  @override
  void clearAll(String batchId) => log.add('clearAll:$batchId');
}

final _att = Attachment('https://cdn/x.png', 'x.png', 'png', 'image/png', 10);

UploadFileView view(
  String id,
  UploadFileState state, {
  String? copy = '/copies/x',
}) => UploadFileView(
  fileId: id,
  name: '$id.png',
  size: 10,
  mimeType: 'image/png',
  state: state,
  attachment: state == UploadFileState.uploaded ? _att : null,
  errorMessage: state == UploadFileState.uploaded ? null : 'no network',
  localCopyPath: copy,
);

UploadFileRequest _restored(_RestoredRepo repo, {int? parent}) =>
    UploadFileRequest.restored(
      repo,
      'u2',
      'user',
      batchId: 'b-u2',
      parentMessageId: parent,
    );

void main() {
  tearDown(() {
    ComposerTrayOffline.resetForTest();
    CometChat.debugSetOfflineEnabledOverride(null);
  });

  group('mapping', () {
    test('restore maps every state: uploaded → done, rejected → rejected, '
        'everything else → failed', () {
      final expected = {
        UploadFileState.uploaded: AttachmentTileStatus.done,
        UploadFileState.rejected: AttachmentTileStatus.rejected,
        UploadFileState.failed: AttachmentTileStatus.failed,
        UploadFileState.queued: AttachmentTileStatus.failed,
        UploadFileState.requestingUrl: AttachmentTileStatus.failed,
        UploadFileState.uploading: AttachmentTileStatus.failed,
        UploadFileState.attached: AttachmentTileStatus.failed,
        UploadFileState.cancelled: AttachmentTileStatus.failed,
      };
      expect(expected.keys.toSet(), UploadFileState.values.toSet());
      expected.forEach((state, status) {
        final tile = ComposerTrayOffline.tileFromRestored(view('f', state));
        expect(tile.status, status, reason: '$state');
        expect(tile.fileId, 'f');
        expect(tile.thumbUrl, '/copies/x');
        expect(
          tile.attachment,
          state == UploadFileState.uploaded ? _att : isNull,
        );
      });
    });

    test('a file whose saved copy is missing is not retryable (D57): '
        'rejected and not saved; every other state maps as before', () {
      for (final state in UploadFileState.values) {
        final tile = ComposerTrayOffline.tileFromRestored(
          view('f', state, copy: null),
        );
        final notSaved =
            state != UploadFileState.uploaded &&
            state != UploadFileState.rejected;
        expect(tile.notSaved, notSaved, reason: '$state');
        expect(
          tile.status,
          state == UploadFileState.uploaded
              ? AttachmentTileStatus.done
              : AttachmentTileStatus.rejected,
          reason: '$state',
        );
        // The tile explains a missing copy itself, never the SDK's text.
        if (notSaved) expect(tile.errorMessage, isNull);
        // With its copy, the same file stays retryable.
        final kept = ComposerTrayOffline.tileFromRestored(view('f', state));
        expect(kept.notSaved, isFalse, reason: '$state');
      }
      // A live tile is never "not saved".
      expect(
        AttachmentTile(
          fileId: 'x',
          name: 'x',
          mimeType: 'a/b',
          size: 1,
        ).notSaved,
        isFalse,
      );
    });

    test('at the file limit a not-saved tile still takes its slot, as the '
        'SDK counts it; a rejected tile does not (D57)', () {
      final max = AttachmentTrayController(
        receiverId: 'u2',
        receiverType: 'user',
      ).maxFileCount;
      final repo = _RestoredRepo([
        for (var i = 0; i < max - 1; i++)
          view('tile_$i', UploadFileState.uploaded),
        view('tile_${max - 1}', UploadFileState.failed, copy: null),
        view('tile_$max', UploadFileState.rejected),
      ]);
      final tray = AttachmentTrayController(
        receiverId: 'u2',
        receiverType: 'user',
      );
      tray.restore(_restored(repo));
      expect(tray.tiles, hasLength(max + 1));
      expect(tray.tiles[max - 1].notSaved, isTrue);
      expect(tray.activeCount, max);
      expect(tray.remainingSlots, 0);
      expect(tray.canAddMore, isFalse);
    });

    test('the batch parent is the thread with offline on, never with off', () {
      expect(ComposerTrayOffline.batchParentId(42, offlineOn: true), 42);
      expect(ComposerTrayOffline.batchParentId(0, offlineOn: true), isNull);
      expect(ComposerTrayOffline.batchParentId(42, offlineOn: false), isNull);
    });

    test('new picks never reuse a restored id', () {
      expect(
        ComposerTrayOffline.nextTileSeq(0, [
          view('tile_3', UploadFileState.failed),
          view('tile_1', UploadFileState.uploaded),
          view('other', UploadFileState.failed),
        ]),
        4,
      );
    });
  });

  group('AttachmentTrayController', () {
    test('restore rebuilds one tile per fileId, in order, and uploads '
        'nothing', () {
      final repo = _RestoredRepo([
        view('tile_0', UploadFileState.uploaded),
        view('tile_1', UploadFileState.failed),
        view('tile_2', UploadFileState.rejected),
      ]);
      final tray = AttachmentTrayController(
        receiverId: 'u2',
        receiverType: 'user',
      );
      expect(tray.restore(_restored(repo)), isTrue);
      expect(tray.tiles.map((t) => t.fileId), ['tile_0', 'tile_1', 'tile_2']);
      expect(tray.tiles.map((t) => t.status), [
        AttachmentTileStatus.done,
        AttachmentTileStatus.failed,
        AttachmentTileStatus.rejected,
      ]);
      expect(tray.batchId, 'b-u2');
      expect(tray.doneAttachments, [_att]);
      expect(repo.log, ['listener:on']);
    });

    test('restore never clobbers a live tray', () async {
      final sdkClient = await registerFakeUploadSdk();
      addTearDown(clearFakeUploadSdk);
      final tray = AttachmentTrayController(
        receiverId: 'u2',
        receiverType: 'user',
      );
      await tray.stage([
        UploadFile(
          name: 'a.png',
          mimeType: 'image/png',
          size: 3,
          path: '/a.png',
        ),
      ]);
      final repo = _RestoredRepo([view('tile_9', UploadFileState.failed)]);
      expect(tray.restore(_restored(repo)), isFalse);
      expect(tray.tiles.map((t) => t.fileId), ['tile_0']);
      expect(repo.log, isEmpty);
      expect(
        sdkClient.repo.log.where((l) => l.startsWith('clearAll')),
        isEmpty,
      );
    });

    test('live retry vs restored retry', () async {
      // Live tile: today's retry (the SDK still holds the picked file).
      final sdkClient = await registerFakeUploadSdk();
      addTearDown(clearFakeUploadSdk);
      final live = AttachmentTrayController(
        receiverId: 'u2',
        receiverType: 'user',
      );
      await live.stage([
        UploadFile(
          name: 'a.png',
          mimeType: 'image/png',
          size: 3,
          path: '/a.png',
        ),
      ]);
      sdkClient.repo.globalListener!.onFileFailure(
        'tile_0',
        CometChatException('ERR_CONNECTION', 'x', 'x'),
      );
      await live.retry('tile_0');
      expect(sdkClient.repo.log, contains('retry:tile_0'));
      expect(live.tiles.single.status, AttachmentTileStatus.uploading);

      // Restored tile: re-uploads from the durable copy (id-based retry);
      // one with no copy cannot be retried: rejected, remove only (D57).
      final repo = _RestoredRepo([
        view('tile_0', UploadFileState.failed),
        view('tile_1', UploadFileState.failed, copy: null),
      ]);
      final tray = AttachmentTrayController(
        receiverId: 'u2',
        receiverType: 'user',
      );
      tray.restore(_restored(repo));
      await tray.retry('tile_0');
      await tray.retry('tile_1');
      expect(repo.log, ['listener:on', 'retry:tile_0']);
      expect(tray.tiles[0].status, AttachmentTileStatus.uploading);
      expect(tray.tiles[1].status, AttachmentTileStatus.rejected);
      expect(tray.tiles[1].notSaved, isTrue);
      // Events for the restored tile reach it.
      repo.globalListener!.onFileUploaded('tile_0', _att);
      expect(tray.tiles[0].status, AttachmentTileStatus.done);
    });

    test('detach empties the tray without destroying the batch; clear '
        'destroys it', () {
      final repo = _RestoredRepo([view('tile_0', UploadFileState.failed)]);
      final tray = AttachmentTrayController(
        receiverId: 'u2',
        receiverType: 'user',
      );
      tray.restore(_restored(repo));
      tray.detach();
      expect(tray.tiles, isEmpty);
      expect(tray.isEmpty, isTrue);
      expect(repo.log, ['listener:on', 'listener:off']);

      final repo2 = _RestoredRepo([view('tile_0', UploadFileState.failed)]);
      final tray2 = AttachmentTrayController(
        receiverId: 'u2',
        receiverType: 'user',
      );
      tray2.restore(_restored(repo2));
      tray2.clear();
      expect(repo2.log, ['listener:on', 'clearAll:b-u2']);
    });

    test('dispose: ON detaches, OFF destroys as today', () {
      CometChat.debugSetOfflineEnabledOverride(true);
      final repo = _RestoredRepo([view('tile_0', UploadFileState.failed)]);
      AttachmentTrayController(receiverId: 'u2', receiverType: 'user')
        ..restore(_restored(repo))
        ..dispose();
      expect(repo.log, ['listener:on', 'listener:off']);

      CometChat.debugSetOfflineEnabledOverride(false);
      final repo2 = _RestoredRepo([view('tile_0', UploadFileState.failed)]);
      AttachmentTrayController(receiverId: 'u2', receiverType: 'user')
        ..restore(_restored(repo2))
        ..dispose();
      expect(repo2.log, ['listener:on', 'clearAll:b-u2']);
    });
  });

  group('ComposerTrayRestorer', () {
    test('runs once per settled triple, on the final triple', () async {
      final lookups = <String>[];
      ComposerTrayOffline.lookup = (id, type, parent) async {
        lookups.add('$type:$id:$parent');
        return null;
      };
      var triple = (id: 'u1', type: 'user', parentMessageId: 0);
      final restorer = ComposerTrayRestorer(
        tray: AttachmentTrayController(),
        tripleOf: () => triple,
        isMounted: () => true,
      );
      triple = (id: 'u2', type: 'user', parentMessageId: 7);
      await restorer.runNow();
      await restorer.runNow();
      expect(lookups, ['user:u2:7']);
      triple = (id: 'u2', type: 'user', parentMessageId: 0);
      await restorer.runNow();
      expect(lookups, ['user:u2:7', 'user:u2:null']);
    });

    test('a request for a triple the chat has left is dropped', () async {
      var triple = (id: 'u2', type: 'user', parentMessageId: 0);
      final repo = _RestoredRepo([view('tile_0', UploadFileState.failed)]);
      ComposerTrayOffline.lookup = (id, type, parent) async {
        triple = (id: 'g1', type: 'group', parentMessageId: 0);
        return _restored(repo);
      };
      final tray = AttachmentTrayController();
      await ComposerTrayRestorer(
        tray: tray,
        tripleOf: () => triple,
        isMounted: () => true,
      ).runNow();
      expect(tray.tiles, isEmpty);
    });

    test('a lookup failure is swallowed', () async {
      ComposerTrayOffline.lookup = (id, type, parent) async =>
          throw StateError('store gone');
      final tray = AttachmentTrayController();
      await ComposerTrayRestorer(
        tray: tray,
        tripleOf: () => (id: 'u2', type: 'user', parentMessageId: 0),
        isMounted: () => true,
      ).runNow();
      expect(tray.tiles, isEmpty);
    });
  });

  group('CometChatMessageComposer', () {
    Widget wrap(Widget child) => MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

    final bob = User(uid: 'u2', name: 'Bob');
    final team = Group(guid: 'g1', name: 'Team', type: 'public');

    testWidgets('a restored file with no saved copy says so and offers remove '
        'only: no Retry, no retryAttachment (D57)', (tester) async {
      UploadFileView pdf(String id, String? copy) => UploadFileView(
        fileId: id,
        name: '$id.pdf',
        size: 10,
        mimeType: 'application/pdf',
        state: UploadFileState.failed,
        errorMessage: 'no network',
        localCopyPath: copy,
      );
      final repo = _RestoredRepo([
        pdf('tile_0', '/copies/0'),
        pdf('tile_1', null),
      ]);
      final tray = AttachmentTrayController(
        receiverId: 'u2',
        receiverType: 'user',
      );
      tray.restore(_restored(repo));
      await tester.pumpWidget(wrap(CometChatAttachmentTray(controller: tray)));
      await tester.pump();

      final en = TranslationsEn();
      // The file with its copy keeps "Tap to retry"; the other says it was
      // not saved.
      expect(find.text(en.tapToRetry), findsOneWidget);
      expect(find.text(en.fileNotSaved), findsOneWidget);

      // Tapping the not-saved tile retries nothing.
      await tester.tap(find.text(en.fileNotSaved));
      await tester.pump();
      expect(repo.log, ['listener:on']);
      expect(tray.tiles[1].status, AttachmentTileStatus.rejected);

      // The retryable one still retries from its copy.
      await tester.tap(find.text(en.tapToRetry));
      await tester.pump();
      expect(repo.log, ['listener:on', 'retry:tile_0']);

      // Remove is offered: the user takes it out and adds the file again.
      await tester.tap(find.bySemanticsLabel(en.remove).last);
      await tester.pump();
      expect(repo.log.last, 'remove:tile_1');
      expect(tray.tiles.map((t) => t.fileId), ['tile_0']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('restores once after the config frame, thread composer '
        'included; a triple change ON looks up the new triple', (tester) async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final lookups = <String>[];
      ComposerTrayOffline.lookup = (id, type, parent) async {
        lookups.add('$type:$id:$parent');
        return null;
      };
      await tester.pumpWidget(
        wrap(CometChatMessageComposer(user: bob, parentMessageId: 42)),
      );
      await tester.pump();
      await tester.pump();
      expect(lookups, ['user:u2:42']);

      await tester.pumpWidget(wrap(CometChatMessageComposer(group: team)));
      await tester.pump();
      await tester.pump();
      expect(lookups, ['user:u2:42', 'group:g1:null']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    Future<void> switchChatAfterRestore(
      WidgetTester tester,
      _RestoredRepo repo,
    ) async {
      ComposerTrayOffline.lookup = (id, type, parent) async =>
          id == 'u2' ? _restored(repo) : null;
      await tester.pumpWidget(wrap(CometChatMessageComposer(user: bob)));
      await tester.pump();
      await tester.pump();
      expect(repo.log, ['listener:on']);
      await tester.pumpWidget(wrap(CometChatMessageComposer(group: team)));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a triple change detaches the batch with offline ON', (
      tester,
    ) async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final repo = _RestoredRepo([view('tile_0', UploadFileState.failed)]);
      await switchChatAfterRestore(tester, repo);
      // Detached, never destroyed: u2's batch stays for its own restore.
      expect(repo.log, ['listener:on', 'listener:off']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(repo.log.where((l) => l.startsWith('clearAll')), isEmpty);
    });

    testWidgets('a triple change destroys the batch with offline OFF, as '
        'today', (tester) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final repo = _RestoredRepo([view('tile_0', UploadFileState.failed)]);
      await switchChatAfterRestore(tester, repo);
      expect(repo.log, ['listener:on', 'clearAll:b-u2']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('OFF: the lookup still runs (the SDK answers null) and '
        'nothing changes', (tester) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final lookups = <String>[];
      ComposerTrayOffline.lookup = (id, type, parent) async {
        lookups.add('$type:$id:$parent');
        return null;
      };
      await tester.pumpWidget(wrap(CometChatMessageComposer(user: bob)));
      await tester.pump();
      await tester.pump();
      expect(lookups, ['user:u2:null']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
