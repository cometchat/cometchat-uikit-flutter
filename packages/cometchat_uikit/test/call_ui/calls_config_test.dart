/// One CallingConfiguration for the whole call UI (round 1a, P1-C10).
///
/// `UIKitSettings.callingConfiguration` wins; the first non-null configuration
/// a host passes to `CallEventService.init` fills in when the settings have
/// none; a later one no longer replaces it. The incoming call banner, the
/// message header's call buttons and the meeting bubble all read the same
/// one.
///
///   flutter test test/call_ui/calls_config_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calling_configuration_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'helpers/call_bloc_harness.dart';

class _MockMessageHeaderBloc
    extends MockBloc<MessageHeaderEvent, MessageHeaderState>
    implements MessageHeaderBloc {}

final _bob = User(uid: 'u2', name: 'Bob', status: 'online');

_MockMessageHeaderBloc _headerBloc() {
  final state = MessageHeaderState(
    status: MessageHeaderStatus.loaded,
    user: _bob,
    memberCount: 0,
    isTyping: false,
  );
  final bloc = _MockMessageHeaderBloc();
  whenListen(
    bloc,
    Stream<MessageHeaderState>.value(state),
    initialState: state,
  );
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

void _settings({CallingConfiguration? callingConfiguration}) {
  CometChatUIKit.authenticationSettings =
      (UIKitSettingsBuilder()
            ..appId = 'test-app'
            ..region = 'us'
            ..authKey = 'test-key'
            ..enableCalls = true
            ..callingConfiguration = callingConfiguration)
          .build();
}

Widget _app(Widget home) => MaterialApp(
  navigatorKey: CallNavigationContext.navigatorKey,
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: home),
);

