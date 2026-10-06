/// GroupMembersBlocAdapter — the shim that lets legacy templates drive the
/// BLoC through `CometChatGroupMembersControllerProtocol`.
///
/// Every method is a one-line delegation, which is exactly why it is worth
/// pinning: a protocol method wired to the wrong event (or to the wrong
/// lookup) fails silently at runtime. The bloc here is a real
/// [GroupMembersBloc] over a mocked repository with `disableSDKListeners: true`,
/// subclassed only to record what the adapter dispatches.
///
///   flutter test test/chat_ui/group_members/group_members_bloc_adapter_test.dart
library;

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/group_members/bloc/group_members_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/bloc/group_members_bloc_adapter.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/bloc/group_members_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/bloc/group_members_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/domain/repositories/group_members_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/domain/usecases/ban_group_member_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/domain/usecases/get_group_members_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/domain/usecases/kick_group_member_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/domain/usecases/load_more_group_members_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/domain/usecases/update_member_scope_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/data/models/cometchat_group_member_option.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/presentation/theme/colors/cometchat_color_palette.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/presentation/theme/spacing/cometchat_spacing.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/presentation/theme/typography/cometchat_typography.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/presentation/view_models/cometchat_group_members_controller_protocol.dart';

class MockRepo extends Mock implements GroupMembersRepository {}

class FakeMember extends Fake implements GroupMember {
  FakeMember(this._uid, [this._scope = GroupMemberScope.participant]);
  final String _uid;
  final String _scope;
  @override
  String get uid => _uid;
  @override
  String get name => 'Member $_uid';
  @override
  String? get scope => _scope;
  @override
  String? get avatar => null;
  @override
  String? get status => 'offline';
}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'me';
  @override
  String get name => 'Me';
}

class FakeGroup extends Fake implements Group {
  @override
  String get guid => 'g1';
  @override
  String get name => 'G1';
  @override
  String get owner => 'me';
  @override
  String get scope => GroupMemberScope.admin;
  int _count = 5;
  @override
  int get membersCount => _count;
  @override
  set membersCount(int value) => _count = value;
}

class FakeConversation extends Fake implements Conversation {
  @override
  String? get conversationId => 'group_g1';
}

/// Records every event the adapter dispatches while still running the real
/// handlers.
class SpyBloc extends GroupMembersBloc {
  SpyBloc(MockRepo repo, {Group? group})
    : super(
        group: group ?? FakeGroup(),
        getGroupMembersUseCase: GetGroupMembersUseCase(repo),
        loadMoreGroupMembersUseCase: LoadMoreGroupMembersUseCase(repo),
        kickGroupMemberUseCase: KickGroupMemberUseCase(repo),
        banGroupMemberUseCase: BanGroupMemberUseCase(repo),
        updateMemberScopeUseCase: UpdateMemberScopeUseCase(repo),
        getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
        repository: repo,
        disableSDKListeners: true,
      );

  final List<GroupMembersEvent> dispatched = [];

  /// When set, [getDefaultOptions] returns this instead of the real defaults —
  /// the only way to exercise the adapter's `onClick` rewrapping, since
  /// `DetailUtils` never attaches one.
  List<CometChatGroupMemberOption>? optionsOverride;

  @override
  void add(GroupMembersEvent event) {
    dispatched.add(event);
    super.add(event);
  }

