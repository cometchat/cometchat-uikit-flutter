import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../../../../../shared_ui/src/logging/cometchat_log.dart';

/// Web-based audio recorder using the browser's MediaRecorder API directly.
///
/// This avoids the `record` package entirely on web, eliminating the
/// `record_linux` / `record_platform_interface` version mismatch issues.
/// Uses `package:web` + `dart:js_interop` for browser API access
/// (WASM-compatible; replaces the legacy `dart:html` / `dart:web_audio` libs).
class WebAudioRecorder {
  static final WebAudioRecorder _instance = WebAudioRecorder._internal();
  factory WebAudioRecorder() => _instance;
  WebAudioRecorder._internal();

  web.MediaRecorder? _mediaRecorder;
  web.MediaStream? _mediaStream;
  // Web Audio API for amplitude metering
  web.AudioContext? _audioContext;
  web.AnalyserNode? _analyserNode;
  final List<web.Blob> _chunks = [];
  String? _recordedBlobUrl;
  Uint8List? _recordedBytes;
  bool _isRecording = false;
  bool _isPaused = false;

  /// Stream controller for amplitude updates
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  Timer? _amplitudeTimer;

  /// Stream of amplitude values (0.0 to 1.0) during recording
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Whether recording is currently active
  bool get isRecording => _isRecording;

