import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../../../cometchat_uikit_shared.dart';
import '../no_intrinsic_card_wrapper.dart';
import '../../logging/cometchat_log.dart';

/// Renders an in-progress streaming AI response with shimmer effect.
///
/// Migrated from GetX to StatefulWidget for v6 BLoC architecture.
class CometChatStreamBubble extends StatefulWidget {
  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Text shown when no message is passed.
  @Deprecated(
    'Has no effect. message is required and is always the source. Will be removed in 7.0.0.',
  )
  final String? text;

  /// Alignment of the bubble.
  @Deprecated('Has no effect. Will be removed in 7.0.0.')
  final BubbleAlignment? alignment;

  const CometChatStreamBubble({
    super.key,
    required this.message,
    this.style,
    this.width,
    this.height,
    this.text,
    this.alignment,
  });

  /// The stream message being rendered.
  final StreamMessage message;

  /// Styling for the bubble.
  final CometChatAIAssistantBubbleStyle? style;

  /// Width of the bubble.
  final double? width;

  /// Height of the bubble.
  final double? height;

  @override
  State<CometChatStreamBubble> createState() => _CometChatStreamBubbleState();
}

class _CometChatStreamBubbleState extends State<CometChatStreamBubble> {
  String _text = '';
  String _errorText = '';
  bool _hasError = false;

  /// Tracks streamed card data by cardId.
  /// null value = loading placeholder; non-null = rendered card JSON.
  final Map<String, Map<String, dynamic>?> _cardStates = {};

  /// Execution text labels for card loading placeholders, by cardId.
  final Map<String, String?> _cardExecutionTexts = {};

  final CometChatStreamService _queueManager = CometChatStreamService();
  final Map<int, String> _originalMessageText = {};
  StreamSubscription<AIAssistantBaseEvent>? _streamSubscription;

  // Theme — cached in didChangeDependencies
  late CometChatAIAssistantBubbleStyle _bubbleStyle;
  late CometChatColorPalette _colorPalette;
  late CometChatSpacing _spacing;
  late CometChatTypography _typography;
  bool _themeInitialized = false;

  @override
  void initState() {
    super.initState();
    _text = widget.message.text ?? '';
    _startStreaming();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_themeInitialized) {
      _bubbleStyle =
          CometChatThemeHelper.getTheme<CometChatAIAssistantBubbleStyle>(
            context: context,
            defaultTheme: CometChatAIAssistantBubbleStyle.of,
          ).merge(widget.style);
      _colorPalette = CometChatThemeHelper.getColorPalette(context);
      _spacing = CometChatThemeHelper.getSpacing(context);
      _typography = CometChatThemeHelper.getTypography(context);
      _themeInitialized = true;
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _startStreaming() {
    final runId = widget.message.runId ?? widget.message.id;

    _streamSubscription = _queueManager
        .startStreamingForRunId(
          runId,
          onAiAssistantEvent: (event) async {
            await Future.delayed(_queueManager.streamDelay);
            _processEvent(event);
          },
          onError: (e) {
            if (!mounted) return;
            setState(() {
              _hasError = true;
              _errorText = e.message ?? '';
            });
          },
        )
        .listen(
          (_) {},
          onError: (err) => ccLog('[CometChatStreamBubble][StreamError] $err'),
          onDone: () => ccLog(
            '[CometChatStreamBubble][Done] Streaming completed for runId: $runId',
          ),
        );
  }

  void _processEvent(AIAssistantBaseEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case AgenticKeys.textMessageStart:
        _handleTextMessageStart(event as AIAssistantRunStartedEvent);
        break;
      case AgenticKeys.textMessageContent:
        _handleTextMessageContent(event as AIAssistantContentReceivedEvent);
        break;
      case AgenticKeys.textMessageEnd:
        _handleTextMessageEnd(event as AIAssistantMessageEndedEvent);
        break;
      case AgenticKeys.toolCallStart:
        _handleToolCallStart(event as AIAssistantToolStartedEvent);
        break;
      case AgenticKeys.toolCallEnd:
        _handleToolCallEnd(event as AIAssistantToolEndedEvent);
        break;
      case AgenticKeys.cardStart:
        _handleCardStart(event as AIAssistantCardStartedEvent);
        break;
      case AgenticKeys.card:
        _handleCardReceived(event as AIAssistantCardReceivedEvent);
        break;
      case AgenticKeys.cardEnd:
        // No-op per §2.6.2 — the persisted message replaces the streamed bubble
        break;
    }
  }

