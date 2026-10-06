/// Behaviour tests for DetailUtils — Track 3 TEST3 (ENG-38684).
///
/// `detail_utils.dart` was at zero line coverage, and most of it is the group
/// moderation permission matrix: who may kick, ban, unban or re-scope whom,
/// keyed by the pair (actor scope, target scope). That is a security-shaped
/// question — the wrong cell means a participant gets a Kick button — and
/// nothing exercised it.
///
/// The option builders need a BuildContext only for Translations, so they run
/// inside a pumped widget; the validators are pure and run as plain tests.
///
///   flutter test test/shared_ui/utils/detail_utils_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a tree and hands the context to [body].
Future<void> withContext(
  WidgetTester tester,
  void Function(BuildContext) body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) {
          body(context);
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pump();
}

const _participant = GroupMemberScope.participant;
const _moderator = GroupMemberScope.moderator;
const _admin = GroupMemberScope.admin;
const _owner = GroupMemberScope.owner;

/// Convenience over the pair-keyed matrix.
dynamic can(String actor, String target, String option) =>
    DetailUtils.validateGroupMemberOptions(
      loggedInUserScope: actor,
      memberScope: target,
      optionId: option,
    );

void main() {
  // -------------------------------------------------------------------------
  // The moderation matrix. Each cell is keyed by actor+target.
  // -------------------------------------------------------------------------
  group('validateGroupMemberOptions', () {
    test('a participant may do nothing to anyone', () {
      for (final target in [_participant, _moderator, _admin, _owner]) {
        expect(
          can(_participant, target, GroupMemberOptionConstants.kick),
          isFalse,
          reason: 'kick $target',
        );
        expect(
          can(_participant, target, GroupMemberOptionConstants.ban),
          isFalse,
          reason: 'ban $target',
        );
        expect(
          can(_participant, target, GroupMemberOptionConstants.unban),
          isFalse,
          reason: 'unban $target',
        );
        expect(
          can(_participant, target, GroupMemberOptionConstants.changeScope),
          isEmpty,
          reason: 'rescope $target',
        );
      }
    });

    test('a moderator may act on participants only', () {
      expect(
        can(_moderator, _participant, GroupMemberOptionConstants.kick),
        isTrue,
      );
      expect(
        can(_moderator, _participant, GroupMemberOptionConstants.ban),
        isTrue,
      );
      for (final target in [_moderator, _admin, _owner]) {
        expect(
          can(_moderator, target, GroupMemberOptionConstants.kick),
          isFalse,
          reason: 'moderator must not kick $target',
        );
      }
    });

    test(
      'a moderator may re-scope a participant to participant or moderator',
      () {
        final scopes =
            can(
                  _moderator,
                  _participant,
                  GroupMemberOptionConstants.changeScope,
                )
                as List;
        expect(scopes, containsAll([_participant, _moderator]));
        expect(
          scopes,
          isNot(contains(_admin)),
          reason: 'a moderator must not promote to admin',
        );
        expect(scopes, isNot(contains(_owner)));
      },
    );

    test('nobody may act on the owner', () {
      for (final actor in [_participant, _moderator, _admin, _owner]) {
        expect(
          can(actor, _owner, GroupMemberOptionConstants.kick),
          isFalse,
          reason: '$actor must not kick the owner',
        );
        expect(
          can(actor, _owner, GroupMemberOptionConstants.ban),
          isFalse,
          reason: '$actor must not ban the owner',
        );
      }
    });

    test('no scope may act on its own equal — moderator on moderator', () {
      expect(
        can(_moderator, _moderator, GroupMemberOptionConstants.kick),
        isFalse,
      );
      expect(
        can(_moderator, _moderator, GroupMemberOptionConstants.ban),
        isFalse,
      );
    });

    test(
      'an unknown scope pair yields null rather than a permissive default',
      () {
        // The lookup is a plain map read, so a scope the matrix does not know
        // returns null. Callers must not treat that as permission.
        expect(
          can('bogus', 'alsoBogus', GroupMemberOptionConstants.kick),
          isNull,
        );
      },
    );

    test('memberScope defaults to participant', () {
      expect(
        DetailUtils.validateGroupMemberOptions(
          loggedInUserScope: _moderator,
          optionId: GroupMemberOptionConstants.kick,
        ),
        can(_moderator, _participant, GroupMemberOptionConstants.kick),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('validateDetailOptions', () {
    test('a participant may leave and view members, nothing else', () {
      expect(
        DetailUtils.validateDetailOptions(
          loggedInUserScope: _participant,
          optionId: GroupOptionConstants.leave,
        ),
        isTrue,
      );
      expect(
        DetailUtils.validateDetailOptions(
          loggedInUserScope: _participant,
          optionId: GroupOptionConstants.viewMembers,
        ),
        isTrue,
      );
      for (final opt in [
        GroupOptionConstants.addMembers,
        GroupOptionConstants.delete,
        GroupOptionConstants.bannedMembers,
      ]) {
        expect(
          DetailUtils.validateDetailOptions(
            loggedInUserScope: _participant,
            optionId: opt,
          ),
          isFalse,
          reason: opt,
        );
      }
    });

    test('an unknown scope yields null', () {
      expect(
        DetailUtils.validateDetailOptions(
          loggedInUserScope: 'bogus',
          optionId: GroupOptionConstants.delete,
        ),
        isNull,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('validateUserOptions', () {
    final me = User(uid: 'u1', name: 'Alice');

    test('you cannot block yourself', () {
      expect(
        DetailUtils.validateUserOptions(me, me, UserOptionConstants.blockUser),
        isFalse,
      );
    });

    test('an already-blocked user cannot be blocked again', () {
      final blocked = User(uid: 'u2', name: 'Bob')..blockedByMe = true;
      expect(
        DetailUtils.validateUserOptions(
          me,
          blocked,
          UserOptionConstants.blockUser,
        ),
        isFalse,
      );
    });

    test('an unblocked user can be blocked', () {
      final other = User(uid: 'u2', name: 'Bob')..blockedByMe = false;
      expect(
        DetailUtils.validateUserOptions(
          me,
          other,
          UserOptionConstants.blockUser,
        ),
        isTrue,
      );
    });

    test('only a blocked user can be unblocked', () {
      final other = User(uid: 'u2', name: 'Bob')..blockedByMe = false;
      final blocked = User(uid: 'u3', name: 'Carol')..blockedByMe = true;
      expect(
        DetailUtils.validateUserOptions(
          me,
          other,
          UserOptionConstants.unblockUser,
        ),
        isFalse,
      );
      expect(
        DetailUtils.validateUserOptions(
          me,
          blocked,
          UserOptionConstants.unblockUser,
        ),
        isTrue,
      );
    });

    test('an unknown blocked state is treated as not blocked', () {
      final unknown = User(uid: 'u2', name: 'Bob');
      expect(
        DetailUtils.validateUserOptions(
          me,
          unknown,
          UserOptionConstants.unblockUser,
        ),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // The option builders. Each needs a context for its label.
  // -------------------------------------------------------------------------
  group('option builders', () {
    testWidgets('each group-member option carries its id, title and icon', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final options = {
          GroupMemberOptionConstants.kick: DetailUtils.getKickOption(context),
          GroupMemberOptionConstants.ban: DetailUtils.getBanOption(context),
          GroupMemberOptionConstants.changeScope:
              DetailUtils.getScopeChangeOption(context),
        };
        options.forEach((id, option) {
          expect(option.id, id);
          expect(option.title, isNotEmpty, reason: '$id has a label');
          expect(option.icon, isNotNull, reason: '$id has an icon');
        });
      });
    });

    testWidgets('each details option carries its id and a label', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final options = <String, CometChatDetailsOption>{
          GroupOptionConstants.viewMembers: DetailUtils.getViewMemberOption(
            context,
          ),
          GroupOptionConstants.bannedMembers: DetailUtils.getBannedMemberOption(
            context,
          ),
          GroupOptionConstants.addMembers: DetailUtils.getAddMembersOption(
            context,
          ),
          GroupOptionConstants.leave: DetailUtils.getLeaveGroupOption(context),
          GroupOptionConstants.delete: DetailUtils.getDeleteGroupOption(
            context,
          ),
          UserOptionConstants.blockUser: DetailUtils.getBlockUserOption(
            context,
          ),
          UserOptionConstants.unblockUser: DetailUtils.getUnBlockUserOption(
            context,
          ),
          UserOptionConstants.viewProfile: DetailUtils.getViewProfileOption(
            context,
          ),
        };
        options.forEach((id, option) {
          expect(option.id, id);
          expect(option.title, isNotEmpty, reason: '$id has a label');
        });
      });
    });

    testWidgets('the unbranded leave and delete options carry no package', (
      tester,
    ) async {
      // `getLeaveOption` / `getDeleteOption` are the second pair of
      // leave/delete builders; they differ from the `…GroupOption` ones above
      // only in that the leave variant declares no packageName, so an icon
      // lookup against it would not resolve inside this package.
      await withContext(tester, (context) {
        final leave = DetailUtils.getLeaveOption(context);
        final delete = DetailUtils.getDeleteOption(context);

        expect(leave.id, GroupOptionConstants.leave);
        expect(delete.id, GroupOptionConstants.delete);
        expect(leave.title, DetailUtils.getLeaveGroupOption(context).title);
        expect(delete.title, DetailUtils.getDeleteGroupOption(context).title);

        // FINDING: getLeaveOption omits packageName, unlike every sibling
        // builder in this file (getDeleteOption and getLeaveGroupOption both
        // set it). Pinned, not fixed — a lib/ change.
        expect(leave.packageName, isNull);
        expect(delete.packageName, UIConstants.packageName);

        // Both are destructive, so both use the red style rather than the
        // primary one.
        expect(leave.titleStyle?.color, const Color(0xffFF3B30));
        expect(delete.titleStyle?.color, const Color(0xffFF3B30));
        expect(
          DetailUtils.getViewProfileOption(context).titleStyle?.color,
          const Color(0xff3399FF),
        );
        expect(
          DetailUtils.getViewMemberOption(context).titleStyle?.color,
          const Color(0xff000000),
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  // The details templates. Each carries a callback, and it is the callback —
  // not the template — that applies the permission matrix, so the assertions
  // are on what the callback returns.
  // -------------------------------------------------------------------------
  group('getPrimaryDetailsTemplate', () {
    /// The option ids the primary template offers for a group whose logged-in
    /// member has [scope]. [owner] makes the actor the group owner.
    List<String> idsFor(
      BuildContext context, {
      required String scope,
      bool owner = false,
    }) {
      final me = User(uid: 'u1', name: 'Alice');
      final group = Group(guid: 'g1', name: 'Team', type: 'public')
        ..scope = scope
        ..owner = owner ? 'u1' : 'u9';
      final template = DetailUtils.getPrimaryDetailsTemplate(
        context,
        me,
        null,
        group,
      )!;
      return template.options!(null, group, context).map((o) => o.id).toList();
    }

    testWidgets('a participant may only view members', (tester) async {
      await withContext(tester, (context) {
        expect(idsFor(context, scope: _participant), [
          GroupOptionConstants.viewMembers,
        ]);
      });
    });

    testWidgets('a moderator also sees banned members', (tester) async {
      await withContext(tester, (context) {
        expect(idsFor(context, scope: _moderator), [
          GroupOptionConstants.viewMembers,
          GroupOptionConstants.bannedMembers,
        ]);
      });
    });

    testWidgets('an admin gets all three, in declaration order', (
      tester,
    ) async {
      await withContext(tester, (context) {
        expect(idsFor(context, scope: _admin), [
          GroupOptionConstants.viewMembers,
          GroupOptionConstants.addMembers,
          GroupOptionConstants.bannedMembers,
        ]);
      });
    });

    testWidgets('ownership beats a stale participant scope', (tester) async {
      await withContext(tester, (context) {
        expect(
          idsFor(context, scope: _participant, owner: true),
          hasLength(3),
          reason: 'owner by uid, whatever group.scope still says',
        );
      });
    });

    testWidgets('a user conversation gets no primary group actions', (
      tester,
    ) async {
      // The template is still built — it is the callback that empties itself
      // when a user is passed, since these are group-only actions.
      await withContext(tester, (context) {
        final me = User(uid: 'u1', name: 'Alice');
        final other = User(uid: 'u2', name: 'Bob');
        final template = DetailUtils.getPrimaryDetailsTemplate(
          context,
          me,
          other,
          null,
        );
        expect(template, isNotNull);
        expect(template!.id, DetailsTemplateConstants.primaryActions);
        expect(template.options!(other, null, context), isEmpty);
      });
    });

    testWidgets('the template hides the item separator only', (tester) async {
      await withContext(tester, (context) {
        final template = DetailUtils.getPrimaryDetailsTemplate(
          context,
          User(uid: 'u1', name: 'Alice'),
          null,
          Group(guid: 'g1', name: 'Team', type: 'public'),
        )!;
        expect(template.hideItemSeparator, isTrue);
        expect(template.hideSectionSeparator, isFalse);
      });
    });
  });

  // -------------------------------------------------------------------------
  group('getSecondaryDetailsTemplate', () {
    testWidgets('a user conversation offers block, not unblock', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final me = User(uid: 'u1', name: 'Alice');
        final other = User(uid: 'u2', name: 'Bob')..blockedByMe = false;
        final template = DetailUtils.getSecondaryDetailsTemplate(
          context,
          me,
          other,
          null,
        )!;
        expect(template.id, DetailsTemplateConstants.secondaryActions);
        expect(template.title, Translations.of(context).privacyAndSecurity);
        expect(template.options!(other, null, context).map((o) => o.id), [
          UserOptionConstants.blockUser,
        ]);
      });
    });

    testWidgets('an already-blocked user offers unblock, not block', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final me = User(uid: 'u1', name: 'Alice');
        final blocked = User(uid: 'u2', name: 'Bob')..blockedByMe = true;
        final template = DetailUtils.getSecondaryDetailsTemplate(
          context,
          me,
          blocked,
          null,
        )!;
        expect(template.options!(blocked, null, context).map((o) => o.id), [
          UserOptionConstants.unblockUser,
        ]);
      });
    });

    testWidgets('your own profile offers neither', (tester) async {
      await withContext(tester, (context) {
        final me = User(uid: 'u1', name: 'Alice')..blockedByMe = false;
        final template = DetailUtils.getSecondaryDetailsTemplate(
          context,
          me,
          me,
          null,
        )!;
        expect(template.options!(me, null, context), isEmpty);
      });
    });

    testWidgets('a group offers leave, and delete only above participant', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final me = User(uid: 'u1', name: 'Alice');

        Group grp(String scope, {bool owned = false}) =>
            Group(guid: 'g1', name: 'Team', type: 'public')
              ..scope = scope
              ..owner = owned ? 'u1' : 'u9';

        List<String> idsFor(Group group) =>
            DetailUtils.getSecondaryDetailsTemplate(
              context,
              me,
              null,
              group,
            )!.options!(null, group, context).map((o) => o.id).toList();

        expect(idsFor(grp(_participant)), [GroupOptionConstants.leave]);
        expect(idsFor(grp(_moderator)), [GroupOptionConstants.leave]);
        expect(idsFor(grp(_admin)), [
          GroupOptionConstants.leave,
          GroupOptionConstants.delete,
        ]);
        expect(idsFor(grp(_participant, owned: true)), [
          GroupOptionConstants.leave,
          GroupOptionConstants.delete,
        ]);
      });
    });

    testWidgets('a group template is titled "more"', (tester) async {
      await withContext(tester, (context) {
        final template = DetailUtils.getSecondaryDetailsTemplate(
          context,
          User(uid: 'u1', name: 'Alice'),
          null,
          Group(guid: 'g1', name: 'Team', type: 'public'),
        )!;
        expect(template.title, Translations.of(context).more);
        expect(template.title, isNotEmpty);
        // ...and not the user-side heading, which is the other arm.
        expect(
          template.title,
          isNot(Translations.of(context).privacyAndSecurity),
        );
        expect(template.hideItemSeparator, isTrue);
        expect(template.hideSectionSeparator, isFalse);
      });
    });

    testWidgets('neither a user nor a group yields no template at all', (
      tester,
    ) async {
      await withContext(tester, (context) {
        expect(
          DetailUtils.getSecondaryDetailsTemplate(
            context,
            User(uid: 'u1', name: 'Alice'),
            null,
            null,
          ),
          isNull,
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  group('getDefaultDetailsTemplates', () {
    testWidgets('a group gets both templates', (tester) async {
      await withContext(tester, (context) {
        final templates = DetailUtils.getDefaultDetailsTemplates(
          context,
          User(uid: 'u1', name: 'Alice'),
          group: Group(guid: 'g1', name: 'Team', type: 'public')
            ..scope = _admin,
        );
        expect(templates.map((t) => t.id), [
          DetailsTemplateConstants.primaryActions,
          DetailsTemplateConstants.secondaryActions,
        ]);
      });
    });

    testWidgets('a user gets both templates, the primary one empty', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final other = User(uid: 'u2', name: 'Bob')..blockedByMe = false;
        final templates = DetailUtils.getDefaultDetailsTemplates(
          context,
          User(uid: 'u1', name: 'Alice'),
          user: other,
        );
        expect(templates, hasLength(2));
        expect(templates.first.options!(other, null, context), isEmpty);
        expect(templates.last.options!(other, null, context), hasLength(1));
      });
    });

    testWidgets('neither a user nor a group yields no templates', (
      tester,
    ) async {
      await withContext(tester, (context) {
        expect(
          DetailUtils.getDefaultDetailsTemplates(
            context,
            User(uid: 'u1', name: 'Alice'),
          ),
          isEmpty,
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  group('getDefaultGroupMemberOptions', () {
    testWidgets('a moderator viewing a participant gets all three options', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final options = DetailUtils.getDefaultGroupMemberOptions(
          loggedInUser: User(uid: 'u1', name: 'Alice'),
          group: Group(guid: 'g1', name: 'Team', type: 'public')
            ..scope = _moderator
            ..owner = 'someone-else',
          member: GroupMember(uid: 'u2', name: 'Bob', scope: _participant),
          context: context,
        );
        expect(
          options.map((o) => o.id),
          containsAll([
            GroupMemberOptionConstants.kick,
            GroupMemberOptionConstants.ban,
            GroupMemberOptionConstants.changeScope,
          ]),
        );
      });
    });

    testWidgets('a participant viewing a participant gets nothing', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final options = DetailUtils.getDefaultGroupMemberOptions(
          loggedInUser: User(uid: 'u1', name: 'Alice'),
          group: Group(guid: 'g1', name: 'Team', type: 'public')
            ..scope = _participant
            ..owner = 'someone-else',
          member: GroupMember(uid: 'u2', name: 'Bob', scope: _participant),
          context: context,
        );
        expect(options, isEmpty);
      });
    });

    testWidgets('the hide flags drop their options before validation', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final options = DetailUtils.getDefaultGroupMemberOptions(
          loggedInUser: User(uid: 'u1', name: 'Alice'),
          group: Group(guid: 'g1', name: 'Team', type: 'public')
            ..scope = _moderator
            ..owner = 'someone-else',
          member: GroupMember(uid: 'u2', name: 'Bob', scope: _participant),
          context: context,
          hideKickMemberOption: true,
          hideBanMemberOption: true,
        );
        final ids = options.map((o) => o.id);
        expect(ids, isNot(contains(GroupMemberOptionConstants.kick)));
        expect(ids, isNot(contains(GroupMemberOptionConstants.ban)));
        expect(ids, contains(GroupMemberOptionConstants.changeScope));
      });
    });

    testWidgets('the group owner is treated as owner regardless of scope', (
      tester,
    ) async {
      await withContext(tester, (context) {
        // loggedInUser.uid == group.owner, so the actor is the owner even
        // though group.scope still says participant.
        final options = DetailUtils.getDefaultGroupMemberOptions(
          loggedInUser: User(uid: 'u1', name: 'Alice'),
          group: Group(guid: 'g1', name: 'Team', type: 'public')
            ..scope = _participant
            ..owner = 'u1',
          member: GroupMember(uid: 'u2', name: 'Bob', scope: _participant),
          context: context,
        );
        expect(
          options,
          isNotEmpty,
          reason: 'ownership overrides the stale participant scope',
        );
      });
    });
  });
}