  /// Start recording audio
  /// Returns true if recording started successfully
  Future<bool> startRecording() async {
    try {
      // Request microphone access
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(audio: true.toJS, video: false.toJS),
          )
          .toDart;
      _mediaStream = stream;

      // Set up AudioContext + AnalyserNode for amplitude metering
      try {
        final audioContext = web.AudioContext();
        _audioContext = audioContext;
        final analyserNode = audioContext.createAnalyser();
        analyserNode.fftSize = 256;
        _analyserNode = analyserNode;

        // Create media stream source and connect to analyser
        final source = audioContext.createMediaStreamSource(stream);
        source.connect(analyserNode);
      } catch (e) {
        ccLog('[WebAudioRecorder] Could not set up amplitude metering: $e');
        // Continue without amplitude — recording still works
        _audioContext = null;
        _analyserNode = null;
      }

      // Create MediaRecorder
      _chunks.clear();
      _recordedBlobUrl = null;
      _recordedBytes = null;

      // Try opus first, fall back to webm
      final mimeType =
          web.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
          ? 'audio/webm;codecs=opus'
          : 'audio/webm';

      final recorder = web.MediaRecorder(
        stream,
        web.MediaRecorderOptions(mimeType: mimeType),
      );
      _mediaRecorder = recorder;

      // Listen for data chunks
      recorder.addEventListener(
        'dataavailable',
        (web.Event event) {
          final blobEvent = event as web.BlobEvent;
          final data = blobEvent.data;
          if (data.size > 0) {
            _chunks.add(data);
          }
        }.toJS,
      );

      // Start recording with 250ms timeslice for regular data events
      recorder.start(250);
      _isRecording = true;
      _isPaused = false;

      // Start amplitude polling
      _startAmplitudePolling();

      ccLog('[WebAudioRecorder] Recording started (mimeType: $mimeType)');
      return true;
    } catch (e) {
      ccLog('[WebAudioRecorder] Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording and return the recorded audio as bytes
  Future<RecordingResult?> stopRecording() async {
    final recorder = _mediaRecorder;
    if (recorder == null) return null;

    try {
      _stopAmplitudePolling();

      // Create a completer to wait for the final data
      final completer = Completer<void>();

      recorder.addEventListener(
        'stop',
        (web.Event event) {
          if (!completer.isCompleted) completer.complete();
        }.toJS,
      );

      recorder.stop();
      _isRecording = false;
      _isPaused = false;

      // Wait for onstop event (ensures all data chunks are collected)
      await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );

      if (_chunks.isEmpty) {
        ccLog('[WebAudioRecorder] No audio chunks recorded');
        return null;
      }

      // Create blob from chunks
      final blob = web.Blob(
        _chunks.toJS,
        web.BlobPropertyBag(type: recorder.mimeType),
      );

      // Create blob URL
      _recordedBlobUrl = web.URL.createObjectURL(blob);
      ccLog(
        '[WebAudioRecorder] Recording stopped, blob size: ${blob.size}, url: $_recordedBlobUrl',
      );

      // Read blob as bytes for upload
      Uint8List? bytes;
      try {
        final arrayBuffer = await blob.arrayBuffer().toDart;
        bytes = arrayBuffer.toDart.asUint8List();
        if (bytes.isNotEmpty) {
          ccLog('[WebAudioRecorder] Read ${bytes.length} bytes from blob');
        }
      } catch (e) {
        ccLog('[WebAudioRecorder] Could not read blob bytes: $e');
      }

      _recordedBytes = bytes;

      // Clean up media stream tracks
      _stopMediaStream();

      return RecordingResult(path: _recordedBlobUrl!, bytes: bytes);
    } catch (e) {
      ccLog('[WebAudioRecorder] Error stopping recording: $e');
      return null;
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    final recorder = _mediaRecorder;
    if (recorder == null || !_isRecording) return;
    try {
      recorder.pause();
      _isPaused = true;
      _stopAmplitudePolling();
      ccLog('[WebAudioRecorder] Recording paused');
    } catch (e) {
      ccLog('[WebAudioRecorder] Error pausing: $e');
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    final recorder = _mediaRecorder;
    if (recorder == null || !_isPaused) return;
    try {
      recorder.resume();
      _isPaused = false;
      _startAmplitudePolling();
      ccLog('[WebAudioRecorder] Recording resumed');
    } catch (e) {
      ccLog('[WebAudioRecorder] Error resuming: $e');
    }
  }

  /// Release all resources
  Future<void> dispose() async {
    _stopAmplitudePolling();

    final recorder = _mediaRecorder;
    if (recorder != null) {
      try {
        if (_isRecording || _isPaused) {
          recorder.stop();
        }
      } catch (_) {}
    }

    _stopMediaStream();
    _closeAudioContext();

    _mediaRecorder = null;
    _isRecording = false;
    _isPaused = false;
    _chunks.clear();

    // Close the amplitude stream controller to prevent memory leaks
    unawaited(_amplitudeController.close());

    // Revoke blob URL to free memory
    if (_recordedBlobUrl != null) {
      try {
        web.URL.revokeObjectURL(_recordedBlobUrl!);
      } catch (_) {}
      _recordedBlobUrl = null;
    }
    _recordedBytes = null;
  }

  /// Get the last recorded blob URL
  String? get recordedBlobUrl => _recordedBlobUrl;

  /// Get the last recorded bytes (populated after stopRecording)
  Uint8List? get recordedBytes => _recordedBytes;

  void _stopMediaStream() {
    final stream = _mediaStream;
    if (stream != null) {
      final tracks = stream.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
      _mediaStream = null;
    }
  }

  void _closeAudioContext() {
    final ctx = _audioContext;
    if (ctx != null) {
      try {
        ctx.close();
      } catch (_) {}
      _audioContext = null;
      _analyserNode = null;
    }
  }

  void _startAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final analyser = _analyserNode;
      if (analyser == null || !_isRecording || _isPaused) return;
      try {
        final bufferLength = analyser.frequencyBinCount;
        // `getByteTimeDomainData` requires a JSUint8Array; allocate a Dart
        // buffer, hand the JS view to the native call, then read it back.
        final jsArray = Uint8List(bufferLength).toJS;
        analyser.getByteTimeDomainData(jsArray);
        final dataArray = jsArray.toDart;

        // Calculate RMS amplitude from time domain data
        double sum = 0;
        for (int i = 0; i < bufferLength; i++) {
          final sample = (dataArray[i] - 128) / 128.0;
          sum += sample * sample;
        }
        final rms = (sum / bufferLength);
        // Normalize to 0.0-1.0 range with some amplification
        final normalized = (rms * 4.0).clamp(0.0, 1.0);

        if (!_amplitudeController.isClosed) {
          _amplitudeController.add(normalized);
        }
      } catch (_) {}
    });
  }

  void _stopAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
  }
}

/// Result of a recording session
class RecordingResult {
  /// On web: blob URL. On native: file path.
  final String path;

  /// Raw bytes of the recording (populated on web after reading blob)
  final Uint8List? bytes;

  RecordingResult({required this.path, this.bytes});
}
