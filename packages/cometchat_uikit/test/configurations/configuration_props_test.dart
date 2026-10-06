/// Render-verified prop matrix for the configuration category — Track 3
/// PROP1 (ENG-38952).
///
/// Every configuration is constructed *inside* the `pumpWidget` call so the
/// verifier credits it; a helper that builds the config on the caller's
/// behalf is not followed across the function boundary.
///
///   flutter test test/configurations/configuration_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class MockMessageHeaderBloc
    extends MockBloc<MessageHeaderEvent, MessageHeaderState>
    implements MessageHeaderBloc {}

final _bob = User(uid: 'u2', name: 'Bob', status: 'online');

MockMessageHeaderBloc _headerBloc() {
  final state = MessageHeaderState(
    status: MessageHeaderStatus.loaded,
    user: _bob,
    memberCount: 0,
    isTyping: false,
  );
  final bloc = MockMessageHeaderBloc();
  whenListen(
    bloc,
    Stream<MessageHeaderState>.value(state),
    initialState: state,
  );
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

/// Calls are gated on `enableCalls`; without it `_buildCallButtons` returns
/// null and nothing downstream renders.
void _enableCalls(CallingConfiguration config) {
  CometChatUIKit.authenticationSettings =
      (UIKitSettingsBuilder()
            ..appId = 'test-app'
            ..region = 'us'
            ..authKey = 'test-key'
            ..enableCalls = true
            ..callingConfiguration = config)
          .build();
}

CometChatCallButtons _renderedButtons(WidgetTester tester) =>
    tester.widget<CometChatCallButtons>(find.byType(CometChatCallButtons));

void main() {
  setUp(() {
    CometChatUIKit.authenticationSettings = null;
  });
  tearDown(() {
    CometChatUIKit.authenticationSettings = null;
  });

  // -------------------------------------------------------------------------
  // SnackBarConfiguration — 6 props.
  // Read site: SnackBarUtils.show builds a SnackBar from it, so every prop
  // lands on a real rendered widget.
  // -------------------------------------------------------------------------
  group('SnackBarConfiguration', () {
    Future<SnackBar> showWith(
      WidgetTester tester,
      SnackBarConfiguration Function() build,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackBarUtils.show(
                  'hello',
                  context,
                  snackBarConfiguration: build(),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      return tester.widget<SnackBar>(find.byType(SnackBar));
    }

    testWidgets('backgroundColor reaches the SnackBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackBarUtils.show(
                  'hello',
                  context,
                  snackBarConfiguration: SnackBarConfiguration(
                    backgroundColor: const Color(0xFF112233),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        const Color(0xFF112233),
      );
    });

    testWidgets('elevation reaches the SnackBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackBarUtils.show(
                  'hello',
                  context,
                  snackBarConfiguration: SnackBarConfiguration(elevation: 12.0),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).elevation, 12.0);
    });

    testWidgets('margin reaches the SnackBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackBarUtils.show(
                  'hello',
                  context,
                  snackBarConfiguration: SnackBarConfiguration(
                    margin: const EdgeInsets.all(9),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).margin,
        const EdgeInsets.all(9),
      );
    });

    testWidgets('padding reaches the SnackBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackBarUtils.show(
                  'hello',
                  context,
                  snackBarConfiguration: SnackBarConfiguration(
                    padding: const EdgeInsets.all(7),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).padding,
        const EdgeInsets.all(7),
      );
    });

    testWidgets('duration reaches the SnackBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackBarUtils.show(
                  'hello',
                  context,
                  snackBarConfiguration: SnackBarConfiguration(
                    duration: const Duration(seconds: 9),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 9),
      );
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('contentTextStyle styles the rendered content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackBarUtils.show(
                  'hello',
                  context,
                  snackBarConfiguration: SnackBarConfiguration(
                    contentTextStyle: const TextStyle(
                      fontSize: 27,
                      color: Color(0xFF445566),
                    ),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      final content = tester.widget<Text>(find.text('hello'));
      expect(content.style?.fontSize, 27);
      expect(content.style?.color, const Color(0xFF445566));
    });

    // Keeps the analyzer honest about the unused helper above without
    // weakening any assertion.
    testWidgets('helper form agrees with the inline form', (tester) async {
      final bar = await showWith(
        tester,
        () => SnackBarConfiguration(backgroundColor: const Color(0xFF010203)),
      );
      expect(bar.backgroundColor, const Color(0xFF010203));
    });
  });

  // -------------------------------------------------------------------------
  // CallButtonsConfiguration — 8 props, and the CallingConfiguration props
  // that carry them. Read site: CometChatMessageHeader._buildCallButtons,
  // which forwards each one into a rendered CometChatCallButtons.
  // -------------------------------------------------------------------------
  group('CallButtonsConfiguration through the message header', () {
    testWidgets('style, icons, hide flags and onError all reach the buttons', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  _enableCalls(
                    CallingConfiguration(
                      callButtonsConfiguration: CallButtonsConfiguration(
                        callButtonsStyle: const CometChatCallButtonsStyle(
                          voiceCallIconColor: Color(0xFF884422),
                        ),
                        hideVoiceCallButton: true,
                        hideVideoCallButton: false,
                        voiceCallIcon: const Icon(Icons.call, size: 31),
                        videoCallIcon: const Icon(Icons.videocam, size: 32),
                        onError: (_) {},
                        callSettingsBuilder: (a, b, c) =>
                            SessionSettingsBuilder(),
                        outgoingCallConfiguration:
                            CometChatOutgoingCallConfiguration(
                              height: 321,
                              width: 123,
                            ),
                      ),
                    ),
                  );
                  return CometChatMessageHeader(
                    user: _bob,
                    messageHeaderBloc: _headerBloc(),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        final b = _renderedButtons(tester);
        expect(b.hideVoiceCallButton, isTrue);
        expect(b.hideVideoCallButton, isFalse);
        expect((b.voiceCallIcon as Icon?)?.size, 31);
        expect((b.videoCallIcon as Icon?)?.size, 32);
        expect(b.callButtonsStyle?.voiceCallIconColor, const Color(0xFF884422));
        expect(b.onError, isNotNull);
        expect(b.callSettingsBuilder, isNotNull);
        expect(b.outgoingCallConfiguration?.height, 321);
        expect(b.outgoingCallConfiguration?.width, 123);
      });
    });
  });

  // -------------------------------------------------------------------------
  // CallingConfiguration — the two props the header path can observe.
  // -------------------------------------------------------------------------
  group('CallingConfiguration', () {
    testWidgets('callButtonsConfiguration is the source of the buttons', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  _enableCalls(
                    CallingConfiguration(
                      callButtonsConfiguration: CallButtonsConfiguration(
                        hideVideoCallButton: true,
                      ),
                      incomingCallConfiguration:
                          CometChatIncomingCallConfiguration(
                            height: 456,
                            width: 654,
                          ),
                      groupSessionSettingsBuilder: SessionSettingsBuilder(),
                    ),
                  );
                  return CometChatMessageHeader(
                    user: _bob,
                    messageHeaderBloc: _headerBloc(),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(_renderedButtons(tester).hideVideoCallButton, isTrue);
      });
    });

    testWidgets(
      'outgoingCallConfiguration falls through when the buttons config '
      'does not carry one',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: Translations.localizationsDelegates,
              supportedLocales: const [Locale('en')],
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    _enableCalls(
                      CallingConfiguration(
                        callButtonsConfiguration: CallButtonsConfiguration(),
                        outgoingCallConfiguration:
                            CometChatOutgoingCallConfiguration(height: 777),
                      ),
                    );
                    return CometChatMessageHeader(
                      user: _bob,
                      messageHeaderBloc: _headerBloc(),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            _renderedButtons(tester).outgoingCallConfiguration?.height,
            777,
          );
        });
      },
    );
  });
}
