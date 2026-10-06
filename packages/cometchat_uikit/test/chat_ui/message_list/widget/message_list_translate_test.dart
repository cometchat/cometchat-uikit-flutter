/// The Translate message option, as Android's XML Views UIKit has it
/// (ENG-38688).
///
/// Android offers "Translate" on every text message — the user's own and
/// others', in any chat — keeps offering it after a translation, and on a
/// tap asks the `message-translation` extension for the device language,
/// stores the answer on the message and re-renders the row with the
/// translation under a separator. Flutter adds one condition, as the v5 kit
/// and the extension docs do: the option shows only while the extension is
/// enabled for the app, which the list asks the SDK once.
///
/// The SDK is faked at its repository seam (`fake_sdk_moderation.dart`), so
/// the list's real `isExtensionEnabled` and `callExtension` calls run their
/// success and failure paths. The bloc is a recording mock whose `add`
/// re-publishes an edited message as an update operation, the way the real
/// bloc does, so a translation re-renders the row through the same path.
///
///   flutter test test/chat_ui/message_list/widget/message_list_translate_test.dart
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/widgets/cometchat_message_action_overlay.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_sdk_moderation.dart';

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');
final _en = TranslationsEn();
final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

/// Unique body text, so the long-press target is unambiguous.
const _body = 'translate sentinel body 7c2a';

TextMessage _text({
  bool byMe = true,
  String text = _body,
  Map<String, dynamic>? metadata,
  List<User>? mentionedUsers,
}) {
  final m = TextMessage(
    id: 7,
    text: text,
    sender: byMe ? _alice : _bob,
    receiver: byMe ? _bob : _alice,
    receiverUid: byMe ? 'u2' : 'u1',
    type: MessageTypeConstants.text,
    receiverType: ReceiverTypeConstants.user,
    sentAt: _sentAt,
    metadata: metadata,
  );
  if (mentionedUsers != null) m.mentionedUsers = mentionedUsers;
  return m;
}

MediaMessage _image() => MediaMessage(
  id: 8,
  sender: _bob,
  receiver: _alice,
  receiverUid: 'u1',
  type: MessageTypeConstants.image,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

/// A mocked bloc that records what the list dispatched and, like the real
/// one, answers a [MessageEdited] with an update operation for that row.
class _Bloc extends MockBloc<MessageListEvent, MessageListState>
    implements MessageListBloc {
  _Bloc(this.messages);

  final List<BaseMessage> messages;
  final events = <MessageListEvent>[];
  final operations = StreamController<MessageOperation>();

  @override
  // ignore: must_call_super
  void add(MessageListEvent event) {
    events.add(event);
    if (event is MessageEdited) {
      final index = messages.indexWhere((m) => m.id == event.message.id);
      if (index != -1) {
        operations.add(
          MessageOperation.update(messages[index], event.message, index),
        );
      }
    }
  }
}

_Bloc _bloc(BaseMessage message) {
  final msgs = <BaseMessage>[message];
  const initial = MessageListState(status: MessageListStatus.initial);
  final loaded = MessageListState(
    status: MessageListStatus.loaded,
    messages: msgs,
    loggedInUser: _alice,
  );
  final bloc = _Bloc(msgs);
  whenListen(
    bloc,
    Stream<MessageListState>.fromIterable([initial, loaded]),
    initialState: initial,
  );
  bloc.operations.add(MessageOperation.set(msgs, animated: false));
  when(() => bloc.operationsStream).thenAnswer((_) => bloc.operations.stream);
  when(() => bloc.findMessageIndex(any())).thenReturn(null);
  when(
    () => bloc.getReceiptNotifierForMessage(any()),
  ).thenReturn(ValueNotifier(MessageReceiptStatus.sent));
  when(
    () => bloc.getThreadReplyCountNotifier(any()),
  ).thenReturn(ValueNotifier<int>(0));
  when(() => bloc.initializeThreadReplyCount(any(), any())).thenAnswer((_) {});
  when(() => bloc.notifyMessageChanged(any())).thenAnswer((_) {});
  addTearDown(bloc.operations.close);
  return bloc;
}

Widget _app(Widget list, {Locale locale = const Locale('en')}) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: Translations.supportedLocales,
  locale: locale,
  home: Scaffold(body: list),
);

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A tall surface, so the action sheet's pages never overflow.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _inSheet(Finder matching) => find.descendant(
  of: find.byType(CometChatMessageActionOverlay),
  matching: matching,
);

