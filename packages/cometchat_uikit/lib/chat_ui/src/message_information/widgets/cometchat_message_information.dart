import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../cometchat_chat_uikit.dart';
import '../../../../cometchat_chat_uikit.dart' as cc;

/// [CometChatMessageInformation] is a widget which is used to display message information.
///
/// This widget uses BLoC for state management and follows Clean Architecture
/// patterns. It displays receipt information (read/delivered status) for a message.
///
/// For user conversations: Shows a single receipt with read/delivered timestamps
/// For group conversations: Fetches and displays receipts for all group members
///
/// ```dart
/// CometChatMessageInformation(
///   message: message,
///   title: "Message Information",
///   template: CometChatMessageTemplate(),
///   messageInformationStyle: CometChatMessageInformationStyle(),
/// );
/// ```
///
/// **Requirements: 1.1, 7.1**
class CometChatMessageInformation extends StatefulWidget {
  const CometChatMessageInformation({
    super.key,
    required this.message,
    this.title,
    this.template,
    this.messageInformationStyle,
    this.textFormatters,
    // Optional pre-cached theme values for optimization
    this.colorPalette,
    this.typography,
    this.spacing,
    this.messageInformationBloc,
  });

  /// [message] parent message for message information
  final BaseMessage message;

  /// [title] to be shown at head
  final String? title;

  /// [template] to get the message template
  final CometChatMessageTemplate? template;

  /// [messageInformationStyle] style parameter
  final CometChatMessageInformationStyle? messageInformationStyle;

  /// [textFormatters] list of text formatters. null = use defaults, empty = no formatters
  final List<CometChatTextFormatter>? textFormatters;

  /// [colorPalette] optional pre-cached color palette for optimization
  final CometChatColorPalette? colorPalette;

  /// [typography] optional pre-cached typography for optimization
  final CometChatTypography? typography;

  /// [spacing] optional pre-cached spacing for optimization
  final CometChatSpacing? spacing;

  ///[messageInformationBloc] Optional external MessageInformationBloc
  ///instance. If provided, it is used instead of creating one internally and
  ///the widget does not close it on dispose. Mirrors
  ///[CometChatConversations.conversationsBloc] — the seam that lets a test
  ///supply receipts without a live SDK.
  final MessageInformationBloc? messageInformationBloc;

  @override
  State<CometChatMessageInformation> createState() =>
      _CometChatMessageInformationState();
}

