/// Behaviour tests for the clean-architecture domain entities and the
/// exception hierarchy — `group_entity.dart`, `user_entity.dart`,
/// `exceptions.dart`, and the two service entities under `services/`.
///
/// All five are pure Dart with no SDK and no widgets, and all five were at
/// zero line coverage. The parts worth pinning are the same in each: the
/// `copyWith` fall-throughs (one mis-wired `??` silently corrupts a field),
/// the derived getters and their empty/null edges, and — for `GroupEntity` —
/// the two membership operations, which are the only entity methods in the
/// layer that compute anything.
///
///   flutter test test/shared_ui/clean_architecture/domain_entities_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

const GroupEntity _group = GroupEntity(
  id: 'g1',
  name: 'Team',
  icon: 'https://example.test/g.png',
  description: 'the team',
  owner: 'u1',
  memberCount: 2,
  members: ['u1', 'u2'],
  metadata: {'k': 'v'},
  type: 'private',
);

const UserEntity _user = UserEntity(
  id: 'u1',
  name: 'Alice',
  avatar: 'https://example.test/a.png',
  status: 'available',
  isOnline: true,
  lastActive: 1788787200000,
  statusMessage: 'in a meeting',
  metadata: {'k': 'v'},
);

void main() {
  // ==========================================================================
  group('GroupEntity', () {
    test('the documented defaults apply when the optionals are omitted', () {
      const g = GroupEntity(id: 'g', name: 'G', owner: 'u1');
      expect(g.icon, isNull);
      expect(g.description, isNull);
      expect(g.metadata, isNull);
      expect(g.memberCount, 0);
      expect(g.members, isEmpty);
      expect(g.type, 'public');
    });

    test('copyWith with no arguments is an equal copy', () {
      expect(_group.copyWith(), _group);
      expect(identical(_group.copyWith(), _group), isFalse);
    });

    test('copyWith changes only the field it is given', () {
      // Each row: the copy, and the constructor-built value it must equal.
      final cases = <String, List<GroupEntity>>{
        'id': [_group.copyWith(id: 'g2'), _groupWith(id: 'g2')],
        'name': [_group.copyWith(name: 'Squad'), _groupWith(name: 'Squad')],
        'icon': [_group.copyWith(icon: 'b.png'), _groupWith(icon: 'b.png')],
        'description': [
          _group.copyWith(description: 'other'),
          _groupWith(description: 'other'),
        ],
        'owner': [_group.copyWith(owner: 'u9'), _groupWith(owner: 'u9')],
        'memberCount': [
          _group.copyWith(memberCount: 7),
          _groupWith(memberCount: 7),
        ],
        'members': [
          _group.copyWith(members: const ['u9']),
          _groupWith(members: const ['u9']),
        ],
        'metadata': [
          _group.copyWith(metadata: const {'k2': 2}),
          _groupWith(metadata: const {'k2': 2}),
        ],
        'type': [_group.copyWith(type: 'public'), _groupWith(type: 'public')],
      };
      cases.forEach((field, pair) {
        expect(pair[0], pair[1], reason: field);
      });
    });

    test('props covers every field', () {
      expect(_group.props.length, 9);
      for (final changed in [
        _group.copyWith(id: 'x'),
        _group.copyWith(name: 'x'),
        _group.copyWith(icon: 'x'),
        _group.copyWith(description: 'x'),
        _group.copyWith(owner: 'x'),
        _group.copyWith(memberCount: 99),
        _group.copyWith(members: const ['x']),
        _group.copyWith(metadata: const {'x': 1}),
        _group.copyWith(type: 'public'),
      ]) {
        expect(changed, isNot(_group));
      }
    });

    test('hasIcon needs a non-null, non-empty url', () {
      expect(_group.hasIcon, isTrue);
      expect(_group.copyWith(icon: '').hasIcon, isFalse);
      expect(
        const GroupEntity(id: 'g', name: 'G', owner: 'u').hasIcon,
        isFalse,
      );
    });

    test('isPublic and isPrivate read the type string', () {
      expect(_group.isPrivate, isTrue);
      expect(_group.isPublic, isFalse);
      expect(_group.copyWith(type: 'public').isPublic, isTrue);
      // Anything else is neither — password-protected groups, for instance.
      final other = _group.copyWith(type: 'password');
      expect(other.isPublic, isFalse);
      expect(other.isPrivate, isFalse);
    });

    test('isMember is membership, not ownership', () {
      expect(_group.isMember('u2'), isTrue);
      expect(_group.isMember('u9'), isFalse);
      // The owner is in the list here; an owner absent from it is not a member.
      expect(_group.copyWith(members: const ['u2']).isMember('u1'), isFalse);
    });

    test('addMember appends and bumps the count', () {
      final grown = _group.addMember('u3');
      expect(grown.members, ['u1', 'u2', 'u3']);
      expect(grown.memberCount, 3);
      // ...and leaves the original alone.
      expect(_group.members, ['u1', 'u2']);
      expect(_group.memberCount, 2);
    });

    test('addMember is a no-op for someone already in the group', () {
      final same = _group.addMember('u2');
      expect(identical(same, _group), isTrue);
      expect(same.memberCount, 2);
    });

    test('removeMember drops the id and decrements the count', () {
      final shrunk = _group.removeMember('u1');
      expect(shrunk.members, ['u2']);
      expect(shrunk.memberCount, 1);
      expect(_group.members, ['u1', 'u2'], reason: 'the original is untouched');
    });

    test('removeMember is a no-op for someone who is not in the group', () {
      expect(identical(_group.removeMember('u9'), _group), isTrue);
    });

    test('removeMember never drives the count below zero', () {
      // A stale count (fewer than the list says) must not go negative.
      const inconsistent = GroupEntity(
        id: 'g1',
        name: 'Team',
        owner: 'u1',
        memberCount: 0,
        members: ['u1'],
      );
      expect(inconsistent.removeMember('u1').memberCount, 0);
    });

    test('add then remove round-trips', () {
      expect(_group.addMember('u3').removeMember('u3'), _group);
    });
  });

  // ==========================================================================
  group('UserEntity', () {
    test('the documented defaults apply when the optionals are omitted', () {
      const u = UserEntity(id: 'u', name: 'U');
      expect(u.avatar, isNull);
      expect(u.status, isNull);
      expect(u.lastActive, isNull);
      expect(u.statusMessage, isNull);
      expect(u.metadata, isNull);
      expect(u.isOnline, isFalse);
    });

    test('copyWith with no arguments is an equal copy', () {
      expect(_user.copyWith(), _user);
      expect(identical(_user.copyWith(), _user), isFalse);
    });

    test('copyWith changes only the field it is given', () {
      final cases = <String, List<UserEntity>>{
        'id': [_user.copyWith(id: 'u9'), _userWith(id: 'u9')],
        'name': [_user.copyWith(name: 'Zoe'), _userWith(name: 'Zoe')],
        'avatar': [_user.copyWith(avatar: 'b.png'), _userWith(avatar: 'b.png')],
        'status': [_user.copyWith(status: 'away'), _userWith(status: 'away')],
        'isOnline': [
          _user.copyWith(isOnline: false),
          _userWith(isOnline: false),
        ],
        'lastActive': [
          _user.copyWith(lastActive: 42),
          _userWith(lastActive: 42),
        ],
        'statusMessage': [
          _user.copyWith(statusMessage: 'brb'),
          _userWith(statusMessage: 'brb'),
        ],
        'metadata': [
          _user.copyWith(metadata: const {'k2': 2}),
          _userWith(metadata: const {'k2': 2}),
        ],
      };
      cases.forEach((field, pair) {
        expect(pair[0], pair[1], reason: field);
      });
    });

    test('props covers every field', () {
      expect(_user.props.length, 8);
      for (final changed in [
        _user.copyWith(id: 'x'),
        _user.copyWith(name: 'x'),
        _user.copyWith(avatar: 'x'),
        _user.copyWith(status: 'x'),
        _user.copyWith(isOnline: false),
        _user.copyWith(lastActive: 99),
        _user.copyWith(statusMessage: 'x'),
        _user.copyWith(metadata: const {'x': 1}),
      ]) {
        expect(changed, isNot(_user));
      }
    });

    test('hasAvatar needs a non-null, non-empty url', () {
      expect(_user.hasAvatar, isTrue);
      expect(_user.copyWith(avatar: '').hasAvatar, isFalse);
      expect(const UserEntity(id: 'u', name: 'U').hasAvatar, isFalse);
    });

    group('statusDisplay', () {
      // Every case is expressed relative to "now" at the moment of the call,
      // so nothing here depends on the wall clock landing anywhere special.
      UserEntity offlineSince(Duration ago) => _user.copyWith(
        isOnline: false,
        lastActive: DateTime.now().millisecondsSinceEpoch - ago.inMilliseconds,
      );

      test('online beats every last-seen value', () {
        expect(_user.statusDisplay, 'Online');
        expect(
          _user.copyWith(isOnline: true, lastActive: 0).statusDisplay,
          'Online',
        );
      });

      test('under a minute reads as active now', () {
        expect(offlineSince(Duration.zero).statusDisplay, 'Active now');
        expect(
          offlineSince(const Duration(seconds: 59)).statusDisplay,
          'Active now',
        );
      });

      test('under an hour counts whole minutes', () {
        expect(
          offlineSince(const Duration(minutes: 5)).statusDisplay,
          'Active 5 min ago',
        );
        expect(
          offlineSince(const Duration(minutes: 59)).statusDisplay,
          'Active 59 min ago',
        );
        // The boundary: exactly a minute is no longer "now".
        expect(
          offlineSince(const Duration(minutes: 1)).statusDisplay,
          'Active 1 min ago',
        );
      });

      test('under a day counts whole hours', () {
        expect(
          offlineSince(const Duration(hours: 1)).statusDisplay,
          'Active 1 h ago',
        );
        expect(
          offlineSince(const Duration(hours: 23)).statusDisplay,
          'Active 23 h ago',
        );
      });

      test('a day or more, or no last-seen at all, reads as offline', () {
        expect(
          offlineSince(const Duration(hours: 24)).statusDisplay,
          'Offline',
        );
        expect(offlineSince(const Duration(days: 30)).statusDisplay, 'Offline');
        expect(const UserEntity(id: 'u', name: 'U').statusDisplay, 'Offline');
      });

      test('a future last-seen is not reported as a huge age', () {
        // A clock-skewed server timestamp gives a negative difference, which
        // is below every threshold and so reads as "active now".
        expect(
          _user
              .copyWith(
                isOnline: false,
                lastActive:
                    DateTime.now().millisecondsSinceEpoch +
                    const Duration(hours: 5).inMilliseconds,
              )
              .statusDisplay,
          'Active now',
        );
      });
    });
  });

  // ==========================================================================
  group('AppException hierarchy', () {
    test('each subclass prints its own name and message', () {
      expect(
        RemoteException(message: 'boom').toString(),
        'RemoteException: boom',
      );
      expect(
        LocalException(message: 'boom').toString(),
        'LocalException: boom',
      );
      expect(
        ValidationException(message: 'boom').toString(),
        'ValidationException: boom',
      );
      expect(
        UnknownException(message: 'boom').toString(),
        'UnknownException: boom',
      );
    });

    test('the subclasses carry code and original exception through', () {
      final cause = StateError('root cause');
      final e = RemoteException(
        message: 'boom',
        code: 'E42',
        originalException: cause,
      );
      expect(e.message, 'boom');
      expect(e.code, 'E42');
      expect(e.originalException, same(cause));
    });

    test('the base toString names the code, the subclasses do not', () {
      // Only the base class formats the code, so a caller logging a subclass
      // loses it unless it reads `.code`.
      final base = _BareException(message: 'boom', code: 'E42');
      expect(base.toString(), 'AppException: boom (code: E42)');
      expect(
        RemoteException(message: 'boom', code: 'E42').toString(),
        isNot(contains('E42')),
      );
    });

    test('every subclass is an AppException and an Exception', () {
      for (final e in <AppException>[
        RemoteException(message: 'm'),
        LocalException(message: 'm'),
        ValidationException(message: 'm'),
        UnknownException(message: 'm'),
      ]) {
        expect(e, isA<Exception>());
        expect(e.code, isNull);
        expect(e.originalException, isNull);
      }
    });

    test('the subclasses are distinguishable by type, not just by text', () {
      // Callers switch on these, so they must not collapse onto each other.
      expect(RemoteException(message: 'm'), isNot(isA<LocalException>()));
      expect(ValidationException(message: 'm'), isNot(isA<UnknownException>()));
    });
  });

  // ==========================================================================
  group('StreamEntity', () {
    final created = DateTime(2026, 9, 8, 10);
    StreamEntity base() => StreamEntity(
      id: 's1',
      name: 'Podcast',
      url: 'https://example.test/s.mp3',
      isPlaying: true,
      duration: const Duration(minutes: 30),
      position: const Duration(minutes: 5),
      createdAt: created,
    );

    test('copyWith with no arguments keeps every field', () {
      final copy = base().copyWith();
      expect(copy.id, 's1');
      expect(copy.name, 'Podcast');
      expect(copy.url, 'https://example.test/s.mp3');
      expect(copy.isPlaying, isTrue);
      expect(copy.duration, const Duration(minutes: 30));
      expect(copy.position, const Duration(minutes: 5));
      expect(copy.createdAt, created);
    });

    test('copyWith changes only the field it is given', () {
      final other = DateTime(2020, 1, 1);
      expect(base().copyWith(id: 's2').id, 's2');
      expect(base().copyWith(id: 's2').name, 'Podcast');
      expect(base().copyWith(name: 'Radio').name, 'Radio');
      expect(base().copyWith(url: 'https://x/y').url, 'https://x/y');
      expect(base().copyWith(isPlaying: false).isPlaying, isFalse);
      expect(
        base().copyWith(duration: const Duration(hours: 1)).duration,
        const Duration(hours: 1),
      );
      expect(base().copyWith(position: Duration.zero).position, Duration.zero);
      expect(base().copyWith(createdAt: other).createdAt, other);
      // Nothing else moved with the last of those.
      expect(
        base().copyWith(createdAt: other).position,
        const Duration(minutes: 5),
      );
    });

    test('toString names every field', () {
      final s = base().toString();
      for (final fragment in ['s1', 'Podcast', 'example.test', 'true']) {
        expect(s, contains(fragment), reason: fragment);
      }
    });
  });

  // ==========================================================================
  group('StreamStatusUpdate', () {
    StreamStatusUpdate at(StreamPlaybackStatus status) => StreamStatusUpdate(
      status: status,
      position: const Duration(seconds: 3),
      duration: const Duration(seconds: 30),
      bufferedPosition: const Duration(seconds: 10),
    );

    test('each predicate is true for exactly one status', () {
      expect(
        StreamPlaybackStatus.values.where((s) => at(s).isPlaying).toList(),
        [StreamPlaybackStatus.playing],
      );
      expect(
        StreamPlaybackStatus.values.where((s) => at(s).isPaused).toList(),
        [StreamPlaybackStatus.paused],
      );
      expect(
        StreamPlaybackStatus.values.where((s) => at(s).isCompleted).toList(),
        [StreamPlaybackStatus.completed],
      );
      expect(
        StreamPlaybackStatus.values.where((s) => at(s).hasError).toList(),
        [StreamPlaybackStatus.error],
      );
    });

    test('errorMessage is optional and defaults to null', () {
      expect(at(StreamPlaybackStatus.error).errorMessage, isNull);
      expect(
        StreamStatusUpdate(
          status: StreamPlaybackStatus.error,
          position: Duration.zero,
          duration: Duration.zero,
          bufferedPosition: Duration.zero,
          errorMessage: 'network lost',
        ).errorMessage,
        'network lost',
      );
    });

    test('toString names the status and all three positions', () {
      final s = at(StreamPlaybackStatus.playing).toString();
      expect(s, contains('playing'));
      expect(s, contains('0:00:03'));
      expect(s, contains('0:00:30'));
      expect(s, contains('0:00:10'));
    });
  });

  // ==========================================================================
  group('AudioStateEntity', () {
    AudioStateEntity base() => AudioStateEntity(
      id: 7,
      audioUrl: 'https://example.test/a.m4a',
      localPath: '/tmp/a.m4a',
      playState: PlayState.playing,
      currentPosition: const Duration(seconds: 3),
      totalDuration: const Duration(seconds: 30),
      isInitializing: false,
      errorMessage: 'none',
    );

    test('copyWith with no arguments keeps every field', () {
      final copy = base().copyWith();
      expect(copy.id, 7);
      expect(copy.audioUrl, 'https://example.test/a.m4a');
      expect(copy.localPath, '/tmp/a.m4a');
      expect(copy.playState, PlayState.playing);
      expect(copy.currentPosition, const Duration(seconds: 3));
      expect(copy.totalDuration, const Duration(seconds: 30));
      expect(copy.isInitializing, isFalse);
      expect(copy.errorMessage, 'none');
    });

    test('copyWith changes only the field it is given', () {
      expect(base().copyWith(id: 9).id, 9);
      expect(base().copyWith(id: 9).playState, PlayState.playing);
      expect(base().copyWith(audioUrl: 'x').audioUrl, 'x');
      expect(base().copyWith(localPath: 'y').localPath, 'y');
      expect(
        base().copyWith(playState: PlayState.paused).playState,
        PlayState.paused,
      );
      expect(
        base().copyWith(currentPosition: Duration.zero).currentPosition,
        Duration.zero,
      );
      expect(
        base().copyWith(totalDuration: Duration.zero).totalDuration,
        Duration.zero,
      );
      expect(base().copyWith(isInitializing: true).isInitializing, isTrue);
      expect(base().copyWith(errorMessage: 'boom').errorMessage, 'boom');
    });

    test('copyWith cannot clear a nullable field', () {
      // `??` again: passing null keeps what was there. Pinned because the
      // error message is the field a caller would most want to clear.
      expect(base().copyWith(errorMessage: null).errorMessage, 'none');
      expect(base().copyWith(audioUrl: null).audioUrl, isNotNull);
    });

    test('toString names the id, state and both positions', () {
      final s = base().toString();
      expect(s, contains('id: 7'));
      expect(s, contains('PlayState.playing'));
      expect(s, contains('0:00:03'));
      expect(s, contains('0:00:30'));
    });
  });

  // ==========================================================================
  group('AudioStateUpdateEntity', () {
    test('carries the id and state, with optional positions', () {
      final e = AudioStateUpdateEntity(audioId: 7, state: PlayState.paused);
      expect(e.audioId, 7);
      expect(e.state, PlayState.paused);
      expect(e.currentPosition, isNull);
      expect(e.totalDuration, isNull);
      expect(e.errorMessage, isNull);
    });

    test('toString names the id, state and position', () {
      final s = AudioStateUpdateEntity(
        audioId: 7,
        state: PlayState.error,
        currentPosition: const Duration(seconds: 4),
        errorMessage: 'decode failed',
      ).toString();
      expect(s, contains('id: 7'));
      expect(s, contains('PlayState.error'));
      expect(s, contains('0:00:04'));
    });

    test('PlayState covers the whole lifecycle exactly once', () {
      expect(PlayState.values, const [
        PlayState.init,
        PlayState.loading,
        PlayState.playing,
        PlayState.paused,
        PlayState.stopped,
        PlayState.error,
      ]);
    });
  });
}

/// A direct AppException, to reach the base `toString` the subclasses hide.
class _BareException extends AppException {
  _BareException({required super.message, super.code});
}

GroupEntity _groupWith({
  String id = 'g1',
  String name = 'Team',
  String? icon = 'https://example.test/g.png',
  String? description = 'the team',
  String owner = 'u1',
  int memberCount = 2,
  List<String> members = const ['u1', 'u2'],
  Map<String, dynamic>? metadata = const {'k': 'v'},
  String type = 'private',
}) => GroupEntity(
  id: id,
  name: name,
  icon: icon,
  description: description,
  owner: owner,
  memberCount: memberCount,
  members: members,
  metadata: metadata,
  type: type,
);

UserEntity _userWith({
  String id = 'u1',
  String name = 'Alice',
  String? avatar = 'https://example.test/a.png',
  String? status = 'available',
  bool isOnline = true,
  int? lastActive = 1788787200000,
  String? statusMessage = 'in a meeting',
  Map<String, dynamic>? metadata = const {'k': 'v'},
}) => UserEntity(
  id: id,
  name: name,
  avatar: avatar,
  status: status,
  isOnline: isOnline,
  lastActive: lastActive,
  statusMessage: statusMessage,
  metadata: metadata,
);
