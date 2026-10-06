/// Render-verified prop matrix for CometChatMessagePreviewStyle and
/// CometChatThreadedHeaderStyle — Track 3 PROP2 (ENG-38961).
///
///   flutter test test/chat_ui/preview_and_threaded_style_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class MockThreadedHeaderBloc
    extends MockBloc<ThreadedHeaderEvent, ThreadedHeaderState>
    implements ThreadedHeaderBloc {}

final _me = User(uid: 'me', name: 'Me');

TextMessage _parent() => TextMessage(
  text: 'parent message',
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: MessageTypeConstants.text,
  sender: User(uid: 'u2', name: 'Bob'),
)..replyCount = 5;

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() {
    CometChatUIKit.loggedInUser = _me;
  });

  // -------------------------------------------------------------------------
  // CometChatMessagePreviewStyle — 9 props via CometChatMessagePreview.
  // -------------------------------------------------------------------------
  group('CometChatMessagePreviewStyle', () {
    testWidgets('surface, title, subtitle and close icon colours all apply', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatMessagePreview(
            messagePreviewTitle: 'Replying to Bob',
            messagePreviewSubtitle: 'the quoted text',
            messagePreviewStyle: CometChatMessagePreviewStyle(
              messagePreviewBackground: Color(0xFF101112),
              messagePreviewBorderRadius: BorderRadius.all(Radius.circular(23)),
              messagePreviewBorder: Border.fromBorderSide(
                BorderSide(color: Color(0xFF131415), width: 3),
              ),
              messagePreviewTitleColor: Color(0xFF161718),
              messagePreviewTitleStyle: TextStyle(fontSize: 26),
              messagePreviewSubtitleColor: Color(0xFF191A1B),
              messagePreviewSubtitleStyle: TextStyle(letterSpacing: 7),
              closeIconColor: Color(0xFF1C1D1E),
              replyMessagePreviewCloseIconColor: Color(0xFF1F2021),
            ),
          ),
        ),
      );
      await tester.pump();

      // Surface.
      final decos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(
        decos.any((d) => d.color == const Color(0xFF101112)),
        isTrue,
        reason: 'messagePreviewBackground',
      );
      expect(
        tester
            .widgetList<ClipRRect>(find.byType(ClipRRect))
            .any(
              (c) =>
                  c.borderRadius == const BorderRadius.all(Radius.circular(23)),
            ),
        isTrue,
        reason: 'messagePreviewBorderRadius',
      );
      expect(
        decos.any((d) => d.border?.top.color == const Color(0xFF131415)),
        isTrue,
        reason: 'messagePreviewBorder',
      );

      // Title and subtitle.
      final title = tester.widget<Text>(find.text('Replying to Bob'));
      expect(title.style?.fontSize, 26, reason: 'messagePreviewTitleStyle');
      expect(
        title.style?.color,
        const Color(0xFF161718),
        reason: 'messagePreviewTitleColor',
      );
      final subtitle = tester.widget<Text>(find.text('the quoted text'));
      expect(
        subtitle.style?.letterSpacing,
        7,
        reason: 'messagePreviewSubtitleStyle',
      );
      expect(
        subtitle.style?.color,
        const Color(0xFF191A1B),
        reason: 'messagePreviewSubtitleColor',
      );

      // Close icons — the plain one and the reply variant.
      final iconColors = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.color)
          .toList();
      expect(
        iconColors.contains(const Color(0xFF1C1D1E)) ||
            iconColors.contains(const Color(0xFF1F2021)),
        isTrue,
        reason: 'closeIconColor / replyMessagePreviewCloseIconColor',
      );
    });
  });

  // -------------------------------------------------------------------------
  // CometChatThreadedHeaderStyle — 10 props via CometChatThreadedHeader.
  // -------------------------------------------------------------------------
  group('CometChatThreadedHeaderStyle', () {
    testWidgets('count chip, bubble container and constraints all apply', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final bloc = MockThreadedHeaderBloc();
        const state = ThreadedHeaderState();
        whenListen(
          bloc,
          Stream<ThreadedHeaderState>.value(state),
          initialState: state,
        );
        when(() => bloc.isClosed).thenReturn(false);

        await tester.pumpWidget(
          _wrap(
            CometChatThreadedHeader(
              parentMessage: _parent(),
              loggedInUser: _me,
              threadedHeaderBloc: bloc,
              style: const CometChatThreadedHeaderStyle(
                countContainerBackGroundColor: Color(0xFF212223),
                countContainerBorder: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF242526), width: 2),
                ),
                countTextColor: Color(0xFF272829),
                countTextStyle: TextStyle(letterSpacing: 8),
                bubbleContainerBackGroundColor: Color(0xFF2A2B2C),
                bubbleContainerBorderRadius: BorderRadius.all(
                  Radius.circular(29),
                ),
                bubbleContainerBorder: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF2D2E2F), width: 4),
                ),
                constraints: BoxConstraints(maxWidth: 321),
                incomingMessageBubbleStyle:
                    CometChatIncomingMessageBubbleStyle(),
                outgoingMessageBubbleStyle:
                    CometChatOutgoingMessageBubbleStyle(),
              ),
            ),
          ),
        );
        await tester.pump();

        final decos = tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .toList();
        expect(
          decos.any((d) => d.color == const Color(0xFF212223)),
          isTrue,
          reason: 'countContainerBackGroundColor',
        );
        expect(
          decos.any((d) => d.border?.top.color == const Color(0xFF242526)),
          isTrue,
          reason: 'countContainerBorder',
        );
        expect(
          decos.any((d) => d.color == const Color(0xFF2A2B2C)),
          isTrue,
          reason: 'bubbleContainerBackGroundColor',
        );
        expect(
          decos.any(
            (d) =>
                d.borderRadius == const BorderRadius.all(Radius.circular(29)),
          ),
          isTrue,
          reason: 'bubbleContainerBorderRadius',
        );
        expect(
          decos.any((d) => d.border?.top.color == const Color(0xFF2D2E2F)),
          isTrue,
          reason: 'bubbleContainerBorder',
        );

        expect(
          tester
              .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
              .any((c) => c.constraints.maxWidth == 321),
          isTrue,
          reason: 'constraints',
        );

        final counts = tester
            .widgetList<Text>(find.byType(Text))
            .where((t) => t.style?.letterSpacing == 8)
            .toList();
        expect(counts, isNotEmpty, reason: 'countTextStyle');
        expect(
          counts.first.style?.color,
          const Color(0xFF272829),
          reason: 'countTextColor',
        );

        final header = tester.widget<CometChatThreadedHeader>(
          find.byType(CometChatThreadedHeader),
        );
        expect(
          header.style?.incomingMessageBubbleStyle,
          isNotNull,
          reason: 'incomingMessageBubbleStyle',
        );
        expect(
          header.style?.outgoingMessageBubbleStyle,
          isNotNull,
          reason: 'outgoingMessageBubbleStyle',
        );
      });
    });
  });
}
