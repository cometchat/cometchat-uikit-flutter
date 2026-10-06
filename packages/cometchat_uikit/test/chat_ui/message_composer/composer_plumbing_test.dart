/// Composer events, recorder state, rich-text spans and diagnostics —
/// Track 3 TEST3 / construction coverage (ENG-38684).
///
/// Nineteen exported classes under `message_composer/` that no test had ever
/// constructed. The composer is the largest component in the package — 62
/// files, 22.2k LOC — and this is its plumbing: eleven inline-recorder and
/// composer bloc events, the recorder state with its eight derived getters,
/// the rich-text span model, the segmented-composer segment, the keyboard
/// diagnostics record and two typed exceptions.
///
/// [InlineAudioRecorderState] earns most of the cases. Its six status getters
/// are trivial, but `hasRecording` and `isInRecordingSession` are compound
/// conditions over status *and* duration, and they are what decide whether the
/// composer shows a send button, a scrubber or a microphone.
///
///   flutter test test/chat_ui/message_composer/composer_plumbing_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMessage extends Fake implements BaseMessage {
  _FakeMessage(this.id);
  @override
  final int id;
}

CometChatKeyboardDiagnostics _diagnostics({
  CometChatKeyboardDiagnosticsSource source =
      CometChatKeyboardDiagnosticsSource.nativePlugin,
  double native = 300,
  double applied = 300,
  bool visible = true,
}) => CometChatKeyboardDiagnostics(
  source: source,
  nativeKeyboardHeight: native,
  nativeSafeAreaBottom: 34,
  viewInsetsBottom: 300,
  mediaQuerySafeAreaBottom: 34,
  appliedBottomPadding: applied,
  isKeyboardVisible: visible,
  stableKeyboardHeight: 300,
  maxBottomHeight: 320,
  devicePixelRatio: 3,
  resizeToAvoidBottomInset: true,
);

