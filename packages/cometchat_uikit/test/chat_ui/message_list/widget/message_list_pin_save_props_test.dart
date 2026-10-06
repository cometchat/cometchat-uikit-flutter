/// Render-verified prop matrix for the pin / save / thread-subscription
/// surface that landed in 6.1.1 (ENG-38688, coverage part 2).
///
/// Two units share one rendered surface, the message action sheet the list
/// pushes on long-press:
///
/// * [CometChatMessageList]: `controller` plus five `hide*` flags
///   (hidePinMessageOption, hideUnpinMessageOption, hideSaveMessageOption,
///   hideUnsaveMessageOption, hideThreadSubscriptionOption).
/// * [AdditionalConfigurations]: the same five flags, which the list's
///   default templates read when an app supplies its own configurations
///   object.
///
/// Every case renders the list twice per variant, once with the prop unset
/// and once with the sentinel, and asserts three things: the default render
/// shows what the prop is meant to change, the sentinel render shows the
/// change, and the two renders differ. A flag is observed through the option
/// titles the sheet actually paints (Pin and Save live on its "More" page, so
/// the observation opens it), never by reading the flag back.
///
/// The variants exist because each flag is read in more than one place, and
/// a case that went through only one of them would stay green if another
/// were dropped:
///
/// * A list flag reaches the sheet twice: folded into the configurations
///   object the list builds when the app supplies none, and through the
///   list's own option filter. The second variant hands the list an app
///   configurations object, which leaves the filter as the only path.
/// * A configurations flag is checked by two option builders: text messages
///   go through getTextMessageOptions, media and custom messages through
///   getCommonOptions. Each case renders a text message and a file message.
///
/// Pin and Save render only while the SDK's feature flags report enabled.
/// Before `CometChat.init` both report the absence-means-enabled default, so
/// no SDK set-up is needed. The thread-subscription option also sits behind
/// [UIKitSettings.enableThreadSubscription]; every case sets that gate
/// explicitly and restores it afterwards.
///
///   flutter test test/chat_ui/message_list/widget/message_list_pin_save_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/widgets/cometchat_message_action_overlay.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Mocks & fixtures ────────────────────────────────────────────────────────

class _RecordingMessageListBloc
    extends MockBloc<MessageListEvent, MessageListState>
    implements MessageListBloc {
  /// Every event the widget dispatched, in order.
  final events = <MessageListEvent>[];

  @override
  // ignore: must_call_super
  void add(MessageListEvent event) => events.add(event);
}

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');
final _en = TranslationsEn();

/// Unique body text, so the long-press target cannot be confused with
/// anything else the list paints.
const _body = 'pin-save sentinel body 5e1c';

/// An id the list has not loaded: a controller jump to it has to take the
/// fetch-around-it path, which is what the controller cases observe.
const _unloadedMessageId = 424242;

enum _Kind { plain, pinnedAndSaved }

/// Which message the list shows. Each type reaches the sheet through a
/// different option builder.
enum _Type { text, file }

BaseMessage _message(_Kind kind, [_Type type = _Type.text]) {
  final sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  final BaseMessage m = switch (type) {
    _Type.text => TextMessage(
      id: 7,
      text: _body,
      sender: _alice,
      receiver: _bob,
      receiverUid: 'u2',
      type: MessageTypeConstants.text,
      receiverType: ReceiverTypeConstants.user,
      sentAt: sentAt,
    ),
    _Type.file => MediaMessage(
      id: 7,
      sender: _alice,
      receiver: _bob,
      receiverUid: 'u2',
      type: MessageTypeConstants.file,
      receiverType: ReceiverTypeConstants.user,
      sentAt: sentAt,
    ),
  };
  if (kind == _Kind.pinnedAndSaved) {
    // Pin and save state ride the message object; the option builders flip
    // Pin to Unpin and Save to Unsave on these two fields.
    m
      ..pinnedAt = DateTime.fromMillisecondsSinceEpoch(1700000100000)
      ..savedAt = DateTime.fromMillisecondsSinceEpoch(1700000200000);
  }
  return m;
}

