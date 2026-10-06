import 'dart:async';
import 'dart:typed_data';

/// Stub implementation of WebAudioRecorder for non-web platforms.
/// This file is used via conditional import — on web, the real
/// dart:html-based implementation is loaded instead.
class WebAudioRecorder {
  static final WebAudioRecorder _instance = WebAudioRecorder._internal();
  factory WebAudioRecorder() => _instance;
  WebAudioRecorder._internal();

  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  Stream<double> get amplitudeStream => _amplitudeController.stream;
  bool get isRecording => false;

  Future<bool> startRecording() async => false;
  Future<RecordingResult?> stopRecording() async => null;
  Future<void> pauseRecording() async {}
  Future<void> resumeRecording() async {}
  Future<void> dispose() async {
    unawaited(_amplitudeController.close());
  }

  String? get recordedBlobUrl => null;
  Uint8List? get recordedBytes => null;
}

/// Result of a recording session
class RecordingResult {
  /// On web: blob URL. On native: file path.
  final String path;

  /// Raw bytes of the recording (populated on web after reading blob)
  final Uint8List? bytes;

  RecordingResult({required this.path, this.bytes});
}