  void _handleTextMessageStart(AIAssistantRunStartedEvent event) {
    final runId = event.id;
    if (runId == null) return;
    if (_queueManager.checkMessageExists(runId)) {
      final existingMessage = _queueManager.getMessageById(runId);
      if (existingMessage != null) {
        existingMessage.text = '';
        existingMessage.metadata = {AIConstants.aiShimmer: false};
        _queueManager.updateMessage(existingMessage);
        setState(() => _text = existingMessage.text ?? '');
      }
    }
    _queueManager.clearBuffer(runId);
  }

  void _handleTextMessageContent(AIAssistantContentReceivedEvent event) {
    final runId = event.id;
    if (runId == null) return;

    final delta = event.delta ?? '';
    if (delta.isEmpty) return;

    final buffer = _queueManager.getOrCreateBuffer(runId);
    buffer.write(delta);

    final messageId = _queueManager.getMessageIdForRun(runId);
    if (messageId != null && _queueManager.checkMessageExists(messageId)) {
      final existingMessage = _queueManager.getMessageById(messageId);
      if (existingMessage != null) {
        existingMessage.text = (existingMessage.text ?? '') + delta;
        existingMessage.metadata?[AIConstants.aiShimmer] = false;
        _queueManager.updateMessage(existingMessage);
        setState(() => _text = existingMessage.text ?? '');
      }
    }
  }

  void _handleTextMessageEnd(AIAssistantMessageEndedEvent event) {
    final runId = event.id;
    if (runId == null) return;

    final messageId = _queueManager.getMessageIdForRun(runId);
    if (messageId != null && _queueManager.checkMessageExists(runId)) {
      final existingMessage = _queueManager.getMessageById(runId);
      if (existingMessage != null) {
        final finalText = _queueManager.getBufferContent(runId) ?? '';
        existingMessage.text = finalText;
        existingMessage.metadata?[AIConstants.aiShimmer] = false;
        _queueManager.updateMessage(existingMessage);
        setState(() => _text = finalText);
      }
    }
  }

  void _handleToolCallStart(AIAssistantToolStartedEvent event) {
    final runId = event.id;
    if (runId == null) return;

    final messageId = _queueManager.getMessageIdForRun(runId);
    if (messageId == null) return;

    if (_queueManager.checkMessageExists(runId)) {
      final existingMessage = _queueManager.getMessageById(runId);
      if (existingMessage != null) {
        _originalMessageText.putIfAbsent(
          messageId,
          () => existingMessage.text ?? '',
        );
        existingMessage.text =
            '${existingMessage.text}\n${event.executionText}';
        existingMessage.metadata?[AIConstants.aiShimmer] = false;
        _queueManager.updateMessage(existingMessage);
        setState(() => _text = existingMessage.text ?? '');
      }
    }
  }

  void _handleToolCallEnd(AIAssistantToolEndedEvent event) {
    final runId = event.id;
    if (runId == null) return;

    final messageId = _queueManager.getMessageIdForRun(runId);
    if (messageId == null) return;

    if (_queueManager.checkMessageExists(runId)) {
      final existingMessage = _queueManager.getMessageById(runId);
      if (existingMessage != null) {
        final originalText = _originalMessageText[messageId];
        if (originalText != null) {
          existingMessage.text = originalText;
          _originalMessageText.remove(messageId);
          _queueManager.updateMessage(existingMessage);
          setState(() => _text = existingMessage.text ?? '');
        }
      }
    }
  }