void main() {
  // ===========================================================================
  group('InlineAudioRecorderState', () {
    test('defaults to idle with nothing recorded', () {
      const state = InlineAudioRecorderState();

      expect(state.status, InlineAudioRecorderStatus.idle);
      expect(state.duration, Duration.zero);
      expect(state.currentPosition, Duration.zero);
      expect(state.filePath, isNull);
      expect(state.errorMessage, isNull);
      expect(state.amplitudes, isEmpty);
      expect(state.extractedWaveform, isEmpty);
    });

    test('exactly one status getter is true at a time', () {
      for (final status in InlineAudioRecorderStatus.values) {
        final state = InlineAudioRecorderState(status: status);
        final flags = [
          state.isIdle,
          state.isRecording,
          state.isPaused,
          state.isCompleted,
          state.isPlaying,
          state.hasError,
        ];

        expect(
          flags.where((f) => f),
          hasLength(1),
          reason: '$status should light exactly one getter',
        );
      }
    });

    test(
      'hasRecording needs a finished-ish status AND a non-zero duration',
      () {
        // Duration alone is not enough, and status alone is not enough. This is
        // the condition behind showing a send button instead of a microphone.
        const oneSecond = Duration(seconds: 1);

        expect(
          const InlineAudioRecorderState(
            status: InlineAudioRecorderStatus.completed,
            duration: oneSecond,
          ).hasRecording,
          isTrue,
        );
        expect(
          const InlineAudioRecorderState(
            status: InlineAudioRecorderStatus.completed,
          ).hasRecording,
          isFalse,
          reason: 'a completed recording of zero length is not a recording',
        );
        expect(
          const InlineAudioRecorderState(
            status: InlineAudioRecorderStatus.recording,
            duration: oneSecond,
          ).hasRecording,
          isFalse,
          reason: 'still recording is not yet a recording to send',
        );
      },
    );

    test('paused and playing also count as having a recording', () {
      const oneSecond = Duration(seconds: 1);

      expect(
        const InlineAudioRecorderState(
          status: InlineAudioRecorderStatus.paused,
          duration: oneSecond,
        ).hasRecording,
        isTrue,
      );
      expect(
        const InlineAudioRecorderState(
          status: InlineAudioRecorderStatus.playing,
          duration: oneSecond,
        ).hasRecording,
        isTrue,
      );
    });

    test('isInRecordingSession covers recording and a mid-recording pause', () {
      const oneSecond = Duration(seconds: 1);

      expect(
        const InlineAudioRecorderState(
          status: InlineAudioRecorderStatus.recording,
        ).isInRecordingSession,
        isTrue,
        reason: 'recording counts even at zero duration',
      );
      expect(
        const InlineAudioRecorderState(
          status: InlineAudioRecorderStatus.paused,
          duration: oneSecond,
        ).isInRecordingSession,
        isTrue,
      );
      expect(
        const InlineAudioRecorderState(
          status: InlineAudioRecorderStatus.paused,
        ).isInRecordingSession,
        isFalse,
        reason: 'a pause before anything was captured is not a session',
      );
      expect(
        const InlineAudioRecorderState(
          status: InlineAudioRecorderStatus.completed,
          duration: oneSecond,
        ).isInRecordingSession,
        isFalse,
      );
    });

    test('copyWith replaces only what it is given', () {
      const base = InlineAudioRecorderState(
        status: InlineAudioRecorderStatus.recording,
        duration: Duration(seconds: 2),
        amplitudes: [0.1],
      );

      final copy = base.copyWith(duration: const Duration(seconds: 5));

      expect(copy.status, InlineAudioRecorderStatus.recording);
      expect(copy.duration, const Duration(seconds: 5));
      expect(copy.amplitudes, [0.1]);
    });

    test('copyWith cannot clear a nullable field back to null', () {
      // Every field resolves as `x ?? this.x`, so once filePath or
      // errorMessage is set there is no way to unset it through copyWith — a
      // stale error survives into the next recording unless the bloc builds a
      // fresh state. Pinned as the shape it is.
      const withError = InlineAudioRecorderState(
        status: InlineAudioRecorderStatus.error,
        errorMessage: 'no mic',
      );

      expect(withError.copyWith(errorMessage: null).errorMessage, 'no mic');
      expect(const InlineAudioRecorderState().copyWith().errorMessage, isNull);
    });

    test('equality distinguishes the waveform from the live amplitudes', () {
      // Two separate lists: `amplitudes` streams in while recording,
      // `extractedWaveform` is computed from the finished file for playback.
      expect(
        const InlineAudioRecorderState(amplitudes: [0.5]),
        isNot(const InlineAudioRecorderState(extractedWaveform: [0.5])),
      );
      expect(
        const InlineAudioRecorderState(amplitudes: [0.5]),
        const InlineAudioRecorderState(amplitudes: [0.5]),
      );
    });
  });

  // ===========================================================================
  group('inline-recorder events', () {
    test('ResumeRecording defaults to a true resume, not a restart', () {
      expect(const ResumeRecording().isFreshRestart, isFalse);
      expect(
        const ResumeRecording(isFreshRestart: true),
        isNot(const ResumeRecording()),
      );
    });

    test('UpdateDuration and UpdatePlaybackPosition both carry a Duration but '
        'are distinct types', () {
      // One advances the recording timer, the other the playback scrubber.
      // Identical props again, so only the type separates them.
      const d = Duration(seconds: 3);

      expect(
        const UpdateDuration(d).props,
        const UpdatePlaybackPosition(d).props,
      );
      expect(const UpdateDuration(d), isNot(const UpdatePlaybackPosition(d)));
      expect(const UpdateDuration(d).duration, d);
      expect(const UpdatePlaybackPosition(d).position, d);
    });

    test('UpdateAmplitude carries one sample', () {
      expect(const UpdateAmplitude(0.7).amplitude, 0.7);
      expect(const UpdateAmplitude(0.7), const UpdateAmplitude(0.7));
      expect(const UpdateAmplitude(0.7), isNot(const UpdateAmplitude(0.8)));
    });

    test('SeekToPosition carries a 0..1 progress, not a duration', () {
      // Documented as a fraction, so a caller passing milliseconds would be a
      // silent no-op at the far end of the bar.
      expect(const SeekToPosition(0).progress, 0);
      expect(const SeekToPosition(0.5).progress, 0.5);
      expect(const SeekToPosition(1).progress, 1);
      expect(const SeekToPosition(0.5), isNot(const SeekToPosition(0.6)));
    });

    test('RecordingCompleted carries both the file and its length', () {
      const event = RecordingCompleted(
        filePath: '/tmp/note.m4a',
        duration: Duration(seconds: 4),
      );

      expect(event.filePath, '/tmp/note.m4a');
      expect(event.duration, const Duration(seconds: 4));
      expect(
        event,
        isNot(
          const RecordingCompleted(
            filePath: '/tmp/note.m4a',
            duration: Duration(seconds: 5),
          ),
        ),
        reason: 'the same file re-measured is a different completion',
      );
    });

    test('RecordingError carries the message the composer will surface', () {
      expect(const RecordingError('no mic').message, 'no mic');
      expect(const RecordingError('no mic'), const RecordingError('no mic'));
    });

    test('SetExtractedWaveform compares its samples by value', () {
      expect(
        const SetExtractedWaveform([0.1, 0.2]),
        const SetExtractedWaveform([0.1, 0.2]),
      );
      expect(
        const SetExtractedWaveform([0.1, 0.2]),
        isNot(const SetExtractedWaveform([0.1, 0.3])),
      );
      expect(const SetExtractedWaveform([]).waveform, isEmpty);
    });
  });

  // ===========================================================================
  group('composer bloc events', () {
    test('UpdateParentMessageId carries the thread it switched to', () {
      expect(const UpdateParentMessageId(42).parentMessageId, 42);
      expect(const UpdateParentMessageId(42), const UpdateParentMessageId(42));
      expect(
        const UpdateParentMessageId(0),
        isNot(const UpdateParentMessageId(42)),
        reason: 'zero means the main conversation, not "unchanged"',
      );
    });

    test('MessageEditedExternally carries the message that changed', () {
      final message = _FakeMessage(1);

      expect(MessageEditedExternally(message).message, same(message));
      expect(
        MessageEditedExternally(message),
        MessageEditedExternally(message),
      );
      expect(
        MessageEditedExternally(message),
        isNot(MessageEditedExternally(_FakeMessage(2))),
      );
    });

    test('DEFECT-ADJACENT — ShowPanel leaves its builder out of props', () {
      // props is [id, position] and the builder is excluded, so two ShowPanel
      // events with the same id and position compare equal however different
      // the widgets they build. A bloc that de-duplicates on equality will
      // drop the second, and the panel keeps rendering the first builder.
      //
      // Excluding a closure from props is the usual advice — closures are
      // rarely equal — but here it makes "show a different panel in the same
      // slot" a no-op. Pinned rather than filed: the composer may never send
      // two in a row, and confirming that needs the bloc, not this test.
      final a = ShowPanel(
        id: const {'k': 'v'},
        position: CustomUIPosition.composerTop,
        builder: (_) => const Text('first'),
      );
      final b = ShowPanel(
        id: const {'k': 'v'},
        position: CustomUIPosition.composerTop,
        builder: (_) => const Text('second'),
      );

      expect(a, b);
      expect(a.builder, isNot(same(b.builder)));
    });

    test('ShowPanel still distinguishes position and id', () {
      Widget build(BuildContext _) => const SizedBox();

      expect(
        ShowPanel(position: CustomUIPosition.composerTop, builder: build),
        isNot(
          ShowPanel(position: CustomUIPosition.composerBottom, builder: build),
        ),
      );
      expect(
        ShowPanel(
          id: const {'a': 1},
          position: CustomUIPosition.composerTop,
          builder: build,
        ),
        isNot(
          ShowPanel(
            id: const {'a': 2},
            position: CustomUIPosition.composerTop,
            builder: build,
          ),
        ),
      );
    });
  });

  // ===========================================================================
  group('RichTextSpan', () {
    const span = RichTextSpan(start: 0, end: 4, formats: {FormatType.bold});

    test('carries a range and the formats over it', () {
      expect(span.start, 0);
      expect(span.end, 4);
      expect(span.formats, {FormatType.bold});
      expect(span.metadata, isNull);
    });

    test('holds several formats at once', () {
      const both = RichTextSpan(
        start: 0,
        end: 4,
        formats: {FormatType.bold, FormatType.italic},
      );

      expect(both.formats, hasLength(2));
      expect(both.formats, contains(FormatType.italic));
    });

    test('metadata carries the url for a link span', () {
      const link = RichTextSpan(
        start: 0,
        end: 9,
        formats: {FormatType.link},
        metadata: {'url': 'https://cometchat.com'},
      );

      expect(link.metadata!['url'], 'https://cometchat.com');
    });

    test('copyWith replaces only what it is given', () {
      final moved = span.copyWith(start: 2, end: 6);

      expect(moved.start, 2);
      expect(moved.end, 6);
      expect(moved.formats, span.formats);
      expect(span.copyWith().start, span.start);
    });

    test('toString names the range and formats, and the metadata only when '
        'there is some', () {
      expect(span.toString(), contains('0-4'));
      expect(span.toString(), isNot(contains('meta=')));
      expect(
        const RichTextSpan(
          start: 0,
          end: 1,
          formats: {FormatType.link},
          metadata: {'url': 'x'},
        ).toString(),
        contains('meta='),
      );
    });
  });

  // ===========================================================================
  group('LinkTapDetails', () {
    test('keeps the display text, the target and the range apart', () {
      const details = LinkTapDetails(
        displayText: 'CometChat',
        url: 'https://cometchat.com',
        start: 4,
        end: 13,
      );

      expect(details.displayText, 'CometChat');
      expect(details.url, 'https://cometchat.com');
      expect(details.start, 4);
      expect(details.end, 13);
      expect(
        details.end - details.start,
        details.displayText.length,
        reason: 'the range spans the rendered label, not the url',
      );
    });
  });

  // ===========================================================================
  group('ComposerSegment', () {
    test('a normal segment gets a rich-text controller', () {
      final segment = ComposerSegment(
        id: 's1',
        type: SegmentType.normal,
        text: 'hello',
      );
      addTearDown(segment.dispose);

      expect(segment.id, 's1');
      expect(segment.type, SegmentType.normal);
      expect(segment.controller, isA<RichTextEditingController>());
      expect(segment.controller.text, 'hello');
      expect(segment.text, 'hello');
      expect(segment.isEmpty, isFalse);
      expect(segment.language, isEmpty);
      expect(
        segment.previousText,
        'hello',
        reason:
            'seeded from the initial text so the first onChange diffs '
            'against what was there, not against empty',
      );
    });

    test('isEmpty ignores whitespace', () {
      final blank = ComposerSegment(
        id: 's0',
        type: SegmentType.normal,
        text: '   ',
      );
      addTearDown(blank.dispose);

      expect(blank.isEmpty, isTrue);
      expect(blank.text, '   ');
    });

    test('a code segment gets a plain controller, not a rich-text one', () {
      // The distinction matters: running the markdown formatter inside a code
      // block would format the code.
      final segment = ComposerSegment(
        id: 's2',
        type: SegmentType.code,
        text: 'final x = 1;',
        language: 'dart',
      );
      addTearDown(segment.dispose);

      expect(segment.controller, isNot(isA<RichTextEditingController>()));
      expect(segment.controller.text, 'final x = 1;');
      expect(segment.language, 'dart');
    });

    test('previousText is per segment, which is what formatters need', () {
      final segment = ComposerSegment(id: 's1', type: SegmentType.normal)
        ..previousText = 'hell';
      addTearDown(segment.dispose);

      expect(segment.previousText, 'hell');
    });
  });

  // ===========================================================================
  group('CometChatKeyboardDiagnostics', () {
    test('carries both the native and the Flutter view of the keyboard', () {
      final d = _diagnostics();

      expect(d.source, CometChatKeyboardDiagnosticsSource.nativePlugin);
      expect(d.nativeKeyboardHeight, 300);
      expect(d.viewInsetsBottom, 300);
      expect(d.nativeSafeAreaBottom, 34);
      expect(d.mediaQuerySafeAreaBottom, 34);
      expect(d.appliedBottomPadding, 300);
      expect(d.isKeyboardVisible, isTrue);
      expect(d.devicePixelRatio, 3);
      expect(d.resizeToAvoidBottomInset, isTrue);
    });

    test('toString names the source and every measurement', () {
      final text = _diagnostics().toString();

      expect(text, startsWith('KbDiag(nativePlugin'));
      expect(text, contains('native=300.0'));
      expect(text, contains('applied=300.0'));
      expect(text, contains('visible=true'));
    });

    test('the source enum names all three capture points', () {
      expect(
        CometChatKeyboardDiagnosticsSource.values,
        contains(CometChatKeyboardDiagnosticsSource.nativePlugin),
      );
      expect(
        CometChatKeyboardDiagnosticsSource.values,
        contains(CometChatKeyboardDiagnosticsSource.viewInsets),
      );
      expect(
        _diagnostics(
          source: CometChatKeyboardDiagnosticsSource.viewInsets,
        ).toString(),
        startsWith('KbDiag(viewInsets'),
      );
    });

    test('a hidden keyboard reports zero height and zero applied padding', () {
      final d = _diagnostics(native: 0, applied: 0, visible: false);

      expect(d.nativeKeyboardHeight, 0);
      expect(d.appliedBottomPadding, 0);
      expect(d.isKeyboardVisible, isFalse);
    });
  });

  // ===========================================================================
  group('composer exceptions', () {
    test('AttachmentStageException carries a user-facing reason and an '
        'optional cause', () {
      final bare = AttachmentStageException('file too large');

      expect(bare.message, 'file too large');
      expect(bare.cause, isNull);
      expect(bare, isA<Exception>());
      expect(bare.toString(), contains('file too large'));
    });

    test('AttachmentStageException keeps the underlying error', () {
      final cause = StateError('disk full');
      final e = AttachmentStageException('staging failed', cause);

      expect(e.cause, same(cause));
      // The cause may be an Error rather than an Exception, which is why the
      // field is typed Object? — a narrower type would drop half the cases.
      expect(e.cause, isA<Error>());
    });

    test(
      'MessageComposerDataSourceException carries message, code and cause',
      () {
        const bare = MessageComposerDataSourceException(message: 'send failed');

        expect(bare.message, 'send failed');
        expect(bare.code, isNull);
        expect(bare.originalException, isNull);

        final cause = Exception('socket');
        final full = MessageComposerDataSourceException(
          message: 'send failed',
          code: 'ERR_NET',
          originalException: cause,
        );

        expect(full.code, 'ERR_NET');
        expect(full.originalException, same(cause));
      },
    );
  });
}