class _CometChatMessageInformationState
    extends State<CometChatMessageInformation> {
  /// BLoC for managing message information state
  late MessageInformationBloc _bloc;
  bool _isExternalBloc = false;

  /// Theme caching - initialized once in didChangeDependencies
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;

  /// Merged style
  late CometChatMessageInformationStyle _messageInfoStyle;

  /// Message template for rendering the parent message bubble
  late CometChatMessageTemplate _messageTemplate;

  @override
  void initState() {
    super.initState();

    // Initialize service locator if not already initialized
    if (!MessageInformationServiceLocator.instance.isInitialized) {
      MessageInformationServiceLocator.instance.setup();
    }

    // Resolve message template from data source based on message category/type
    _resolveMessageTemplate();

    // Create BLoC and dispatch initialization event
    if (widget.messageInformationBloc != null) {
      _bloc = widget.messageInformationBloc!;
      _isExternalBloc = true;
    } else {
      _bloc = MessageInformationBloc();
      _bloc.add(InitializeMessageInformation(parentMessage: widget.message));
    }
  }

  /// Resolve the message template from use case or use custom template
  ///
  /// If a custom template is provided via the `template` parameter, it takes
  /// precedence. Otherwise, the template is resolved from the data source
  /// based on the message's category and type.
  ///
  /// **Requirements: 8.1, 8.2**
  void _resolveMessageTemplate() {
    // If custom template is provided, use it directly (Requirement 8.2)
    if (widget.template != null) {
      _messageTemplate = widget.template!;
      return;
    }

    // Get all templates directly (Requirement 8.1)
    final templates = MessageTemplateUtils.getAllMessageTemplates();

    // Find matching template based on message category and type
    CometChatMessageTemplate? resolvedTemplate;
    for (final template in templates) {
      if (widget.message.category == template.category &&
          widget.message.type == template.type) {
        resolvedTemplate = template;
        break;
      }
    }

    // Use resolved template or fall back to first available template
    _messageTemplate = resolvedTemplate ?? templates.first;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize theme once to avoid expensive lookups during rebuilds
    // **Requirements: 6.1, 6.2**
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (!_themeInitialized || brightnessChanged) {
      _cachedBrightness = currentBrightness;
      // Use passed values or fallback to lookups (for standalone usage)
      // **Requirement: 6.3**
      _colorPalette =
          widget.colorPalette ?? CometChatThemeHelper.getColorPalette(context);
      _typography =
          widget.typography ?? CometChatThemeHelper.getTypography(context);
      _spacing = widget.spacing ?? CometChatThemeHelper.getSpacing(context);

      // Merge style with theme
      _messageInfoStyle =
          CometChatThemeHelper.getTheme<CometChatMessageInformationStyle>(
            context: context,
            defaultTheme: CometChatMessageInformationStyle.of,
          ).merge(widget.messageInformationStyle);

      _themeInitialized = true;
    }
  }

  @override
  void didUpdateWidget(CometChatMessageInformation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update cached theme values if they changed
    if (widget.colorPalette != oldWidget.colorPalette &&
        widget.colorPalette != null) {
      _colorPalette = widget.colorPalette!;
    }
    if (widget.typography != oldWidget.typography &&
        widget.typography != null) {
      _typography = widget.typography!;
    }
    if (widget.spacing != oldWidget.spacing && widget.spacing != null) {
      _spacing = widget.spacing!;
    }

    // Update style if it changed
    if (widget.messageInformationStyle != oldWidget.messageInformationStyle) {
      _messageInfoStyle =
          CometChatThemeHelper.getTheme<CometChatMessageInformationStyle>(
            context: context,
            defaultTheme: CometChatMessageInformationStyle.of,
          ).merge(widget.messageInformationStyle);
    }

    // Re-resolve template if parent message or custom template changed
    if (widget.message != oldWidget.message ||
        widget.template != oldWidget.template) {
      _resolveMessageTemplate();
    }
  }

  @override
  void dispose() {
    // an injected bloc belongs to its owner, so only close what we created
    if (!_isExternalBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.5,
        maxChildSize: 1,
        expand: false,
        builder: (context, scrollController) {
          return Material(
            color:
                _messageInfoStyle.backgroundColor ?? _colorPalette.background1,
            borderRadius:
                _messageInfoStyle.borderRadius ??
                BorderRadius.vertical(
                  top: Radius.circular(_spacing.radius6 ?? 0),
                ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                border: _messageInfoStyle.border,
              ),
              child: Column(
                children: [
                  // Notch and the Name
                  _buildHeader(),
                  // Content with BlocBuilder
                  BlocBuilder<MessageInformationBloc, MessageInformationState>(
                    bloc: _bloc,
                    builder: (context, state) {
                      if (state.hasError) {
                        // Error view
                        return const SizedBox();
                      } else if (state.receipts.isEmpty &&
                          state.status == MessageInformationStatus.loading) {
                        // Loading view
                        return Expanded(
                          child: SingleChildScrollView(
                            child: Column(children: [_buildLoadingView()]),
                          ),
                        );
                      } else {
                        // Loaded view
                        return Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Message bubble
                                IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          _messageInfoStyle
                                              .backgroundHighLightColor ??
                                          _colorPalette.background2,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                        _spacing.padding4 ?? 0,
                                      ),
                                      child: MessageUtils.getMessageBubble(
                                        context: context,
                                        colorPalette: _colorPalette,
                                        spacing: _spacing,
                                        typography: _typography,
                                        bubbleAlignment: BubbleAlignment.right,
                                        message:
                                            state.parentMessage ??
                                            widget.message,
                                        template: _messageTemplate,
                                        textFormatters:
                                            widget.textFormatters ??
                                            MessageTemplateUtils.getDefaultTextFormatters(),
                                      ),
                                    ),
                                  ),
                                ),
                                // Receipt list
                                // For group conversations, filter receipts with no timestamps
                                // before display for efficiency **Requirement: 9.4**
                                Builder(
                                  builder: (context) {
                                    final receiptsToDisplay =
                                        state.isGroupConversation
                                        ? state.receipts
                                              .where(
                                                (r) =>
                                                    r.readAt != null ||
                                                    r.deliveredAt != null,
                                              )
                                              .toList()
                                        : state.receipts;

                                    return ListView.builder(
                                      itemCount: receiptsToDisplay.length,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemBuilder: (context, index) {
                                        final messageReceipt =
                                            receiptsToDisplay[index];
                                        if (state.isUserConversation) {
                                          return _buildUserView(
                                            messageReceipt: messageReceipt,
                                          );
                                        }
                                        return _buildGroupView(
                                          messageReceipt: messageReceipt,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build the header with notch and title
  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: _spacing.padding3 ?? 0,
            bottom: _spacing.padding2 ?? 0,
          ),
          child: Container(
            height: 4,
            width: 32,
            decoration: BoxDecoration(
              color: _colorPalette.neutral500,
              borderRadius: BorderRadius.circular(_spacing.radiusMax ?? 0),
            ),
          ),
        ),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color:
                _messageInfoStyle.backgroundColor ?? _colorPalette.background1,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: _spacing.padding2 ?? 0,
                horizontal: _spacing.padding4 ?? 0,
              ),
              child: Text(
                widget.title ?? cc.Translations.of(context).messageInformation,
                style:
                    TextStyle(
                          color:
                              _messageInfoStyle.titleTextColor ??
                              _colorPalette.textPrimary,
                          fontSize: _typography.heading2?.bold?.fontSize,
                          fontWeight: _typography.heading2?.bold?.fontWeight,
                          fontFamily: _typography.heading2?.bold?.fontFamily,
                        )
                        .merge(_messageInfoStyle.titleTextStyle)
                        .copyWith(color: _messageInfoStyle.titleTextColor),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build time text widget
  Widget _buildTimeText(
    String text,
    TextStyle? mergeTextStyle,
    Color? textColor,
  ) {
    return Text(
      text,
      style: TextStyle(
        color: textColor ?? _colorPalette.textSecondary,
        fontSize: _typography.body?.regular?.fontSize,
        fontWeight: _typography.body?.regular?.fontWeight,
        fontFamily: _typography.body?.regular?.fontFamily,
      ).merge(mergeTextStyle).copyWith(color: textColor),
    );
  }

  /// Convert time to formatted string
  static String _convertTime(DateTime? time, String receiptDatePattern) {
    String formattedDate = "";
    if (time != null) {
      formattedDate = DateFormat(receiptDatePattern).format(time);
    }
    return formattedDate;
  }

  /// Build user view for 1-on-1 conversations
  ///
  /// **Requirement: 9.1**
  Widget _buildUserView({required MessageReceipt messageReceipt}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _spacing.padding4 ?? 0,
            vertical: _spacing.padding3 ?? 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: _spacing.padding1 ?? 0),
                child: Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: _spacing.padding1 ?? 0),
                      child: CometChatReceipt(
                        status: ReceiptStatus.read,
                        size: 16,
                        style: _messageInfoStyle.messageReceiptStyle,
                      ),
                    ),
                    _buildTimeText(
                      cc.Translations.of(context).read,
                      _messageInfoStyle.readTextStyle,
                      _messageInfoStyle.readTextColor,
                    ),
                  ],
                ),
              ),
              (messageReceipt.readAt == null)
                  ? _buildTimeText(
                      "----",
                      _messageInfoStyle.readDateTextStyle,
                      _messageInfoStyle.readDateTextColor,
                    )
                  : _buildTimeText(
                      _convertTime(messageReceipt.readAt, "dd/M/yyyy, h:mm a"),
                      _messageInfoStyle.readDateTextStyle,
                      _messageInfoStyle.readDateTextColor,
                    ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _spacing.padding4 ?? 0,
            vertical: _spacing.padding3 ?? 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: _spacing.padding1 ?? 0),
                child: Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: _spacing.padding1 ?? 0),
                      child: CometChatReceipt(
                        status: ReceiptStatus.delivered,
                        size: 16,
                        style: _messageInfoStyle.messageReceiptStyle,
                      ),
                    ),
                    _buildTimeText(
                      cc.Translations.of(context).delivered,
                      _messageInfoStyle.deliveredTextStyle,
                      _messageInfoStyle.deliveredTextColor,
                    ),
                  ],
                ),
              ),
              (messageReceipt.deliveredAt == null)
                  ? _buildTimeText(
                      "----",
                      _messageInfoStyle.deliveredDateTextStyle,
                      _messageInfoStyle.deliveredDateTextColor,
                    )
                  : _buildTimeText(
                      _convertTime(
                        messageReceipt.deliveredAt,
                        "dd/M/yyyy, h:mm a",
                      ),
                      _messageInfoStyle.deliveredDateTextStyle,
                      _messageInfoStyle.deliveredDateTextColor,
                    ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build group view for group conversations
  ///
  /// Displays each member's avatar, name, and receipt timestamps.
  /// Shows placeholder indicator ("----") when a timestamp is null.
  ///
  /// **Requirements: 9.2, 9.3**
  Widget _buildGroupView({required MessageReceipt messageReceipt}) {
    return ListTile(
      minLeadingWidth: 0,
      minVerticalPadding: 0,
      horizontalTitleGap: _spacing.padding3 ?? 0,
      leading: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CometChatAvatar(
            height: 40,
            width: 40,
            name: messageReceipt.sender.name,
            image: messageReceipt.sender.avatar,
            style: _messageInfoStyle.avatarStyle,
          ),
        ],
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Member name **Requirement: 9.2**
          Text(
            messageReceipt.sender.name,
            style:
                TextStyle(
                      color:
                          _messageInfoStyle.nameTextColor ??
                          _colorPalette.textPrimary,
                      fontSize: _typography.heading4?.medium?.fontSize,
                      fontWeight: _typography.heading4?.medium?.fontWeight,
                      fontFamily: _typography.heading4?.medium?.fontFamily,
                    )
                    .merge(_messageInfoStyle.nameTextStyle)
                    .copyWith(color: _messageInfoStyle.nameTextColor),
          ),
          // Read timestamp row - shows placeholder if null **Requirements: 9.2, 9.3**
          Row(
            children: [
              _buildTimeText(
                cc.Translations.of(context).read,
                _messageInfoStyle.readTextStyle,
                _messageInfoStyle.readTextColor,
              ),
              const Spacer(),
              _buildTimeText(
                messageReceipt.readAt != null
                    ? _convertTime(messageReceipt.readAt, "dd/M/yyyy, h:mm a")
                    : "----", // Placeholder indicator **Requirement: 9.3**
                _messageInfoStyle.readDateTextStyle,
                _messageInfoStyle.readDateTextColor,
              ),
            ],
          ),
          // Delivered timestamp row - shows placeholder if null **Requirements: 9.2, 9.3**
          Row(
            children: [
              _buildTimeText(
                cc.Translations.of(context).delivered,
                _messageInfoStyle.deliveredTextStyle,
                _messageInfoStyle.deliveredTextColor,
              ),
              const Spacer(),
              _buildTimeText(
                messageReceipt.deliveredAt != null
                    ? _convertTime(
                        messageReceipt.deliveredAt,
                        "dd/M/yyyy, h:mm a",
                      )
                    : "----", // Placeholder indicator **Requirement: 9.3**
                _messageInfoStyle.deliveredDateTextStyle,
                _messageInfoStyle.deliveredDateTextColor,
              ),
            ],
          ),
        ],
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: _spacing.padding4 ?? 0,
        vertical: _spacing.padding3 ?? 0,
      ),
    );
  }

  /// Build loading view with shimmer effect
  Widget _buildLoadingView() {
    return CometChatShimmerEffect(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: 10,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _spacing.padding4 ?? 0,
              vertical: _spacing.padding3 ?? 0,
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: CircleAvatar(radius: 24, backgroundColor: Colors.grey),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title shimmer bar
                      Container(
                        height: 19.0,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(
                            _spacing.radius2 ?? 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Row for shimmer bars
                      Row(
                        children: [
                          // Shimmer bars
                          Container(
                            height: 19.0,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(
                                _spacing.radius2 ?? 0,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            height: 19.0,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(
                                _spacing.radius2 ?? 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Function to show message information
///
/// **Requirement: 7.4**
Future showMessageInformation({
  required BuildContext context,
  required final BaseMessage message,
  final String? title,
  final CometChatMessageTemplate? template,
  final CometChatMessageInformationStyle? messageInformationStyle,
  final List<CometChatTextFormatter>? textFormatters,
}) {
  final colorPalette = CometChatThemeHelper.getColorPalette(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor:
        messageInformationStyle?.backgroundColor ?? colorPalette.background1,
    builder: (BuildContext context) {
      return CometChatMessageInformation(
        message: message,
        title: title,
        template: template,
        messageInformationStyle: messageInformationStyle,
        textFormatters: textFormatters,
      );
    },
  );
}