  /// §2.6.2 card_start — show loading placeholder tracked by cardId.
  void _handleCardStart(AIAssistantCardStartedEvent event) {
    final cardId = event.cardId;
    if (cardId == null || cardId.isEmpty) return;

    setState(() {
      _cardStates[cardId] = null; // null = loading placeholder
      _cardExecutionTexts[cardId] = event.executionText;
    });
  }

  /// §2.6.2 card — replace the placeholder with the actual card payload.
  void _handleCardReceived(AIAssistantCardReceivedEvent event) {
    final cardId = event.cardId;
    if (cardId == null || cardId.isEmpty) return;

    final cardData = event.getCard();
    if (cardData == null) return;

    setState(() {
      _cardStates[cardId] = cardData;
    });
  }

  /// card_end — remove the loading placeholder.
  /// If the card was already rendered (via 'card' event), keep it visible.
  /// Only removes entries that are still in loading state (null).
  // ignore: unused_element — retained for card_end event wiring
  void _handleCardEnd(AIAssistantCardEndedEvent event) {
    final cardId = event.cardId;
    if (cardId == null || cardId.isEmpty) return;

    // Remove only the loading placeholder — rendered cards stay
    if (_cardStates[cardId] == null) {
      setState(() {
        _cardStates.remove(cardId);
        _cardExecutionTexts.remove(cardId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width ?? MediaQuery.sizeOf(context).width * 0.7,
      decoration: BoxDecoration(
        border: _bubbleStyle.border,
        borderRadius: _bubbleStyle.borderRadius ?? BorderRadius.zero,
        color: _bubbleStyle.backgroundColor ?? _colorPalette.transparent,
      ),
      padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.0058),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CometChatShimmerEffect(
            linearGradient:
                (widget.message.metadata?[AIConstants.aiShimmer] == true)
                ? LinearGradient(
                    colors: [
                      _colorPalette.textTertiary ?? Colors.transparent,
                      _colorPalette.textPrimary ?? Colors.transparent,
                      _colorPalette.textTertiary ?? Colors.transparent,
                    ],
                  )
                : null,
            child: NoIntrinsicScroll(
              child: GptMarkdownTheme(
                gptThemeData: GptMarkdownThemeData(
                  brightness: Theme.of(context).brightness,
                  highlightColor: _colorPalette.background4,
                  h3: TextStyle(
                    color: _colorPalette.textPrimary,
                    fontWeight: _typography.body?.bold?.fontWeight,
                    fontSize: _typography.body?.bold?.fontSize,
                    fontFamily: _typography.body?.bold?.fontFamily,
                  ),
                ),
                child: GptMarkdown(
                  _text,
                  style:
                      TextStyle(
                            color: _colorPalette.textPrimary,
                            fontWeight: _typography.body?.regular?.fontWeight,
                            fontSize: _typography.body?.regular?.fontSize,
                            fontFamily: _typography.body?.regular?.fontFamily,
                          )
                          .merge(_bubbleStyle.textStyle)
                          .copyWith(color: _bubbleStyle.textColor),
                  codeBuilder: (context, name, code, closed) {
                    return NoIntrinsicScroll(
                      child: CometChatAiAssistantCodeBlock(
                        language: name,
                        codes: code,
                        colorPalette: _colorPalette,
                        spacing: _spacing,
                        typography: _typography,
                      ),
                    );
                  },
                  tableBuilder: (context, tableRows, textStyle, config) {
                    return NoIntrinsicScroll(
                      child: CometChatAiAssistantTableBuilder(
                        tableRows: tableRows,
                        colorPalette: _colorPalette,
                        spacing: _spacing,
                        typography: _typography,
                        config: config,
                      ),
                    );
                  },
                  // `inlineCodeBuilder` only exists from gpt_markdown 1.2; our ^1.1.2 still
                  // resolves 1.1.x, where this is the only option. Removed in 2.0.
                  // ignore: deprecated_member_use
                  highlightBuilder: (context, text, style) {
                    return CometchatHighlightBuilder(
                      text: text,
                      style: style,
                      typography: _typography,
                      spacing: _spacing,
                      colorPalette: _colorPalette,
                    );
                  },
                  // gpt_markdown 1.3.0 deprecates linkBuilder in favour of inlineLinkBuilder,
                  // which only exists from 1.3.0. linkBuilder stays until 2.0.0, which our
                  // ^1.1.2 constraint excludes; migrate when the package's floor moves to 1.3.0.
                  // ignore: deprecated_member_use
                  linkBuilder: (context, text, url, style) {
                    return CometchatLinkBuilder(
                      text: text,
                      url: url,
                      style: style,
                      typography: _typography,
                      spacing: _spacing,
                      colorPalette: _colorPalette,
                    );
                  },
                ),
              ),
            ),
          ),
          if (_errorText.isNotEmpty && _hasError) ...[
            SizedBox(height: _spacing.padding2),
            Container(
              padding: EdgeInsets.symmetric(
                vertical: _spacing.padding ?? 0,
                horizontal: _spacing.padding2 ?? 0,
              ),
              color: _colorPalette.error100,
              child: Text(
                _errorText,
                style: TextStyle(
                  color: _colorPalette.error,
                  fontWeight: _typography.caption1?.regular?.fontWeight,
                  fontSize: _typography.caption1?.regular?.fontSize,
                  fontFamily: _typography.caption1?.regular?.fontFamily,
                ),
                textAlign: TextAlign.start,
              ),
            ),
          ],
          // Streamed card widgets (card_start → loader, card → rendered)
          ..._buildStreamedCards(context),
        ],
      ),
    );
  }