/// Long-presses the message and returns the ids of the actions the sheet
/// was handed.
Future<List<String>> _sheetIds(WidgetTester tester, Finder target) async {
  await tester.longPress(target.first);
  await _settle(tester);
  return tester
      .widget<CometChatMessageActionOverlay>(
        find.byType(CometChatMessageActionOverlay),
      )
      .actionItems
      .map((a) => a.id)
      .toList();
}

/// Long-presses the message, turns to the sheet's "More" page, where
/// Translate sits, and taps it.
Future<void> _tapTranslate(
  WidgetTester tester, {
  Translations? strings,
  Finder? target,
}) async {
  final t = strings ?? _en;
  await tester.longPress(
    (target ?? find.text(_body, findRichText: true)).first,
  );
  await _settle(tester);
  await tester.tap(_inSheet(find.text(t.more)));
  await _settle(tester, 4);
  await tester.tap(_inSheet(find.text(t.translate)));
  await _settle(tester);
}

Finder get _bodyFinder => find.text(_body, findRichText: true);

void main() {
  setUpAll(() => registerFallbackValue(_text()));

  setUp(() async {
    CometChatUIKit.loggedInUser = _alice;
    await registerFakeSdkBackend();
    fakeEnabledExtensions = {ExtensionConstants.messageTranslation};
  });

  tearDown(() async {
    CometChatUIKit.loggedInUser = null;
    await clearFakeSdkBackend();
  });

  group('the Translate option', () {
    testWidgets('is offered on my own text message, on the More page', (
      tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(
        _app(CometChatMessageList(user: _bob, messageListBloc: _bloc(_text()))),
      );
      await _settle(tester);

      expect(
        await _sheetIds(tester, _bodyFinder),
        contains(MessageOptionConstants.translateMessage),
      );
      await tester.tap(_inSheet(find.text(_en.more)));
      await _settle(tester, 4);
      expect(_inSheet(find.text(_en.translate)), findsOneWidget);
    });

    testWidgets('is offered on someone else\'s text message', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(
        _app(
          CometChatMessageList(
            user: _bob,
            messageListBloc: _bloc(_text(byMe: false)),
          ),
        ),
      );
      await _settle(tester);

      expect(
        await _sheetIds(tester, _bodyFinder),
        contains(MessageOptionConstants.translateMessage),
      );
    });

    testWidgets('is hidden while the extension is disabled', (tester) async {
      fakeEnabledExtensions = {};
      _tallView(tester);
      await tester.pumpWidget(
        _app(CometChatMessageList(user: _bob, messageListBloc: _bloc(_text()))),
      );
      await _settle(tester);

      final ids = await _sheetIds(tester, _bodyFinder);
      expect(ids, contains(MessageOptionConstants.copyMessage));
      expect(ids, isNot(contains(MessageOptionConstants.translateMessage)));
    });

    testWidgets('is hidden when the extension check fails', (tester) async {
      // No SDK to ask: the check errors, and an unknown answer hides it.
      await clearFakeSdkBackend();
      _tallView(tester);
      await tester.pumpWidget(
        _app(CometChatMessageList(user: _bob, messageListBloc: _bloc(_text()))),
      );
      await _settle(tester);

      expect(
        await _sheetIds(tester, _bodyFinder),
        isNot(contains(MessageOptionConstants.translateMessage)),
      );
    });

    testWidgets('CometChatMessageList.hideTranslateMessageOption hides it', (
      tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(
        _app(
          CometChatMessageList(
            user: _bob,
            messageListBloc: _bloc(_text()),
            hideTranslateMessageOption: true,
          ),
        ),
      );
      await _settle(tester);

      final ids = await _sheetIds(tester, _bodyFinder);
      expect(ids, contains(MessageOptionConstants.copyMessage));
      expect(ids, isNot(contains(MessageOptionConstants.translateMessage)));
    });

    testWidgets('the list flag still hides it when the app supplies its own '
        'configurations', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(
        _app(
          CometChatMessageList(
            user: _bob,
            messageListBloc: _bloc(_text()),
            additionalConfigurations: AdditionalConfigurations(),
            hideTranslateMessageOption: true,
          ),
        ),
      );
      await _settle(tester);

      expect(
        await _sheetIds(tester, _bodyFinder),
        isNot(contains(MessageOptionConstants.translateMessage)),
      );
    });

    testWidgets('AdditionalConfigurations.hideTranslateMessageOption hides '
        'it', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(
        _app(
          CometChatMessageList(
            user: _bob,
            messageListBloc: _bloc(_text()),
            additionalConfigurations: AdditionalConfigurations(
              hideTranslateMessageOption: true,
            ),
          ),
        ),
      );
      await _settle(tester);

      final ids = await _sheetIds(tester, _bodyFinder);
      expect(ids, contains(MessageOptionConstants.copyMessage));
      expect(ids, isNot(contains(MessageOptionConstants.translateMessage)));
    });

    testWidgets('is not offered on a media message', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(
        _app(
          CometChatMessageList(user: _bob, messageListBloc: _bloc(_image())),
        ),
      );
      await _settle(tester);

      final ids = await _sheetIds(tester, find.byType(CometChatMessageBubble));
      expect(ids, isNotEmpty);
      expect(ids, isNot(contains(MessageOptionConstants.translateMessage)));
    });

    testWidgets('is still offered once the message is translated', (
      tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(
        _app(
          CometChatMessageList(
            user: _bob,
            messageListBloc: _bloc(
              _text(metadata: {'translated_message': 'hola'}),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(
        await _sheetIds(tester, _bodyFinder),
        contains(MessageOptionConstants.translateMessage),
      );
    });
  });

  group('tapping Translate', () {
    testWidgets('asks the message-translation extension for the app '
        'language', (tester) async {
      final calls = <List<Object?>>[];
      fakeCallExtension = (slug, method, endpoint, body) {
        calls.add([slug, method, endpoint, body]);
        return {
          'translations': [
            {'message_translated': 'bonjour'},
          ],
        };
      };
      _tallView(tester);
      await tester.pumpWidget(
        _app(
          CometChatMessageList(user: _bob, messageListBloc: _bloc(_text())),
          locale: const Locale('fr'),
        ),
      );
      await _settle(tester);
      await _tapTranslate(tester, strings: TranslationsFr());

      expect(calls, hasLength(1));
      expect(calls.single[0], 'message-translation');
      expect(calls.single[1], 'POST');
      expect(calls.single[2], '/v2/translate');
      expect(calls.single[3], {
        'msgId': 7,
        'text': _body,
        'languages': ['fr'],
      });
    });

    testWidgets('renders the translation under the message, labelled', (
      tester,
    ) async {
      fakeCallExtension = (_, _, _, _) => {
        'translations': [
          {'message_translated': 'hola mundo'},
        ],
      };
      final message = _text();
      final bloc = _bloc(message);
      _tallView(tester);
      await tester.pumpWidget(
        _app(CometChatMessageList(user: _bob, messageListBloc: bloc)),
      );
      await _settle(tester);
      expect(find.byType(MessageTranslationBubble), findsNothing);

      await _tapTranslate(tester);

      expect(message.metadata?['translated_message'], 'hola mundo');
      expect(bloc.events.whereType<MessageEdited>(), hasLength(1));
      final bubble = find.byType(MessageTranslationBubble);
      expect(bubble, findsOneWidget);
      expect(
        find.descendant(of: bubble, matching: find.text('hola mundo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bubble, matching: find.text(_en.textTranslated)),
        findsOneWidget,
      );
      // The original text is still there, above the translation.
      expect(
        find.descendant(of: bubble, matching: _bodyFinder),
        findsOneWidget,
      );
    });

    testWidgets('an error shows a toast and leaves the message alone', (
      tester,
    ) async {
      fakeCallExtension = (_, _, _, _) => throw Exception('translate failed');
      final message = _text();
      final bloc = _bloc(message);
      _tallView(tester);
      await tester.pumpWidget(
        _app(CometChatMessageList(user: _bob, messageListBloc: bloc)),
      );
      await _settle(tester);
      await _tapTranslate(tester);

      expect(find.text(_en.somethingWentWrongError), findsOneWidget);
      expect(find.byType(MessageTranslationBubble), findsNothing);
      expect(message.metadata?['translated_message'], isNull);
      expect(bloc.events.whereType<MessageEdited>(), isEmpty);
      // Let the toast's timer run out.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('an empty translation does nothing', (tester) async {
      fakeCallExtension = (_, _, _, _) => {
        'translations': [
          {'message_translated': ''},
        ],
      };
      final message = _text();
      final bloc = _bloc(message);
      _tallView(tester);
      await tester.pumpWidget(
        _app(CometChatMessageList(user: _bob, messageListBloc: bloc)),
      );
      await _settle(tester);
      await _tapTranslate(tester);

      expect(find.byType(MessageTranslationBubble), findsNothing);
      expect(find.text(_en.somethingWentWrongError), findsNothing);
      expect(message.metadata?['translated_message'], isNull);
      expect(bloc.events.whereType<MessageEdited>(), isEmpty);
    });

    testWidgets('no translations at all does nothing either', (tester) async {
      fakeCallExtension = (_, _, _, _) => {'translations': <Object>[]};
      final message = _text();
      final bloc = _bloc(message);
      _tallView(tester);
      await tester.pumpWidget(
        _app(CometChatMessageList(user: _bob, messageListBloc: bloc)),
      );
      await _settle(tester);
      await _tapTranslate(tester);

      expect(find.byType(MessageTranslationBubble), findsNothing);
      expect(bloc.events.whereType<MessageEdited>(), isEmpty);
    });
  });

  group('a translated message', () {
    testWidgets('resolves mentions in the translation', (tester) async {
      await tester.pumpWidget(
        _app(
          CometChatMessageList(
            user: _bob,
            messageListBloc: _bloc(
              _text(
                text: 'hi <@uid:u2>',
                mentionedUsers: [_bob],
                metadata: {'translated_message': 'hola <@uid:u2>'},
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(
        find.descendant(
          of: find.byType(MessageTranslationBubble),
          matching: find.text('hola @Bob'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('my translation takes the outgoing '
        'messageTranslationBubbleStyle', (tester) async {
      await tester.pumpWidget(
        _app(
          CometChatMessageList(
            user: _bob,
            messageListBloc: _bloc(
              _text(metadata: {'translated_message': 'hola mundo'}),
            ),
            style: CometChatMessageListStyle(
              outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                messageTranslationBubbleStyle:
                    CometChatMessageTranslationBubbleStyle(
                      translatedTextStyle: const TextStyle(
                        color: Color(0xFF7A0001),
                      ),
                    ),
              ),
              incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                messageTranslationBubbleStyle:
                    CometChatMessageTranslationBubbleStyle(
                      translatedTextStyle: const TextStyle(
                        color: Color(0xFF7A0002),
                      ),
                    ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(
        tester.widget<Text>(find.text('hola mundo')).style?.color,
        const Color(0xFF7A0001),
      );
    });

    testWidgets('someone else\'s translation takes the incoming style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CometChatMessageList(
            user: _bob,
            messageListBloc: _bloc(
              _text(byMe: false, metadata: {'translated_message': 'hola'}),
            ),
            style: CometChatMessageListStyle(
              incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                messageTranslationBubbleStyle:
                    CometChatMessageTranslationBubbleStyle(
                      infoTextStyle: const TextStyle(color: Color(0xFF7B0001)),
                    ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(
        tester.widget<Text>(find.text(_en.textTranslated)).style?.color,
        const Color(0xFF7B0001),
      );
    });

    testWidgets('AdditionalConfigurations.messageTranslationBubbleStyle '
        'wins over the direction style', (tester) async {
      await tester.pumpWidget(
        _app(
          CometChatMessageList(
            user: _bob,
            messageListBloc: _bloc(
              _text(metadata: {'translated_message': 'hola mundo'}),
            ),
            additionalConfigurations: AdditionalConfigurations(
              messageTranslationBubbleStyle:
                  CometChatMessageTranslationBubbleStyle(
                    translatedTextStyle: const TextStyle(
                      color: Color(0xFF7C0001),
                    ),
                  ),
            ),
            style: CometChatMessageListStyle(
              outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                messageTranslationBubbleStyle:
                    CometChatMessageTranslationBubbleStyle(
                      translatedTextStyle: const TextStyle(
                        color: Color(0xFF7C0002),
                      ),
                    ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(
        tester.widget<Text>(find.text('hola mundo')).style?.color,
        const Color(0xFF7C0001),
      );
    });

    testWidgets('a long message is not squeezed to the old 232px cap', (
      tester,
    ) async {
      final long = List.filled(12, 'translate sentinel words').join(' ');
      await tester.pumpWidget(
        _app(
          CometChatMessageList(
            user: _bob,
            messageListBloc: _bloc(
              _text(text: long, metadata: {'translated_message': long}),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(
        tester.getSize(find.byType(MessageTranslationBubble)).width,
        greaterThan(232),
      );
    });

    testWidgets('the separator spans a translation wider than the original', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CometChatMessageList(
            user: _bob,
            messageListBloc: _bloc(
              _text(
                text: 'Hi',
                metadata: {'translated_message': 'Bonjour à tout le monde'},
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      final bubble = find.byType(MessageTranslationBubble);
      final separator = find
          .descendant(of: bubble, matching: find.byType(DecoratedBox))
          .first;
      expect(tester.getSize(separator).width, tester.getSize(bubble).width);
    });
  });
}
