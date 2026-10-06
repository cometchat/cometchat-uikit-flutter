/// Who started a looping sound — a ringtone, a ringback — so only they stop
/// it.
///
/// Package-private (see `lib/src/`).
///
/// A call screen's bloc is closed when its route or overlay entry is
/// disposed, and that happens after the next screen has been built: a
/// banner replaced by the next incoming call, or an outgoing screen popping
/// a moment after its call ended while the next call already rings. Its
/// stop used to be global, so it silenced the sound the next screen had
/// just started. Android keeps an audio manager per direction; this goes a
/// little further and matches the stop to the start.
final class SoundLoopOwner {
  /// A loop no one has started yet.
  SoundLoopOwner();

  Object? _owner;

  /// [owner] starts the loop. It is theirs from now on, whoever had it.
  void take(Object owner) => _owner = owner;

  /// Whether [owner] started the loop playing now. It stays theirs.
  bool owns(Object owner) => identical(_owner, owner);

  /// Whether someone started the loop and has not stopped it.
  bool get isTaken => _owner != null;

  /// Whether [owner] started the loop playing now. If so, it is no longer
  /// anyone's: the caller stops it.
  bool release(Object owner) {
    if (!identical(_owner, owner)) return false;
    _owner = null;
    return true;
  }

  /// Forgets the owner (for tests: see `CallTone.debugReset`).
  void reset() => _owner = null;
}

/// The incoming call's ringtone, on a native player of its own: see
/// `IncomingRingtone`.
final SoundLoopOwner incomingRingtoneLoop = SoundLoopOwner();