/// A bloc that moves from `initial` to `loaded`, so the list's status
/// listener runs and lifts the initial-load shimmer the way a real load does.
_RecordingMessageListBloc _loadedBloc(BaseMessage message) {
  final msgs = <BaseMessage>[message];
  const initial = MessageListState(status: MessageListStatus.initial);
  final loaded = MessageListState(
    status: MessageListStatus.loaded,
    messages: msgs,
    loggedInUser: _alice,
  );
  final bloc = _RecordingMessageListBloc();
  whenListen(
    bloc,
    Stream<MessageListState>.fromIterable([initial, loaded]),
    initialState: initial,
  );
  when(() => bloc.operationsStream).thenAnswer(
    (_) => Stream<MessageOperation>.fromIterable([
      MessageOperation.set(msgs, animated: false),
    ]),
  );
  // Nothing counts as already loaded for a jump, so a controller jump
  // dispatches JumpToMessage instead of scrolling in place.
  when(() => bloc.findMessageIndex(any())).thenReturn(null);
  when(
    () => bloc.getReceiptNotifierForMessage(any()),
  ).thenReturn(ValueNotifier(MessageReceiptStatus.sent));
  when(
    () => bloc.getThreadReplyCountNotifier(any()),
  ).thenReturn(ValueNotifier<int>(0));
  when(() => bloc.initializeThreadReplyCount(any(), any())).thenAnswer((_) {});
  when(() => bloc.notifyMessageChanged(any())).thenAnswer((_) {});
  return bloc;
}

/// Everything one render needs. Built fresh for each run so the baseline and
/// sentinel renders share no state.
class _Fixture {
  _Fixture(_Kind kind, this.type) : bloc = _loadedBloc(_message(kind, type));

  final _RecordingMessageListBloc bloc;
  final _Type type;
  final controller = CometChatMessageListController();

  /// What a user long-presses to open the sheet: the text body (painted as a
  /// RichText, not a Text), or for a file message the bubble itself, which
  /// paints no unique text.
  Finder get target => switch (type) {
    _Type.text => find.text(_body, findRichText: true),
    _Type.file => find.byType(CometChatMessageBubble),
  };
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

/// Drives the animated list's operation queue, the overlay's entry
/// animation and any bubble animations.
Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A tall surface, so the sheet's pages never overflow.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Sets the thread-subscription feature gate for this test and restores
/// whatever was there before.
void _threadGate(bool on) {
  final previous = CometChatUIKit.authenticationSettings;
  addTearDown(() => CometChatUIKit.authenticationSettings = previous);
  CometChatUIKit.authenticationSettings =
      (UIKitSettingsBuilder()..enableThreadSubscription = on).build();
}

// ─── Observations ────────────────────────────────────────────────────────────

Finder _inSheet(Finder matching) => find.descendant(
  of: find.byType(CometChatMessageActionOverlay),
  matching: matching,
);

List<String> _sheetTexts(WidgetTester tester) => tester
    .widgetList<Text>(_inSheet(find.byType(Text)))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .toList();

/// Long-presses the message, then reads every title the sheet paints on both
/// of its pages. Pin and Save sit on "More", so that page is opened too.
Future<Object?> _optionTitles(WidgetTester tester, _Fixture fx) async {
  await tester.longPress(fx.target.first);
  await _settle(tester);
  final titles = <String>{..._sheetTexts(tester)};
  final more = _inSheet(find.text(_en.more));
  if (more.evaluate().isNotEmpty) {
    await tester.tap(more);
    await _settle(tester, 4);
    titles.addAll(_sheetTexts(tester));
  }
  return titles.toList()..sort();
}

/// Asks [controller] to jump to a message the list has not loaded, then
/// reads what the list did about it: whether the call was accepted, how many
/// JumpToMessage events for that id reached [bloc], and how many jump
/// shimmers went up over the list.
Future<List<Object>> _jump(
  WidgetTester tester,
  CometChatMessageListController controller,
  _RecordingMessageListBloc bloc,
) async {
  bloc.events.clear();
  final accepted = await controller.jumpToMessage(_unloadedMessageId);
  await tester.pump();
  final jumps = bloc.events
      .whereType<JumpToMessage>()
      .where((e) => e.messageId == _unloadedMessageId)
      .length;
  final shimmers = find.byType(CometChatShimmerEffect).evaluate().length;
  // Drain the list's five-second give-up timer so none outlives the test.
  await tester.pump(const Duration(seconds: 6));
  return [accepted, jumps, shimmers];
}

Future<Object?> _controllerJump(WidgetTester tester, _Fixture fx) =>
    _jump(tester, fx.controller, fx.bloc);

// ─── The matrix ──────────────────────────────────────────────────────────────

typedef _Observe = Future<Object?> Function(WidgetTester tester, _Fixture fx);

enum _Run { baseline, subject }

/// One way of rendering a case. Each variant renders twice (prop unset, prop
/// set) and is asserted on its own.
class _Variant {
  const _Variant(this.label, {this.type = _Type.text, this.appConfig = false});

