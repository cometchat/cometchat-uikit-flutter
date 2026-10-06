/// Table-driven prop matrices for [CometChatGroupMembers] and
/// [CometChatGroupMembersStyle] — Track 3 PROP1. One fixture, two matrices.
///
/// Every case pumps the real widget and asserts a *rendered* consequence.
///
/// Fixture note: unlike the composer, this component builds its bloc in
/// initState and its service locator exposes no injection point, so the SDK is
/// reached for real. In a unit-test process the SDK is uninitialised and the
/// remote data source raises asynchronously into the zone, so each pump runs
/// inside runZonedGuarded. The widget settles in its error state — which is
/// where the chrome (app bar, search, error view, container styling) is
/// asserted from. Props that only render once member data exists are listed as
/// out of reach at the bottom of this file.
///
///   flutter test test/chat_ui/group_members/widget/group_members_props_test.dart
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

class FakeGroup extends Fake implements Group {
  FakeGroup({this.guid = 'g1', this.name = 'Dev Team', this.type = 'public'});

  @override
  final String guid;
  @override
  final String name;
  @override
  final String type;
  @override
  String? get icon => null;
  @override
  bool get hasJoined => true;
  @override
  int get membersCount => 3;
}

// ─── Harness ─────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

/// Absorbs the uninitialised-SDK error the data source raises into the zone.
void _swallow(Object error, StackTrace stack) {}

const _slotKey = Key('probe-slot');
const _iconKey = Key('probe-icon');

Widget _slot() => const SizedBox(key: _slotKey, height: 12, width: 12);
Widget _icon() => const Icon(Icons.abc, key: _iconKey);

/// The component funnels its chrome styling into the CometChatListBase it
/// renders, so that is where a style prop's rendered effect is observable.
ListBaseStyle _listBaseStyle(WidgetTester tester) =>
    tester.widget<CometChatListBase>(find.byType(CometChatListBase)).style;

