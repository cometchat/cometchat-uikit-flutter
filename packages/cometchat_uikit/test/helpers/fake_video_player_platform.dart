/// A scriptable [VideoPlayerPlatform] for the audio / video bubbles.
///
/// `video_player` has no platform implementation in a VM test — the default
/// instance is the package's own placeholder, whose `init()` throws
/// `UnimplementedError`. That makes every playback path in the Kit collapse
/// onto the same "failed to initialize" branch, so the play/pause/seek state
/// machines can never be driven.
///
/// Installing this fake as `VideoPlayerPlatform.instance` gives those paths a
/// player that answers: `initialize()` completes, `play()`/`pause()`/`seekTo()`
/// are recorded, and end-of-media can be pushed with [completePlayback]. Every
/// call is appended to [log] so tests can assert on the calls the widget made,
/// not only on what it painted.
library;

import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
// video_player does not re-export the platform interface, and the interface is
// the only seam for faking playback. It is a resolved (transitive) dependency,
// not a new one.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Installs a fresh [FakeVideoPlayerPlatform] and returns it.
///
/// Call from `setUp`. There is no way to restore the original instance (the
/// setter has no un-set), which is fine: the placeholder is inert and every
/// test that cares installs its own.
FakeVideoPlayerPlatform installFakeVideoPlayerPlatform({
  Duration duration = const Duration(seconds: 30),
}) {
  final fake = FakeVideoPlayerPlatform(duration: duration);
  VideoPlayerPlatform.instance = fake;
  return fake;
}

/// A [VideoPlayerPlatform] that records calls and can be told how to behave.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  /// Creates a fake whose players report [duration] once initialized.
  FakeVideoPlayerPlatform({this.duration = const Duration(seconds: 30)});

  /// Duration reported in the `initialized` event of every player created.
  Duration duration;

  /// When true, `createWithOptions` throws — the "player could not be built"
  /// failure the Kit catches and turns into an error / idle state.
  bool failCreate = false;

  /// When true, a player is created but never emits `initialized`, so
  /// `initialize()` hangs. Drives the Kit's init timeout.
  bool hangInitialize = false;

  /// When true, the `initialized` event carries no duration. `video_player`
  /// then completes `initialize()` with `isInitialized` still false — the
  /// "opened but unusable media" case (an unsupported codec on a real device).
  bool initializeWithoutDuration = false;

  /// When true, `play()` throws — a player that initialized but cannot start.
  bool failPlay = false;

  /// Ordered log of every platform call, e.g. `create:https://a/b.mp3`,
  /// `play:1`, `pause:1`, `seek:1:0:00:05.000000`, `dispose:1`.
  final List<String> log = <String>[];

  /// Data-source URIs passed to `createWithOptions`, in order.
  final List<String> createdUris = <String>[];

  /// Player ids that are still alive (created and not disposed).
  Iterable<int> get livePlayerIds => _streams.keys;

  int _nextId = 1;
  final Map<int, StreamController<VideoEvent>> _streams =
      <int, StreamController<VideoEvent>>{};
  final Map<int, Duration> _positions = <int, Duration>{};

  /// Pushes an end-of-media event to [playerId] (or to every live player when
  /// omitted), which is what flips `VideoPlayerValue.isCompleted`.
  void completePlayback([int? playerId]) {
    final ids = playerId == null ? _streams.keys.toList() : <int>[playerId];
    for (final id in ids) {
      final c = _streams[id];
      if (c != null && !c.isClosed) {
        c.add(VideoEvent(eventType: VideoEventType.completed));
      }
    }
  }

  @override
  Future<void> init() async {
    log.add('init');
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final uri = options.dataSource.uri ?? options.dataSource.asset ?? '';
    createdUris.add(uri);
    log.add('create:$uri');
    if (failCreate) {
      throw PlatformException(
        code: 'VideoError',
        message: 'fake create failed',
      );
    }
    final id = _nextId++;
    _streams[id] = StreamController<VideoEvent>.broadcast();
    _positions[id] = Duration.zero;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final controller = _streams[playerId];
    if (controller == null) return const Stream<VideoEvent>.empty();
    if (!hangInitialize) {
      // `VideoPlayerController.initialize` subscribes immediately after this
      // returns, so the event has to be deferred by at least a microtask.
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: initializeWithoutDuration ? null : duration,
              size: const Size(640, 480),
            ),
          );
        }
      });
    }
    return controller.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    log.add('dispose:$playerId');
    _positions.remove(playerId);
    await _streams.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    log.add('play:$playerId');
    if (failPlay) {
      throw PlatformException(code: 'VideoError', message: 'fake play failed');
    }
  }

  @override
  Future<void> pause(int playerId) async {
    log.add('pause:$playerId');
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    log.add('seek:$playerId:$position');
    _positions[playerId] = position;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async =>
      _positions[playerId] ?? Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {
    log.add('mixWithOthers:$mixWithOthers');
  }

  @override
  // Fills its slot and takes hit tests (a bare SizedBox does neither), so a
  // test can tap "the video surface" the way a user would.
  Widget buildView(int playerId) =>
      const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand());
}