  final String label;
  final _Type type;

  /// List group only: whether the app hands the list its own configurations
  /// object. The configurations group always does.
  final bool appConfig;
}

/// A list hide flag is read twice: folded into the configurations object the
/// list builds when the app supplies none, and by the list's option filter.
/// With an app object supplied, the filter is the only path left, so a flag
/// the filter ignored would show in the second variant.
const _listRoutes = [
  _Variant('when the list builds the configurations'),
  _Variant('when the app supplies configurations', appConfig: true),
];

/// A configurations flag is checked by getTextMessageOptions for text and by
/// getCommonOptions for every media and custom message, each with its own
/// copy of the check.
const _messageTypes = [
  _Variant('on a text message'),
  _Variant('on a file message', type: _Type.file),
];

class _Case<P> {
  const _Case({
    required this.prop,
    required this.effect,
    required this.subject,
    required this.observe,
    required this.baseline,
    required this.expected,
    this.kind = _Kind.plain,
    this.threadGate = false,
    this.variants = const [_Variant('as built')],
  });

  final String prop;
  final String effect;

  /// The props for the sentinel run. The baseline run uses the defaults.
  final P Function(_Fixture fx) subject;
  final _Observe observe;

  /// Value or matcher for the observation with the prop unset.
  final Object? baseline;

  /// Value or matcher for the observation with the prop set.
  final Object? expected;

  /// Pin and save state of the one message the list shows.
  final _Kind kind;

  /// Whether the thread-subscription feature gate is on for both runs.
  final bool threadGate;

  /// The renders the case is asserted through.
  final List<_Variant> variants;
}

/// A hide flag: the default sheet shows [hides] next to [keeps], and the
/// flagged sheet drops [hides] while still showing [keeps], which proves the
/// sheet rendered and the flag removed only its own option.
_Case<P> _hideCase<P>({
  required String prop,
  required String hides,
  required String keeps,
  required P subject,
  required List<_Variant> variants,
  _Kind kind = _Kind.plain,
  bool threadGate = false,
}) => _Case<P>(
  prop: prop,
  effect: 'removes "$hides" from the action sheet and keeps "$keeps"',
  subject: (_) => subject,
  observe: _optionTitles,
  baseline: containsAll(<String>[hides, keeps]),
  expected: allOf(isNot(contains(hides)), contains(keeps)),
  kind: kind,
  threadGate: threadGate,
  variants: variants,
);

/// The CometChatMessageList props a case can set. Defaults mirror the
/// widget's own, so a default instance is the same as passing nothing.
class _ListProps {
  const _ListProps({
    this.controller,
    this.hidePinMessageOption = false,
    this.hideUnpinMessageOption = false,
    this.hideSaveMessageOption = false,
    this.hideUnsaveMessageOption = false,
    this.hideThreadSubscriptionOption = false,
  });

  final CometChatMessageListController? controller;
  final bool hidePinMessageOption;
  final bool hideUnpinMessageOption;
  final bool hideSaveMessageOption;
  final bool hideUnsaveMessageOption;
  final bool hideThreadSubscriptionOption;
}

/// The AdditionalConfigurations flags a case can set. Null is the class's own
/// default for each.
class _ConfigProps {
  const _ConfigProps({
    this.hidePinMessageOption,
    this.hideUnpinMessageOption,
    this.hideSaveMessageOption,
    this.hideUnsaveMessageOption,
    this.hideThreadSubscriptionOption,
  });