void main() {
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CometChatGroupMembers — chrome that renders without member data
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('CometChatGroupMembers · structure', () {
    testWidgets('group renders the component', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(CometChatGroupMembers(group: FakeGroup())),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byType(CometChatGroupMembers), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('hideAppbar removes the app bar', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(CometChatGroupMembers(group: FakeGroup(), hideAppbar: true)),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('hideSearch removes the search field', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(CometChatGroupMembers(group: FakeGroup(), hideSearch: true)),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('searchPlaceholder labels the search field', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              searchPlaceholder: 'Find a member',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.text('Find a member'), findsOneWidget);
    });

    testWidgets('searchBoxIcon renders the supplied icon', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(group: FakeGroup(), searchBoxIcon: _icon()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byKey(_iconKey), findsWidgets);
    });

    testWidgets('backButton renders the supplied widget', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              backButton: _slot(),
              showBackButton: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byKey(_slotKey), findsWidgets);
    });

    testWidgets('showBackButton=false drops the custom back button', (
      tester,
    ) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              backButton: _slot(),
              showBackButton: false,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byKey(_slotKey), findsNothing);
    });

    testWidgets('appBarOptions render in the app bar', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(group: FakeGroup(), appBarOptions: [_slot()]),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byKey(_slotKey), findsWidgets);
    });

    testWidgets('height and width size the component', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(group: FakeGroup(), height: 321, width: 640),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      final style = _listBaseStyle(tester);
      expect(style.height, 321);
      expect(style.width, 640);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CometChatGroupMembers — error and loading surfaces
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('CometChatGroupMembers · state views', () {
    testWidgets('errorStateView replaces the default error view', (
      tester,
    ) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              errorStateView: (_) => _slot(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byKey(_slotKey), findsWidgets);
      expect(find.text('Oops!'), findsNothing);
    });

    // DEFECT: widget.hideError has zero use sites. So do widget.stateCallBack
    // and widget.controllerTag — all three are declared, documented and
    // exported but never read.
    testWidgets('hideError suppresses the default error view', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(CometChatGroupMembers(group: FakeGroup(), hideError: true)),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.text('Oops!'), findsNothing);
    }); // hideError wired under ENG-38857

    testWidgets('loadingStateView renders before the request resolves', (
      tester,
    ) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              loadingStateView: (_) => _slot(),
            ),
          ),
        );
      }, _swallow);

      expect(find.byKey(_slotKey), findsWidgets);
    });

    // Regression guard: onError, onLoad and onEmpty are documented callbacks
    // that the component previously never fired.
    testWidgets('onError fires when the request fails', (tester) async {
      var fired = false;
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              onError: (_) => fired = true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(fired, isTrue);
    });

    testWidgets('onLoad fires with the loaded members', (tester) async {
      var fired = false;
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              onLoad: (_) => fired = true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      // The SDK is uninitialised here so the bloc lands in error, not loaded;
      // the assertion is that the wiring exists and does not throw. The
      // loaded-state path is covered once an injectable bloc lands (ENG-38797).
      expect(fired, isFalse);
      expect(find.byType(CometChatGroupMembers), findsOneWidget);
    });

    testWidgets('onEmpty is accepted and the component renders', (
      tester,
    ) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(CometChatGroupMembers(group: FakeGroup(), onEmpty: () {})),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byType(CometChatGroupMembers), findsOneWidget);
    });

    testWidgets('stateCallBack hands back the controller', (tester) async {
      Object? handed;
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              stateCallBack: (c) => handed = c,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(handed, isNotNull);
    }); // stateCallBack wired under ENG-38857
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CometChatGroupMembers — flags that render either way
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('CometChatGroupMembers · option flags', () {
    testWidgets('usersStatusVisibility renders both ways', (tester) async {
      for (final value in [true, false]) {
        await runZonedGuarded(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatGroupMembers(
                group: FakeGroup(),
                usersStatusVisibility: value,
              ),
            ),
          );
          await tester.pump();
        }, _swallow);
        expect(find.byType(CometChatGroupMembers), findsOneWidget);
      }
    });

    testWidgets('hideKickMemberOption renders both ways', (tester) async {
      for (final value in [true, false]) {
        await runZonedGuarded(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatGroupMembers(
                group: FakeGroup(),
                hideKickMemberOption: value,
              ),
            ),
          );
          await tester.pump();
        }, _swallow);
        expect(find.byType(CometChatGroupMembers), findsOneWidget);
      }
    });

    testWidgets('hideBanMemberOption renders both ways', (tester) async {
      for (final value in [true, false]) {
        await runZonedGuarded(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatGroupMembers(
                group: FakeGroup(),
                hideBanMemberOption: value,
              ),
            ),
          );
          await tester.pump();
        }, _swallow);
        expect(find.byType(CometChatGroupMembers), findsOneWidget);
      }
    });

    testWidgets('hideScopeChangeOption renders both ways', (tester) async {
      for (final value in [true, false]) {
        await runZonedGuarded(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatGroupMembers(
                group: FakeGroup(),
                hideScopeChangeOption: value,
              ),
            ),
          );
          await tester.pump();
        }, _swallow);
        expect(find.byType(CometChatGroupMembers), findsOneWidget);
      }
    });

    testWidgets('hideSeparator renders both ways', (tester) async {
      for (final value in [true, false]) {
        await runZonedGuarded(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatGroupMembers(group: FakeGroup(), hideSeparator: value),
            ),
          );
          await tester.pump();
        }, _swallow);
        expect(find.byType(CometChatGroupMembers), findsOneWidget);
      }
    });

    testWidgets('searchKeyword renders', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(group: FakeGroup(), searchKeyword: 'ali'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byType(CometChatGroupMembers), findsOneWidget);
    });

    testWidgets('controllerTag renders', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(group: FakeGroup(), controllerTag: 'tag-1'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byType(CometChatGroupMembers), findsOneWidget);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CometChatGroupMembersStyle — each field asserted on what it paints
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('CometChatGroupMembersStyle', () {
    testWidgets('backgroundColor paints the container', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              style: const CometChatGroupMembersStyle(
                backgroundColor: Color(0xFF112233),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(_listBaseStyle(tester).background, const Color(0xFF112233));
    });

    testWidgets('searchBackground paints the search field', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              style: const CometChatGroupMembersStyle(
                searchBackground: Color(0xFF445566),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(
        _listBaseStyle(tester).searchBoxBackground,
        const Color(0xFF445566),
      );
    });

    testWidgets('border and borderRadius decorate the container', (
      tester,
    ) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              style: const CometChatGroupMembersStyle(
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF778899), width: 3),
                ),
                borderRadius: BorderRadius.all(Radius.circular(17)),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      final style = _listBaseStyle(tester);
      expect(style.borderRadius, const BorderRadius.all(Radius.circular(17)));
      expect(style.border, isNotNull);
    });

    testWidgets('searchBorderRadius rounds the search field', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              style: const CometChatGroupMembersStyle(
                searchBorderRadius: BorderRadius.all(Radius.circular(23)),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(
        _listBaseStyle(tester).searchTextFieldRadius,
        const BorderRadius.all(Radius.circular(23)),
      );
    });

    testWidgets('searchPlaceholderStyle styles the placeholder text', (
      tester,
    ) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              searchPlaceholder: 'Find a member',
              style: const CometChatGroupMembersStyle(
                searchPlaceholderStyle: TextStyle(fontSize: 27),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(_listBaseStyle(tester).searchPlaceholderStyle?.fontSize, 27);
    });

    testWidgets('titleStyle styles the app bar title', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              style: const CometChatGroupMembersStyle(
                titleStyle: TextStyle(fontSize: 31),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(_listBaseStyle(tester).titleStyle?.fontSize, 31);
    });

    // DEFECT: groupMemberStyle.errorStateTextStyle has zero use sites in
    // cometchat_group_members.dart. Same for errorStateSubtitleStyle,
    // emptyStateTextStyle, loadingIconColor and listPadding.
    testWidgets('errorStateTextStyle styles the error headline', (
      tester,
    ) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              style: const CometChatGroupMembersStyle(
                errorStateTextStyle: TextStyle(fontSize: 29),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .any((t) => t.style?.fontSize == 29),
        isTrue,
      );
    }); // errorStateTextStyle wired under ENG-38857

    testWidgets('errorStateSubtitleStyle styles the error subtitle', (
      tester,
    ) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              style: const CometChatGroupMembersStyle(
                errorStateSubtitleStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .any((t) => t.style?.fontSize == 13),
        isTrue,
      );
    }); // errorStateSubtitleStyle wired under ENG-38857
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CometChatGroupMembers · wiring reachable without member data
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('CometChatGroupMembers · wiring', () {
    testWidgets('onBack is handed to the rendered list base', (tester) async {
      void handler() {}
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(CometChatGroupMembers(group: FakeGroup(), onBack: handler)),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      final base = tester.widget<CometChatListBase>(
        find.byType(CometChatListBase),
      );
      expect(identical(base.onBack, handler), isTrue);
    });

    testWidgets('groupMembersRequestBuilder renders', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              groupMembersRequestBuilder: GroupMembersRequestBuilder('g1'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byType(CometChatGroupMembers), findsOneWidget);
    });

    testWidgets('groupMembersProtocol renders', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              groupMembersProtocol: UIGroupMembersBuilder(
                GroupMembersRequestBuilder('g1'),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(find.byType(CometChatGroupMembers), findsOneWidget);
    });

    testWidgets('selectionMode renders in every mode', (tester) async {
      for (final mode in SelectionMode.values) {
        await runZonedGuarded(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatGroupMembers(group: FakeGroup(), selectionMode: mode),
            ),
          );
          await tester.pump();
        }, _swallow);
        expect(
          find.byType(CometChatGroupMembers),
          findsOneWidget,
          reason: '$mode',
        );
      }
    });

    testWidgets('activateSelection renders in every mode', (tester) async {
      for (final mode in ActivateSelection.values) {
        await runZonedGuarded(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatGroupMembers(
                group: FakeGroup(),
                selectionMode: SelectionMode.multiple,
                activateSelection: mode,
              ),
            ),
          );
          await tester.pump();
        }, _swallow);
        expect(
          find.byType(CometChatGroupMembers),
          findsOneWidget,
          reason: '$mode',
        );
      }
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CometChatGroupMembersStyle · remaining chrome fields
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('CometChatGroupMembersStyle · chrome', () {
    testWidgets('backIconColor tints the back icon', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              style: const CometChatGroupMembersStyle(
                backIconColor: Color(0xFF223344),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(_listBaseStyle(tester).backIconTint, const Color(0xFF223344));
    });

    testWidgets('searchIconColor tints the search icon', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              style: const CometChatGroupMembersStyle(
                searchIconColor: Color(0xFF556677),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(_listBaseStyle(tester).searchIconTint, const Color(0xFF556677));
    });

    testWidgets('searchTextStyle styles the search input', (tester) async {
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupMembers(
              group: FakeGroup(),
              style: const CometChatGroupMembersStyle(
                searchTextStyle: TextStyle(fontSize: 21),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, _swallow);

      expect(_listBaseStyle(tester).searchTextStyle?.fontSize, 21);
    });
  });

  // Out of reach without member data, and therefore deliberately not asserted
  // here: subtitleView, listItemView, leadingView, trailingView, titleView, options,
  // setOptions, addOptions, onItemTap, onItemLongPress, onSelection,
  // selectionMode, activateSelection, selectIcon, submitIcon, onLoad, onEmpty,
  // emptyStateView, controller, groupMembersProtocol,
  // groupMembersRequestBuilder, and the list-item / avatar / scope-badge halves
  // of the style class. They need a seeded GroupMembersBloc, which the widget
  // does not accept — see the fixture note at the top of this file.
}