  /// Builds card widgets for streamed cards (loading placeholders or rendered cards).
  List<Widget> _buildStreamedCards(BuildContext context) {
    if (_cardStates.isEmpty) return [];

    final resolvedThemeMode = Theme.of(context).brightness == Brightness.dark
        ? CometChatCardThemeMode.dark
        : CometChatCardThemeMode.light;

    return _cardStates.entries.map((entry) {
      final cardId = entry.key;
      final cardData = entry.value;

      return Padding(
        padding: EdgeInsets.symmetric(vertical: _spacing.padding2 ?? 4),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: cardData == null
              ? _buildCardPlaceholder(cardId)
              : _buildRenderedCard(cardId, cardData, resolvedThemeMode),
        ),
      );
    }).toList();
  }

  /// Loading placeholder for a card being generated.
  Widget _buildCardPlaceholder(String cardId) {
    final executionText = _cardExecutionTexts[cardId];
    return Container(
      key: ValueKey('card_loading_$cardId'),
      height: 120,
      decoration: BoxDecoration(
        color: _colorPalette.background2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _colorPalette.borderLight ?? Colors.grey.shade200,
          width: 0.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _colorPalette.iconSecondary,
              ),
            ),
            if (executionText != null && executionText.isNotEmpty) ...[
              SizedBox(height: _spacing.padding2 ?? 8),
              Text(
                executionText,
                style: TextStyle(
                  color: _colorPalette.textSecondary,
                  fontSize: _typography.caption1?.regular?.fontSize,
                  fontFamily: _typography.caption1?.regular?.fontFamily,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Rendered card widget from parsed card JSON.
  Widget _buildRenderedCard(
    String cardId,
    Map<String, dynamic> cardData,
    CometChatCardThemeMode themeMode,
  ) {
    final cardJson = jsonEncode(cardData);
    return NoIntrinsicCardWrapper(
      key: ValueKey('card_rendered_$cardId'),
      width: MediaQuery.sizeOf(context).width * 0.65,
      child: CometChatCardView(
        cardJson: cardJson,
        themeMode: themeMode,
        onAction: (CometChatCardActionEvent action) {
          CometChatUIEvents.ccCardActionClicked(widget.message, action);
        },
      ),
    );
  }
}