void main() {
  setUp(() {
    CometChatUIKit.authenticationSettings = null;
    CallingConfigurationResolver.clearHostConfiguration();
  });

  tearDown(() {
    CometChatUIKit.authenticationSettings = null;
    CallingConfigurationResolver.clearHostConfiguration();
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  group('resolver', () {
    test('UIKitSettings.callingConfiguration wins over the init one', () {
      final fromSettings = CallingConfiguration();
      final fromInit = CallingConfiguration();
      _settings(callingConfiguration: fromSettings);

      CallingConfigurationResolver.offerHostConfiguration(fromInit);

      expect(CallingConfigurationResolver.resolved, same(fromSettings));
    });

    test('the init one is used when UIKitSettings has none', () {
      final fromInit = CallingConfiguration();
      _settings();

      CallingConfigurationResolver.offerHostConfiguration(fromInit);

      expect(CallingConfigurationResolver.resolved, same(fromInit));
    });

    test('init(A) then init(B) keeps A', () {
      final a = CallingConfiguration();
      final b = CallingConfiguration();
      _settings();

      CallingConfigurationResolver.offerHostConfiguration(a);
      CallingConfigurationResolver.offerHostConfiguration(b);

      expect(CallingConfigurationResolver.resolved, same(a));
    });

    test('a null configuration never fills the slot', () {
      final b = CallingConfiguration();
      _settings();

      CallingConfigurationResolver.offerHostConfiguration(null);
      CallingConfigurationResolver.offerHostConfiguration(b);

      expect(CallingConfigurationResolver.resolved, same(b));
    });

    test('clearHostConfiguration (logout) forgets it', () {
      _settings();
      CallingConfigurationResolver.offerHostConfiguration(
        CallingConfiguration(),
      );

      CallingConfigurationResolver.clearHostConfiguration();

      expect(CallingConfigurationResolver.resolved, isNull);
    });
  });

  group('the call UI reads the resolved configuration', () {
    testWidgets('message header call buttons', (tester) async {
      await mockNetworkImagesFor(() async {
        _settings();
        CallingConfigurationResolver.offerHostConfiguration(
          CallingConfiguration(
            callButtonsConfiguration: CallButtonsConfiguration(
              hideVoiceCallButton: true,
            ),
          ),
        );

        await tester.pumpWidget(
          _app(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _headerBloc(),
            ),
          ),
        );
        await tester.pump();

        final buttons = tester.widget<CometChatCallButtons>(
          find.byType(CometChatCallButtons),
        );
        expect(buttons.hideVoiceCallButton, isTrue);
      });
    });

    testWidgets('message header call buttons: the settings one wins', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        _settings(
          callingConfiguration: CallingConfiguration(
            callButtonsConfiguration: CallButtonsConfiguration(
              hideVideoCallButton: true,
            ),
          ),
        );
        CallingConfigurationResolver.offerHostConfiguration(
          CallingConfiguration(
            callButtonsConfiguration: CallButtonsConfiguration(
              hideVoiceCallButton: true,
            ),
          ),
        );

        await tester.pumpWidget(
          _app(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _headerBloc(),
            ),
          ),
        );
        await tester.pump();

        final buttons = tester.widget<CometChatCallButtons>(
          find.byType(CometChatCallButtons),
        );
        expect(buttons.hideVideoCallButton, isTrue);
        expect(buttons.hideVoiceCallButton, isNot(isTrue));
      });
    });

    testWidgets('incoming call banner', (tester) async {
      _settings();
      CallingConfigurationResolver.offerHostConfiguration(
        CallingConfiguration(
          incomingCallConfiguration: CometChatIncomingCallConfiguration(
            acceptButtonText: 'Pick up',
            declineButtonText: 'Not now',
            disableSoundForCalls: true,
          ),
        ),
      );
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      addTearDown(() {
        IncomingCallOverlay.dismiss();
        ActiveCallTracker.ringingCall = null;
      });

      await mockNetworkImagesFor(() async {
        CallEventService.instance.onIncomingCallReceived(
          Call(
            sessionId: 'banner-1',
            receiverUid: 'me',
            type: 'audio',
            receiverType: 'user',
            callInitiator: _bob,
          ),
        );
        await tester.pump();
        await tester.pump();
      });

      final banner = tester.widget<CometChatIncomingCall>(
        find.byType(CometChatIncomingCall),
      );
      expect(banner.acceptButtonText, 'Pick up');
      expect(banner.declineButtonText, 'Not now');

      IncomingCallOverlay.dismiss();
      await tester.pump();
    });

    testWidgets('meeting bubble', (tester) async {
      final group = SessionSettingsBuilder();
      _settings();
      CallingConfigurationResolver.offerHostConfiguration(
        CallingConfiguration(groupSessionSettingsBuilder: group),
      );
      // The call screen the bubble opens stops at the readiness guard.
      installCallsSdk(FakeCallsSdkGateway(), settings: () => null);
      await CallOperationsServiceLocator.instance.reset();
      CallOperationsServiceLocator.instance.setup(
        dataSource: FakeCallOperationsDataSource(),
      );
      addTearDown(() async {
        CallScreenOverlay.dismiss();
        uninstallCallsSdk();
        await CallOperationsServiceLocator.instance.reset();
      });

      // Sent (an id): Join does nothing on a meeting message still sending
      // (round 5).
      final meeting = CustomMessage(
        id: 1,
        receiverUid: 'g1',
        type: MessageTypeConstants.meeting,
        receiverType: CometChatReceiverType.group,
        customData: {'callType': 'video', 'sessionID': 'meeting-1'},
        sender: _bob,
      );
      final template = MessageTemplateUtils.getMessageTemplate(
        messageType: MessageTypeConstants.meeting,
        messageCategory: MessageCategoryConstants.custom,
      )!;

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) =>
                template.contentView!(meeting, context, BubbleAlignment.left)!,
          ),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(CometChatCallBubble),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pump();

      final screen = tester.widget<CometChatOngoingCall>(
        find.byType(CometChatOngoingCall),
      );
      expect(screen.sessionSettingsBuilder, same(group));
      expect(screen.sessionId, 'meeting-1');

      CallScreenOverlay.dismiss();
      await tester.pumpAndSettle();
    });
  });
}