  final bool? hidePinMessageOption;
  final bool? hideUnpinMessageOption;
  final bool? hideSaveMessageOption;
  final bool? hideUnsaveMessageOption;
  final bool? hideThreadSubscriptionOption;
}

final _listMatrix = <_Case<_ListProps>>[
  _Case(
    prop: 'controller',
    effect: 're-aims the mounted list at a message it has not loaded',
    subject: (fx) => _ListProps(controller: fx.controller),
    observe: _controllerJump,
    // Unset, nothing attaches: the call is refused, the bloc hears nothing
    // and no jump shimmer goes up.
    baseline: [false, 0, 0],
    expected: [true, 1, 1],
  ),
  _hideCase(
    prop: 'hidePinMessageOption',
    hides: _en.pinMessageOption,
    keeps: _en.saveMessageOption,
    subject: const _ListProps(hidePinMessageOption: true),
    variants: _listRoutes,
  ),
  _hideCase(
    prop: 'hideUnpinMessageOption',
    kind: _Kind.pinnedAndSaved,
    hides: _en.unpinMessageOption,
    keeps: _en.unsaveMessageOption,
    subject: const _ListProps(hideUnpinMessageOption: true),
    variants: _listRoutes,
  ),
  _hideCase(
    prop: 'hideSaveMessageOption',
    hides: _en.saveMessageOption,
    keeps: _en.pinMessageOption,
    subject: const _ListProps(hideSaveMessageOption: true),
    variants: _listRoutes,
  ),
  _hideCase(
    prop: 'hideUnsaveMessageOption',
    kind: _Kind.pinnedAndSaved,
    hides: _en.unsaveMessageOption,
    keeps: _en.unpinMessageOption,
    subject: const _ListProps(hideUnsaveMessageOption: true),
    variants: _listRoutes,
  ),
  _hideCase(
    prop: 'hideThreadSubscriptionOption',
    threadGate: true,
    hides: _en.messageListOptionGetReplyNotifications,
    keeps: _en.pinMessageOption,
    subject: const _ListProps(hideThreadSubscriptionOption: true),
    variants: _listRoutes,
  ),
];

final _configMatrix = <_Case<_ConfigProps>>[
  _hideCase(
    prop: 'hidePinMessageOption',
    hides: _en.pinMessageOption,
    keeps: _en.saveMessageOption,
    subject: const _ConfigProps(hidePinMessageOption: true),
    variants: _messageTypes,
  ),
  _hideCase(
    prop: 'hideUnpinMessageOption',
    kind: _Kind.pinnedAndSaved,
    hides: _en.unpinMessageOption,
    keeps: _en.unsaveMessageOption,
    subject: const _ConfigProps(hideUnpinMessageOption: true),
    variants: _messageTypes,
  ),
  _hideCase(
    prop: 'hideSaveMessageOption',
    hides: _en.saveMessageOption,
    keeps: _en.pinMessageOption,
    subject: const _ConfigProps(hideSaveMessageOption: true),
    variants: _messageTypes,
  ),
  _hideCase(
    prop: 'hideUnsaveMessageOption',
    kind: _Kind.pinnedAndSaved,
    hides: _en.unsaveMessageOption,
    keeps: _en.unpinMessageOption,
    subject: const _ConfigProps(hideUnsaveMessageOption: true),
    variants: _messageTypes,
  ),
  _hideCase(
    prop: 'hideThreadSubscriptionOption',
    threadGate: true,
    hides: _en.messageListOptionGetReplyNotifications,
    keeps: _en.pinMessageOption,
    subject: const _ConfigProps(hideThreadSubscriptionOption: true),
    variants: _messageTypes,
  ),
];

void main() {
  setUpAll(() {
    registerFallbackValue(_message(_Kind.plain));
  });

  group('CometChatMessageList 6.1.1 props', () {
    test('the matrix covers exactly the props new in 6.1.1', () {
      expect(_listMatrix.map((c) => c.prop), [
        'controller',
        'hidePinMessageOption',
        'hideUnpinMessageOption',
        'hideSaveMessageOption',
        'hideUnsaveMessageOption',
        'hideThreadSubscriptionOption',
      ]);
    });

    for (final c in _listMatrix) {
      testWidgets('${c.prop} ${c.effect}', (tester) async {
        _tallView(tester);
        _threadGate(c.threadGate);

        for (final v in c.variants) {
          final observed = <_Run, Object?>{};
          for (final run in _Run.values) {
            final fx = _Fixture(c.kind, v.type);
            final p = run == _Run.subject ? c.subject(fx) : const _ListProps();

            // A fresh tree per run: the list attaches its controller and
            // subscribes to its bloc in initState. The app configurations
            // object, when there is one, carries no flags of its own, so the
            // list flag is the only thing that differs between the runs.
            await tester.pumpWidget(const SizedBox.shrink());
            await mockNetworkImagesFor(
              () => tester.pumpWidget(
                _wrap(
                  CometChatMessageList(
                    user: _bob,
                    messageListBloc: fx.bloc,
                    additionalConfigurations: v.appConfig
                        ? AdditionalConfigurations()
                        : null,
                    controller: p.controller,
                    hidePinMessageOption: p.hidePinMessageOption,
                    hideUnpinMessageOption: p.hideUnpinMessageOption,
                    hideSaveMessageOption: p.hideSaveMessageOption,
                    hideUnsaveMessageOption: p.hideUnsaveMessageOption,
                    hideThreadSubscriptionOption:
                        p.hideThreadSubscriptionOption,
                  ),
                ),
              ),
            );
            await _settle(tester);
            observed[run] = await c.observe(tester, fx);
          }
          await tester.pumpWidget(const SizedBox.shrink());

          expect(
            observed[_Run.baseline],
            c.baseline,
            reason: 'rendered with ${c.prop} unset, ${v.label}',
          );
          expect(
            observed[_Run.subject],
            c.expected,
            reason: 'rendered with ${c.prop} set, ${v.label}',
          );
          expect(
            observed[_Run.subject],
            isNot(equals(observed[_Run.baseline])),
            reason: 'setting ${c.prop} changed nothing, ${v.label}',
          );
        }
      });
    }

    // The matrix case only proves the list attaches the controller it was
    // built with. The list also re-reads the prop when a rebuild hands it a
    // different controller, and lets go of it on dispose; either could be
    // dropped without that case noticing.
    testWidgets('controller follows a swap on the mounted list and is '
        'released on dispose', (tester) async {
      _tallView(tester);
      _threadGate(false);

      final fx = _Fixture(_Kind.plain, _Type.text);
      final first = fx.controller;
      final second = CometChatMessageListController();

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatMessageList(
              user: _bob,
              messageListBloc: fx.bloc,
              controller: first,
            ),
          ),
        ),
      );
      await _settle(tester);

      // Same bloc, same position: the element and its State are reused, so
      // this reaches didUpdateWidget rather than a fresh initState.
      await tester.pumpWidget(
        _wrap(
          CometChatMessageList(
            user: _bob,
            messageListBloc: fx.bloc,
            controller: second,
          ),
        ),
      );
      await tester.pump();

      final stale = await _jump(tester, first, fx.bloc);
      final live = await _jump(tester, second, fx.bloc);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(stale, [
        false,
        0,
        0,
      ], reason: 'the swapped-out controller still drives the list');
      expect(live, [
        true,
        1,
        1,
      ], reason: 'the swapped-in controller never attached');
      expect(
        second.isAttached,
        isFalse,
        reason: 'the controller still holds the disposed list',
      );
    });
  });

  group('AdditionalConfigurations 6.1.1 hide flags', () {
    test('the matrix covers exactly the hide flags new in 6.1.1', () {
      expect(_configMatrix.map((c) => c.prop), [
        'hidePinMessageOption',
        'hideUnpinMessageOption',
        'hideSaveMessageOption',
        'hideUnsaveMessageOption',
        'hideThreadSubscriptionOption',
      ]);
    });

    for (final c in _configMatrix) {
      testWidgets('${c.prop} ${c.effect}', (tester) async {
        _tallView(tester);
        _threadGate(c.threadGate);

        for (final v in c.variants) {
          final observed = <_Run, Object?>{};
          for (final run in _Run.values) {
            final fx = _Fixture(c.kind, v.type);
            final p = run == _Run.subject
                ? c.subject(fx)
                : const _ConfigProps();

            // Both runs hand the list a configurations object, so the only
            // difference between them is the one flag under test. Supplying
            // the object is what routes the sheet through these flags rather
            // than the widget-level ones.
            await tester.pumpWidget(const SizedBox.shrink());
            await mockNetworkImagesFor(
              () => tester.pumpWidget(
                _wrap(
                  CometChatMessageList(
                    user: _bob,
                    messageListBloc: fx.bloc,
                    additionalConfigurations: AdditionalConfigurations(
                      hidePinMessageOption: p.hidePinMessageOption,
                      hideUnpinMessageOption: p.hideUnpinMessageOption,
                      hideSaveMessageOption: p.hideSaveMessageOption,
                      hideUnsaveMessageOption: p.hideUnsaveMessageOption,
                      hideThreadSubscriptionOption:
                          p.hideThreadSubscriptionOption,
                    ),
                  ),
                ),
              ),
            );
            await _settle(tester);
            observed[run] = await c.observe(tester, fx);
          }
          await tester.pumpWidget(const SizedBox.shrink());

          expect(
            observed[_Run.baseline],
            c.baseline,
            reason: 'rendered with ${c.prop} unset, ${v.label}',
          );
          expect(
            observed[_Run.subject],
            c.expected,
            reason: 'rendered with ${c.prop} set, ${v.label}',
          );
          expect(
            observed[_Run.subject],
            isNot(equals(observed[_Run.baseline])),
            reason: 'setting ${c.prop} changed nothing, ${v.label}',
          );
        }
      });
    }
  });
}