  @override
  List<CometChatGroupMemberOption> getDefaultOptions(
    GroupMember member,
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    return optionsOverride ??
        super.getDefaultOptions(
          member,
          context,
          colorPalette,
          typography,
          spacing,
        );
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeMember('fallback'));
    registerFallbackValue(FakeGroup());
  });

  late MockRepo repo;
  late List<GroupMember> page;

  setUp(() {
    page = [FakeMember('a'), FakeMember('b'), FakeMember('c')];
    repo = MockRepo();
    when(() => repo.resetPagination()).thenReturn(null);
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(FakeUser()));
    when(
      () => repo.getConversation(any()),
    ).thenAnswer((_) async => Success(FakeConversation()));
    when(
      () => repo.getGroupMembers(
        guid: any(named: 'guid'),
        limit: any(named: 'limit'),
        searchKeyword: any(named: 'searchKeyword'),
      ),
    ).thenAnswer((_) async => Success(page));
  });

  /// Builds an adapter over a seeded, loaded bloc and hands both to [body]
  /// with a live, localized BuildContext.
  Future<void> withAdapter(
    WidgetTester tester,
    Future<void> Function(
      SpyBloc bloc,
      GroupMembersBlocAdapter adapter,
      BuildContext context,
    )
    body, {
    bool seed = true,
    Group? group,
  }) async {
    final bloc = SpyBloc(repo, group: group);
    addTearDown(() => tester.runAsync(bloc.close));

    if (seed) {
      bloc.add(const LoadGroupMembers());
      await tester.pump(const Duration(milliseconds: 50));
      bloc.dispatched.clear();
    }

    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: Translations.supportedLocales,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final adapter = GroupMembersBlocAdapter(bloc: bloc, context: captured);
    await body(bloc, adapter, captured);
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('getList exposes the loaded members and [] otherwise', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      expect(bloc.state, isA<GroupMembersLoaded>());
      expect(
        adapter.getList(),
        same((bloc.state as GroupMembersLoaded).members),
      );
      expect(adapter.getList().map((m) => m.uid), ['a', 'b', 'c']);
    });

    // Not-yet-loaded blocs must yield an empty list, not throw.
    await withAdapter(tester, (bloc, adapter, _) async {
      expect(bloc.state, isA<GroupMembersInitial>());
      expect(adapter.getList(), isEmpty);
    }, seed: false);
  });

  testWidgets('onSearch dispatches SearchGroupMembers with the raw keyword', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      adapter.onSearch('  bob  ');
      expect(bloc.dispatched.single, isA<SearchGroupMembers>());
      expect(
        (bloc.dispatched.single as SearchGroupMembers).keyword,
        '  bob  ',
        reason: "trimming is the bloc handler's job, not the adapter's",
      );

      // Let the 300ms debounce fire so the search actually reaches the repo.
      await tester.pump(const Duration(milliseconds: 400));
      final captured = verify(
        () => repo.getGroupMembers(
          guid: any(named: 'guid'),
          limit: any(named: 'limit'),
          searchKeyword: captureAny(named: 'searchKeyword'),
        ),
      ).captured;
      expect(captured.last, 'bob');
    });
  });

  testWidgets('loadMoreElements dispatches LoadMoreGroupMembers', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      adapter.loadMoreElements();
      expect(bloc.dispatched.single, isA<LoadMoreGroupMembers>());
    });
  });

  testWidgets('match compares uids, not identity', (tester) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      expect(adapter.match(FakeMember('a'), FakeMember('a')), isTrue);
      expect(adapter.match(FakeMember('a'), FakeMember('b')), isFalse);
    }, seed: false);
  });

  testWidgets('index lookups fall back to -1 when nothing matches', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      expect(adapter.getMatchingIndex(FakeMember('a')), 0);
      expect(adapter.getMatchingIndex(FakeMember('c')), 2);
      expect(adapter.getMatchingIndex(FakeMember('zzz')), -1);

      expect(adapter.getMatchingIndexFromKey('b'), 1);
      expect(adapter.getMatchingIndexFromKey('zzz'), -1);
      // An empty key short-circuits in the bloc and must not read index 0.
      expect(adapter.getMatchingIndexFromKey(''), -1);
    });
  });

  testWidgets('updateElement dispatches UpdateMember carrying the element', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      final updated = FakeMember('b', GroupMemberScope.admin);
      adapter.updateElement(updated);
      expect(bloc.dispatched.first, isA<UpdateMember>());
      expect((bloc.dispatched.first as UpdateMember).member, same(updated));

      await tester.pump(const Duration(milliseconds: 50));
      final members = (bloc.state as GroupMembersLoaded).members;
      expect(members[1].scope, GroupMemberScope.admin);
      expect(members.length, 3, reason: 'update must not grow the list');
    });
  });

  testWidgets('addElement appends through the bloc list, not an event', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      adapter.addElement(FakeMember('d'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(adapter.getList().map((m) => m.uid), ['a', 'b', 'c', 'd']);
      expect(adapter.getMatchingIndexFromKey('d'), 3);
    });
  });

  testWidgets('removeElement drops the member it is handed', (tester) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      adapter.removeElement(page[1]);
      await tester.pump(const Duration(milliseconds: 50));

      expect(adapter.getList().map((m) => m.uid), ['a', 'c']);
    });
  });

  testWidgets('removeElementAt only fires for an in-range index', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      adapter.removeElementAt(-1);
      adapter.removeElementAt(3);
      await tester.pump(const Duration(milliseconds: 50));
      expect(adapter.getList().map((m) => m.uid), [
        'a',
        'b',
        'c',
      ], reason: 'out of range is a no-op');

      adapter.removeElementAt(0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(adapter.getList().map((m) => m.uid), ['b', 'c']);
    });
  });

  testWidgets('removeElementAt is inert while the state is not loaded', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      expect(bloc.state, isA<GroupMembersInitial>());
      adapter.removeElementAt(0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(bloc.dispatched, isEmpty);
      expect(bloc.state, isA<GroupMembersInitial>());
    }, seed: false);
  });

  testWidgets('updateContext is a documented no-op', (tester) async {
    await withAdapter(tester, (bloc, adapter, context) async {
      adapter.updateContext(context);
      expect(bloc.dispatched, isEmpty);
    }, seed: false);
  });

  // --------------------------------------------------------------------
  // defaultFunction
  // --------------------------------------------------------------------

  testWidgets('defaultFunction maps the bloc options onto CometChatOption', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, context) async {
      final group = FakeGroup();

      final options = adapter.defaultFunction(
        group,
        FakeMember('a'),
        context,
        CometChatColorPalette(),
        const CometChatTypography(),
        CometChatSpacing(),
      );

      // The owner ('me') sees all three default options on a participant.
      expect(options.map((o) => o.id), [
        GroupMemberOptionConstants.changeScope,
        GroupMemberOptionConstants.ban,
        GroupMemberOptionConstants.kick,
      ]);
      expect(options.map((o) => o.title), everyElement(isNotEmpty));
      expect(
        options.every((o) => o.onClick == null),
        isTrue,
        reason: 'DetailUtils attaches no handlers, so none survive the map',
      );
    }, seed: false);
  });

  testWidgets('defaultFunction rewraps onClick with (group, member, this)', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, context) async {
      final captured = <Object?>[];
      bloc.optionsOverride = [
        CometChatGroupMemberOption(
          id: 'with_click',
          title: 'With click',
          icon: 'icon.png',
          packageName: 'pkg',
          backgroundColor: const Color(0xFF112233),
          titleStyle: const TextStyle(fontSize: 21),
          onClick: (g, m, state) => captured.addAll([g, m, state]),
        ),
        CometChatGroupMemberOption(id: 'no_click', title: 'No click'),
      ];

      final group = FakeGroup();
      final member = FakeMember('a');
      final options = adapter.defaultFunction(
        group,
        member,
        context,
        CometChatColorPalette(),
        const CometChatTypography(),
        CometChatSpacing(),
      );

      expect(options, hasLength(2));
      // Every field is carried across.
      expect(options[0].id, 'with_click');
      expect(options[0].title, 'With click');
      expect(options[0].icon, 'icon.png');
      expect(options[0].packageName, 'pkg');
      expect(options[0].backgroundColor, const Color(0xFF112233));
      expect(options[0].titleStyle?.fontSize, 21);
      expect(options[1].onClick, isNull);

      // The wrapper takes no arguments but must supply all three.
      options[0].onClick!();
      expect(captured, [same(group), same(member), same(adapter)]);
      expect(
        captured[2],
        isA<CometChatGroupMembersControllerProtocol>(),
        reason: 'the adapter hands itself in as the controller',
      );
    }, seed: false);
  });
}
