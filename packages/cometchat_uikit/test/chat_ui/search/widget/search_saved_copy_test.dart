// ENG-41484 (D-323), BEH-MEDIA-18: search result thumbnails use the copy saved
// on the phone — the attachment's `localPath`, else the SDK's cache — and
// with offline off they use the link as before.

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_video_player_platform.dart';
import '../../../helpers/media_file_harness.dart';

class _MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

const _imageUrl = 'https://media.test/a.png?sig=1';
const _videoUrl = 'https://media.test/v.mp4?sig=1';

final _me = User(uid: 'u-me', name: 'Me');
final _bob = User(uid: 'u-bob', name: 'Bob Smith');

MediaMessage _media(String type, Attachment attachment, {int id = 2}) =>
    MediaMessage(
      id: id,
      type: type,
      sender: _bob,
      receiver: _me,
      receiverUid: 'u-me',
      receiverType: ReceiverTypeConstants.user,
      category: MessageCategoryConstants.message,
      sentAt: DateTime(2026, 3, 14, 9, 30),
      attachments: [attachment],
    );

SearchState _state(BaseMessage message) => SearchState(
  searchText: 'pas',
  scope: SearchScope.messages,
  showConversations: false,
  showMessages: true,
  messagesStatus: SearchStatus.loaded,
  messages: [message],
);

_MockSearchBloc _bloc(SearchState state) {
  final bloc = _MockSearchBloc();
  when(() => bloc.state).thenReturn(state);
  when(() => bloc.isClosed).thenReturn(false);
  whenListen(bloc, Stream<SearchState>.value(state), initialState: state);
  return bloc;
}

String? _filePath(ImageProvider p) {
  if (p is ResizeImage) return _filePath(p.imageProvider);
  if (p is FileImage) return p.file.path;
  return null;
}

Finder _frameFrom(String source) => find.byWidgetPredicate(
  (w) => w is CometChatVideoFirstFrame && w.source == source,
);

void main() {
  final hub = OfflineHub.instance;
  final lookups = <String>[];
  late Directory dir;
  String? cached;

  setUp(() {
    installFakeVideoPlayerPlatform();
    dir = createMediaTempDir();
    CometChatUIKit.loggedInUser = _me;
    hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    hub.debugLoginSuccess('me');
    lookups.clear();
    cached = null;
    OfflineMedia.debugCachedMediaPath = (m) async {
      lookups.add((m as MediaMessage).attachment!.fileUrl);
      return cached;
    };
  });

  tearDown(() {
    CometChatUIKit.loggedInUser = null;
    CometChat.debugSetOfflineEnabledOverride(null);
    OfflineMedia.debugCachedMediaPath = null;
    disposeMediaTempDir(dir);
  });

  Future<void> pumpSearch(WidgetTester tester, BaseMessage message) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: CometChatSearch(searchBloc: _bloc(_state(message))),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('an image hit shows the SDK-cached copy', (tester) async {
    cached = writeImageFile(dir, 'a.bmp');
    await pumpSearch(
      tester,
      _media(
        MessageTypeConstants.image,
        Attachment(_imageUrl, 'a.png', 'png', 'image/png', 10),
      ),
    );

    expect(lookups, contains(_imageUrl));
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any((i) => _filePath(i.image) == cached),
      isTrue,
    );
  });

  testWidgets('a video hit takes its first frame from the saved copy', (
    tester,
  ) async {
    final path = writeRawFile(dir, 'v.mp4', const [1, 2, 3]);
    await pumpSearch(
      tester,
      _media(
        MessageTypeConstants.video,
        Attachment(_videoUrl, 'v.mp4', 'mp4', 'video/mp4', 10, localPath: path),
      ),
    );

    expect(_frameFrom(path), findsOneWidget);
    expect(_frameFrom(_videoUrl), findsNothing);
  });

  testWidgets('a video hit finds a copy only the SDK cache knows', (
    tester,
  ) async {
    cached = writeRawFile(dir, 'v.mp4', const [1, 2, 3]);
    await pumpSearch(
      tester,
      _media(
        MessageTypeConstants.video,
        Attachment(_videoUrl, 'v.mp4', 'mp4', 'video/mp4', 10),
      ),
    );

    expect(_frameFrom(cached!), findsOneWidget);
  });

  testWidgets('a row reused for another video hit swaps the frame source', (
    tester,
  ) async {
    final first = writeRawFile(dir, 'v1.mp4', const [1, 2, 3]);
    final second = writeRawFile(dir, 'v2.mp4', const [4, 5, 6]);
    final a = _state(
      _media(
        MessageTypeConstants.video,
        Attachment(
          _videoUrl,
          'v1.mp4',
          'mp4',
          'video/mp4',
          10,
          localPath: first,
        ),
      ),
    );
    final b = _state(
      _media(
        MessageTypeConstants.video,
        Attachment(
          '$_videoUrl&2',
          'v2.mp4',
          'mp4',
          'video/mp4',
          10,
          localPath: second,
        ),
        id: 3,
      ),
    );
    final states = StreamController<SearchState>();
    final bloc = _MockSearchBloc();
    when(() => bloc.isClosed).thenReturn(false);
    whenListen(bloc, states.stream, initialState: a);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: CometChatSearch(searchBloc: bloc),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_frameFrom(first), findsOneWidget);

    // The same index now holds another result.
    states.add(b);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_frameFrom(second), findsOneWidget);
    expect(_frameFrom(first), findsNothing);
    await states.close();
  });

  testWidgets('offline off: the link\'s first frame, no lookup', (
    tester,
  ) async {
    CometChat.debugSetOfflineEnabledOverride(false);
    final path = writeRawFile(dir, 'v.mp4', const [1, 2, 3]);
    await pumpSearch(
      tester,
      _media(
        MessageTypeConstants.video,
        Attachment(_videoUrl, 'v.mp4', 'mp4', 'video/mp4', 10, localPath: path),
      ),
    );

    expect(_frameFrom(_videoUrl), findsOneWidget);
    expect(_frameFrom(path), findsNothing);
    expect(lookups, isEmpty);
  });
}
