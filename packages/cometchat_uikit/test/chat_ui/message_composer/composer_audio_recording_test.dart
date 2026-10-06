/// The composer's inline voice-note mode: entering it swaps the input row for
/// the recorder, cancelling returns to the input, and submitting hands the
/// recording to the BLoC.
///
/// Events are observed through a [BlocObserver] so the exact payload the
/// composer builds is assertable without reaching into the SDK.
///
///   flutter test test/chat_ui/message_composer/composer_audio_recording_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessageComposerRepository {}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'u1';
  @override
  String get name => 'Alice';
  @override
  String? get avatar => null;
  @override
  String get status => 'online';
  @override
  bool get blockedByMe => false;
  @override
  bool get hasBlockedMe => false;
}

/// Records every event every composer BLoC receives.
class _EventSpy extends BlocObserver {
  final List<Object?> events = <Object?>[];

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    events.add(event);
    super.onEvent(bloc, event);
  }
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

void main() {
  late _MockRepo repo;
  late _EventSpy spy;
  late List<MediaMessage> sentMedia;

  setUpAll(() {
    registerFallbackValue(
      MediaMessage(receiverUid: 'u1', receiverType: 'user', type: 'audio'),
    );
  });

  setUp(() {
    sentMedia = <MediaMessage>[];
    repo = _MockRepo();
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(_FakeUser()));
    when(
      () => repo.startTyping(
        receiverUid: any(named: 'receiverUid'),
        receiverType: any(named: 'receiverType'),
      ),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.endTyping(
        receiverUid: any(named: 'receiverUid'),
        receiverType: any(named: 'receiverType'),
      ),
    ).thenAnswer((_) async => const Success(null));
    when(() => repo.sendMediaMessage(any())).thenAnswer((invocation) async {
      final message = invocation.positionalArguments.first as MediaMessage;
      sentMedia.add(message);
      return Success(message);
    });

    MessageComposerServiceLocator.instance.reset();
    MessageComposerServiceLocator.instance.setup(repository: repo);

    spy = _EventSpy();
    Bloc.observer = spy;
  });

  tearDown(() {
    Bloc.observer = _EventSpy();
    MessageComposerServiceLocator.instance.reset();
  });

  /// Pumps the composer and hands back its BLoC.
  Future<MessageComposerBloc> pumpComposer(WidgetTester tester) async {
    late MessageComposerBloc bloc;
    await tester.pumpWidget(
      _wrap(
        CometChatMessageComposer(
          user: _FakeUser(),
          stateCallBack: (b) => bloc = b,
        ),
      ),
    );
    await tester.pump();
    return bloc;
  }

  /// Drains the composer's typing debounce so no timer outlives the tree.
  Future<void> drain(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 5));

  T lastEventOf<T>(List<Object?> events) => events.whereType<T>().last;

  testWidgets('recording mode replaces the input row with the recorder', (
    tester,
  ) async {
    final bloc = await pumpComposer(tester);
    expect(find.byType(EditableText), findsWidgets);
    expect(find.byType(CometChatInlineAudioRecorder), findsNothing);

    bloc.add(const StartAudioRecording());
    await tester.pump();
    await tester.pump();

    expect(find.byType(CometChatInlineAudioRecorder), findsOneWidget);
    expect(
      find.byType(EditableText),
      findsNothing,
      reason: 'the recorder takes the input row over entirely',
    );
    await drain(tester);
  });

  testWidgets('cancelling the recorder returns to the input row', (
    tester,
  ) async {
    final bloc = await pumpComposer(tester);
    bloc.add(const StartAudioRecording());
    await tester.pump();
    await tester.pump();

    tester
        .widget<CometChatInlineAudioRecorder>(
          find.byType(CometChatInlineAudioRecorder),
        )
        .onCancel!();
    await tester.pump();

    expect(spy.events.whereType<CancelAudioRecording>(), hasLength(1));
    expect(find.byType(EditableText), findsWidgets);
    expect(find.byType(CometChatInlineAudioRecorder), findsNothing);
    await drain(tester);
  });

  testWidgets('submitting a recording sends it as a voice note', (
    tester,
  ) async {
    final bloc = await pumpComposer(tester);
    bloc.add(const StartAudioRecording());
    await tester.pump();
    await tester.pump();

    tester
        .widget<CometChatInlineAudioRecorder>(
          find.byType(CometChatInlineAudioRecorder),
        )
        .onSubmit!('/tmp/rec/voice.m4a');
    await tester.pump();

    final submit = lastEventOf<SubmitAudioRecording>(spy.events);
    expect(submit.filePath, '/tmp/rec/voice.m4a');
    expect(submit.fileBytes, isNull);

    // The BLoC turns it into a media send marked as a voice note.
    final send = lastEventOf<SendMediaMessage>(spy.events);
    expect(send.path, '/tmp/rec/voice.m4a');
    expect(send.messageType, MessageTypeConstants.audio);
    expect(send.metadata?['localPath'], '/tmp/rec/voice.m4a');
    expect(
      send.metadata?[CometChatVoiceNoteBubble.audioTypeKey],
      CometChatVoiceNoteBubble.audioTypeVoiceNote,
      reason: 'so it renders as a waveform, not an audio-file row',
    );

    // …and the message that actually goes out carries the same marker.
    await tester.pump();
    expect(sentMedia.single.type, MessageTypeConstants.audio);
    expect(sentMedia.single.file, '/tmp/rec/voice.m4a');
    expect(
      sentMedia.single.metadata?[CometChatVoiceNoteBubble.audioTypeKey],
      CometChatVoiceNoteBubble.audioTypeVoiceNote,
    );

    // The recorder is dismissed either way.
    expect(find.byType(CometChatInlineAudioRecorder), findsNothing);
    await drain(tester);
  });

  testWidgets('the recording is always named audio.webm, even off web', (
    tester,
  ) async {
    final bloc = await pumpComposer(tester);
    bloc.add(const StartAudioRecording());
    await tester.pump();
    await tester.pump();

    tester
        .widget<CometChatInlineAudioRecorder>(
          find.byType(CometChatInlineAudioRecorder),
        )
        .onSubmit!('/tmp/rec/voice.m4a', fileBytes: const [1, 2, 3]);
    await tester.pump();

    // FINDING: the composer hard-codes `fileName: 'audio.webm'` when it builds
    // SubmitAudioRecording. MessageComposerBloc._onSubmitAudioRecording has a
    // platform-aware default right there —
    //   `const defaultFileName = kIsWeb ? 'audio.webm' : 'audio.m4a';`
    // — but it is only used when the event carries no name, so off web it is
    // dead code and a natively recorded `.m4a` is announced as a `.webm`.
    final submit = lastEventOf<SubmitAudioRecording>(spy.events);
    expect(submit.fileName, 'audio.webm');
    expect(submit.filePath, endsWith('.m4a'));
    expect(submit.fileBytes, const [1, 2, 3]);

    final send = lastEventOf<SendMediaMessage>(spy.events);
    expect(
      send.fileName,
      'audio.webm',
      reason: 'the wrong extension rides all the way to the send',
    );
    await drain(tester);
  });
}
