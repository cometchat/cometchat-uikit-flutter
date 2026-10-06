import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import '../../../../shared_ui/src/keyboard_height/keyboard_height_plugin.dart';
import '../../../../shared_ui/src/clean_architecture/core/utils/platform_utils/platform_file_utils.dart'
    as platform;
import '../../../../shared_ui/src/clean_architecture/core/utils/platform_utils/clipboard_paste.dart'
    as web_paste;
import '../../../../shared_ui/src/clean_architecture/core/utils/platform_utils/file_drop.dart'
    as web_drop;
import '../../../../shared_ui/src/clean_architecture/core/constants/enums.dart'
    as core_enums;

// Import extracted widgets
import 'message_composer_send_button.dart';
import 'message_composer_secondary_buttons.dart';
import 'message_composer_auxiliary_buttons.dart';
import 'message_composer_suggestion_list.dart';
import 'attachment_options_overlay.dart';

// Import inline audio recorder
import '../utils/composer_attachment_utils.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../../shared_ui/src/clean_architecture/core/utils/ui_event_target.dart';

///
/// [CometChatMessageComposer] component allows users to
/// send messages and attachments to the chat, participating in the conversation.
///
/// ```dart
///  CometChatMessageComposer(
///        user: User(uid: 'uid', name: 'name'),
///        group: Group(guid: 'guid', name: 'name', type: 'public'),
///        messageComposerStyle: MessageComposerStyle(),
///        stateCallBack: (MessageComposerBloc bloc) {},
///        customSoundForMessage: 'asset url',
///        disableSoundForMessages: true,
///        placeholderText: 'Message',
///      );
///
/// ```
///
/// ### Layout
///
/// The composer skeleton supports two layouts via the [layout] prop:
/// * [CometChatComposerLayout.singleLine] (default) — text field and buttons
///   share a single row.
/// * [CometChatComposerLayout.doubleLine] — classic v5 look with the text
///   field on its own row and buttons on a second row below a divider.
///
/// ```dart
/// CometChatMessageComposer(
///   user: User(uid: 'uid', name: 'name'),
///   layout: CometChatComposerLayout.doubleLine,
/// );
/// ```
///
///
///
class CometChatMessageComposer extends StatefulWidget {
  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Custom AI icon.
  @Deprecated(
    'Has no effect. The Flutter composer has no AI button; add your own through auxiliaryButtonView. Will be removed in 7.0.0.',
  )
  final Widget? aiIcon;

  /// Path of the icon for the AI button.
  @Deprecated(
    'Has no effect. The Flutter composer has no AI button; add your own through auxiliaryButtonView. Will be removed in 7.0.0.',
  )
  final String? aiIconURL;

  /// Package to load the AI icon from.
  @Deprecated(
    'Has no effect. The Flutter composer has no AI button; add your own through auxiliaryButtonView. Will be removed in 7.0.0.',
  )
  final String? aiIconPackageName;

  const CometChatMessageComposer({
    super.key,
    this.user,
    this.group,
    this.messageComposerStyle,
    this.placeholderText,
    this.disableTypingEvents = false,
    this.disableSoundForMessages = false,
    this.parentMessageId = 0,
    this.customSoundForMessage,
    this.customSoundForMessagePackage,
    this.auxiliaryButtonView,
    this.headerView,
    this.footerView,
    this.secondaryButtonView,
    this.sendButtonView,
    this.attachmentOptions,
    this.richTextToolbarActions,
    this.text,
    this.onChange,
    this.maxLine,
    this.auxiliaryButtonsAlignment,
    this.attachmentIconURL,
    this.stateCallBack,
    this.attachmentIcon,
    this.onError,
    this.onSendButtonTap,
    this.hideVoiceRecordingButton,
    this.useInlineAudioRecorder = true,
    this.voiceRecordingIcon,
    this.textFormatters,
    this.disableMentions,
    this.textEditingController,
    this.padding,
    this.messageInputPadding,
    this.recorderStartButtonIcon,
    this.recorderPauseButtonIcon,
    this.recorderDeleteButtonIcon,
    this.recorderStopButtonIcon,
    this.recorderSendButtonIcon,
    this.hideSendButton,
    this.hideAttachmentButton,
    this.hideStickersButton,
    this.stickerIcon,
    this.stickerActiveIcon,
    this.hideAudioAttachmentOption,
    this.hideFileAttachmentOption,
    this.hideImageAttachmentOption,
    this.hideVideoAttachmentOption,
    this.hidePollsOption,
    this.hideCollaborativeDocumentOption,
    this.hideCollaborativeWhiteboardOption,
    this.hideTakePhotoOption,
    this.sendButtonIcon,
    this.disableMentionAll = false,
    this.mentionAllLabel,
    this.mentionAllLabelId,
    this.enableRichTextFormatting = true,
    this.showRichTextFormattingOptions = true,
    this.hideRichTextFormattingOptions = const {},
    this.richTextToolbarView,
    this.onRichTextFormatApplied,
    this.hideBottomSafeArea = false,
    this.resizeToAvoidBottomInset = true,
    this.layout = CometChatComposerLayout.singleLine,
    this.onKeyboardDiagnostics,
    this.enableMultipleAttachments = true,
    this.attachmentTrayController,
    this.onAttachmentTrayAdd,
    this.onAttachmentTraySend,
    this.disableImagePaste = false,
    this.disableDragAndDrop = false,
    this.attachmentErrorAlertStyle,
    this.attachmentErrorSnackBarBuilder,
    this.onAttachmentErrorTap,
    this.aiIcon,
    this.aiIconURL,
    this.aiIconPackageName,
  }) : assert(
         user != null || group != null,
         "One of user or group should be passed",
       ),
       assert(
         user == null || group == null,
         "Only one of user or group should be passed",
       );

  ///sets [user] for message composer
  final User? user;

  ///set [group] for message composer
  final Group? group;

  ///[enableMultipleAttachments] when true (the default) the composer owns a
  ///multi-attachment staging tray: picked files upload immediately, stage as
  ///tray tiles, and send as one message per attachment kind (image / video /
  ///audio / file) grouped by a shared metadata batchId. When false, the legacy
  ///single-attachment pick→send flow is used.
  final bool enableMultipleAttachments;

  /// Optional external staging tray controller. When null and
  /// [enableMultipleAttachments] is true, the composer creates and owns its own
  /// controller internally — no app wiring needed.
  final AttachmentTrayController? attachmentTrayController;

  /// Invoked by the tray's Add affordance when [attachmentTrayController] is set.
  /// Documented as firing when the user taps **+** on the tray, but the tray
  /// renders no add affordance, so nothing invokes it — see ENG-38930. Kept
  /// rather than removed because it is a documented property; it starts
  /// working the moment the tray grows the button.
  final VoidCallback? onAttachmentTrayAdd;

  /// Invoked by the tray's Send affordance (shown only when the tray can send).
  final VoidCallback? onAttachmentTraySend;

  ///[disableImagePaste] disables staging an image pasted from the clipboard
  ///(context-menu Paste, Cmd/Ctrl+V, and the web paste event). Text paste is
  ///unaffected. Default false.
  final bool disableImagePaste;

  ///[disableDragAndDrop] disables staging files dragged onto the chat and the
  ///"drop files here" overlay (web only). Default false.
  final bool disableDragAndDrop;

  ///[attachmentErrorAlertStyle] styles every attachment error alert: the toast
  ///shown when a selection is over the count/size limit, and the alert stating
  ///why a staged attachment was rejected (see
  ///[CometChatAttachmentErrorAlertStyle]).
  final CometChatAttachmentErrorAlertStyle? attachmentErrorAlertStyle;

  ///[attachmentErrorSnackBarBuilder] fully replaces the default error snackbar.
  ///Receives the errored [AttachmentTile]. Informational only — retry lives in
  ///the tile (tap a failed tile to retry), so the snackbar carries no action.
  final SnackBar Function(BuildContext context, AttachmentTile tile)?
  attachmentErrorSnackBarBuilder;

  ///[onAttachmentErrorTap] fully overrides the tap/hover action on an errored
  ///tile (skips showing the default/custom snackbar entirely).
  final void Function(BuildContext context, AttachmentTile tile)?
  onAttachmentErrorTap;

  ///[messageComposerStyle] message composer style
  final CometChatMessageComposerStyle? messageComposerStyle;

  ///[auxiliaryButtonView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? auxiliaryButtonView;

  ///[secondaryButtonView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? secondaryButtonView;

  ///[sendButtonView] ui component to be forwarded to message input component
  final Widget? sendButtonView;

  ///[text] initial text for the input field
  final String? text;

  ///[placeholderText] hint text for input field
  final String? placeholderText;

  ///[onChange] callback to handle change in value of text in the input field
  final Function(String text)? onChange;

  ///[maxLine] maximum lines allowed to increase in the input field
  final int? maxLine;

  ///[auxiliaryButtonsAlignment] controls position auxiliary button view
  final AuxiliaryButtonsAlignment? auxiliaryButtonsAlignment;

  ///[attachmentIconURL] path of the icon to show in the attachments button
  final String? attachmentIconURL;

  ///[attachmentIcon] custom attachment icon
  final Widget? attachmentIcon;

  ///[hideVoiceRecordingButton] provides option to hide voice recording button
  final bool? hideVoiceRecordingButton;

  ///[useInlineAudioRecorder] when true, shows inline audio recorder in the composer
  ///instead of opening a bottom sheet. Defaults to true.
  final bool useInlineAudioRecorder;

  ///[voiceRecordingIcon] provides icon to the voice recording Icon/widget
  final Widget? voiceRecordingIcon;

  final int parentMessageId;

  ///[disableMentions] disables mentions in the composer
  final bool? disableMentions;

  ///[textEditingController] controls the state of the text field
  final TextEditingController? textEditingController;

  ///[padding] provides padding to the message composer
  final EdgeInsetsGeometry? padding;

  ///[messageInputPadding] sets the padding to the message input field
  final EdgeInsetsGeometry? messageInputPadding;

  ///[customSoundForMessage] provides custom sound for message sent
  final String? customSoundForMessage;

  ///[customSoundForMessagePackage] package name to show icon from
  final String? customSoundForMessagePackage;

  ///[disableSoundForMessages] disables sound for message sent
  final bool disableSoundForMessages;

  ///[disableTypingEvents] disables typing events
  final bool disableTypingEvents;

  ///[headerView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? headerView;

  ///[footerView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? footerView;

  ///[attachmentOptions] provides options to attach files
  final ComposerActionsBuilder? attachmentOptions;

  ///[richTextToolbarActions] appends consumer actions at the trailing end of
  ///the rich-text formatting toolbar, after a UIKit-owned divider (Trailing
  ///Toolbar Buttons DD). Same builder shape as [attachmentOptions]; each
  ///action's [CometChatMessageComposerAction.onToolbarTap] receives the live
  ///[RichTextEditingController], so it can read `text`/`selection` and call
  ///`applyFormat`/`applyInlineStyle`. Rendered in both composer layouts, and
  ///only while the rich-text toolbar itself is visible.
  final ComposerActionsBuilder? richTextToolbarActions;

  ///[stateCallBack] callback to handle state of the message composer
  ///Now returns MessageComposerBloc instead of the old controller
  final void Function(MessageComposerBloc bloc)? stateCallBack;

  ///[onError] callback to handle error
  final OnError? onError;

  ///[onSendButtonTap] callback to handle send button tap
  final Function(
    BuildContext context,
    BaseMessage message,
    PreviewMessageMode? previewMessageMode,
  )?
  onSendButtonTap;

  ///[textFormatters] provides list of text formatters
  final List<CometChatTextFormatter>? textFormatters;

  ///[recorderStartButtonIcon] defines the icon of the start button.
  final Widget? recorderStartButtonIcon;

  ///[recorderPauseButtonIcon] defines the icon of the pause button.
  final Widget? recorderPauseButtonIcon;

  ///[recorderDeleteButtonIcon] defines the icon of the delete button.
  final Widget? recorderDeleteButtonIcon;

  ///[recorderStopButtonIcon] defines the icon of the stop button.
  final Widget? recorderStopButtonIcon;

  ///[recorderSendButtonIcon] defines the icon of the send button.
  final Widget? recorderSendButtonIcon;

  ///[hideSendButton] is a [bool] that can be used to hide/display send button
  final bool? hideSendButton;

  ///[hideAttachmentButton] is a [bool] that can be used to hide/display attachment button
  final bool? hideAttachmentButton;

  ///[hideStickersButton] is a [bool] that can be used to hide/display sticker button
  final bool? hideStickersButton;

  ///[stickerIcon] replaces the sticker button's icon while the sticker
  ///keyboard is closed. Shown as given — tint it yourself; the default icon is
  ///tinted with [CometChatMessageComposerStyle.stickerIconColor].
  final Widget? stickerIcon;

  ///[stickerActiveIcon] replaces the sticker button's icon while the sticker
  ///keyboard is open. Shown as given — tint it yourself; the default icon is
  ///tinted with [CometChatMessageComposerStyle.stickerActiveIconColor].
  final Widget? stickerActiveIcon;

  ///[hideImageAttachmentOption] is a [bool] that can be used to hide/display image attachment option
  final bool? hideImageAttachmentOption;

  ///[hideVideoAttachmentOption] is a [bool] that can be used to hide/display video attachment option
  final bool? hideVideoAttachmentOption;

  ///[hideAudioAttachmentOption] is a [bool] that can be used to hide/display audio attachment option
  final bool? hideAudioAttachmentOption;

  ///[hideFileAttachmentOption] is a [bool] that can be used to hide/display file attachment option
  final bool? hideFileAttachmentOption;

  ///[hidePollsOption] is a [bool] that can be used to hide/display poll option
  final bool? hidePollsOption;

  ///[hideCollaborativeDocumentOption] is a [bool] that can be used to hide/display collaborative document option
  final bool? hideCollaborativeDocumentOption;

  ///[hideCollaborativeWhiteboardOption] is a [bool] that can be used to hide/display collaborative whiteboard option
  final bool? hideCollaborativeWhiteboardOption;

  ///[hideTakePhotoOption] is a [bool] that can be used to hide/display take photo option
  final bool? hideTakePhotoOption;

  ///[sendButtonIcon] custom send button icon
  final Widget? sendButtonIcon;

  ///[disableMentionAll] is a boolean which is used to disable @all mentions in groups
  final bool disableMentionAll;

  ///[mentionAllLabel] is a String which is used to set a custom label for @all mentions
  final String? mentionAllLabel;

  ///[mentionAllLabelId] is a String which is used to set a custom label ID for @all mentions
  final String? mentionAllLabelId;

  /// Master switch for rich text formatting (markdown detection, toolbar
  /// buttons, WYSIWYG rendering inside the composer).
  ///
  /// When `false`, the composer behaves as a plain text field — no markdown
  /// is parsed, no toolbar is shown, regardless of [showRichTextFormattingOptions].
  ///
  /// Defaults to `true`.
  final bool enableRichTextFormatting;

  /// Whether the rich text formatting toolbar UI is visible.
  ///
  /// Takes effect only when [enableRichTextFormatting] is true.
  ///
  /// Behavior per layout:
  /// * [CometChatComposerLayout.doubleLine] — renders an `Aa` toggle in the
  ///   composer's action row. Tapping swaps the row for the toolbar.
  /// * [CometChatComposerLayout.singleLine] — renders the toolbar in a
  ///   persistent row directly below the text input.
  ///
  /// When `false`, the composer still parses markdown in typed text but
  /// shows no toolbar UI. Defaults to `true`.
  final bool showRichTextFormattingOptions;

  /// Format buttons to hide from the toolbar.
  ///
  /// Example:
  /// ```dart
  /// hideRichTextFormattingOptions: const {
  ///   FormatType.strikethrough,
  ///   FormatType.codeBlock,
  /// }
  /// ```
  ///
  /// Has no effect if [showRichTextFormattingOptions] is `false`.
  final Set<FormatType> hideRichTextFormattingOptions;

  ///[richTextToolbarView] custom view for rich text toolbar.
  ///
  /// Receives the active text controller so the custom view can apply
  /// formats directly via [RichTextEditingController.applyFormat]. The
  /// legacy formatter manager argument has been removed.
  final Widget Function(BuildContext context, TextEditingController controller)?
  richTextToolbarView;

  ///[onRichTextFormatApplied] callback when a rich-text format is applied
  ///from the toolbar. The format type uses the active [FormatType] enum.
  final void Function(FormatType formatType)? onRichTextFormatApplied;

  ///[hideBottomSafeArea] when true, hides the bottom safe area padding.
  ///Use this when the parent widget handles safe area/keyboard positioning.
  final bool hideBottomSafeArea;

  ///[resizeToAvoidBottomInset] when true (default), indicates the parent
  ///Scaffold has `resizeToAvoidBottomInset: true` and will handle keyboard
  ///insets itself. The composer skips its internal keyboard height tracking
  ///and bottom padding. Set to false only if you are opting into the
  ///composer's internal keyboard-aware spacing and your parent Scaffold has
  ///`resizeToAvoidBottomInset: false`.
  final bool resizeToAvoidBottomInset;

  ///[layout] controls the skeleton layout of the composer.
  ///
  /// * [CometChatComposerLayout.singleLine] (default) — text field and all
  ///   buttons share a single row.
  /// * [CometChatComposerLayout.doubleLine] — text field on its own row, with
  ///   the secondary / auxiliary / primary buttons on a second row below a
  ///   divider (classic v5 look).
  ///
  /// All existing props (hide flags, slots, style, mentions, rich text,
  /// voice recording, reply/edit preview, AI options) work identically in
  /// both layouts.
  final CometChatComposerLayout layout;

  /// Optional diagnostics callback fired whenever the composer's internal
  /// keyboard state changes (native plugin event, viewInsets change, app
  /// resume, or widget activate).
  ///
  /// Use this to debug device-specific keyboard spacing issues — for example
  /// an unexpected gap between the composer and the keyboard on a particular
  /// OEM / gesture-nav setup. The callback receives a
  /// [CometChatKeyboardDiagnostics] snapshot containing every value the
  /// composer considers when deciding its bottom padding.
  ///
  /// Leave `null` in production — this is a debugging hook, not a layout
  /// primitive.
  final CometChatKeyboardDiagnosticsCallback? onKeyboardDiagnostics;

  @override
  State<CometChatMessageComposer> createState() =>
      _CometChatMessageComposerState();
}

class _CometChatMessageComposerState extends State<CometChatMessageComposer>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ============================================================================
  // BLoC and State Management
  // ============================================================================
  late MessageComposerBloc _bloc;
  late Map<String, dynamic> _composerId;

  // ============================================================================
  // Theme and Styling
  // ============================================================================
  late CometChatMessageComposerStyle _style;
  late CometChatColorPalette _colorPalette;
  late CometChatSpacing _spacing;
  late CometChatTypography _typography;
  late CometChatSuggestionListStyle _suggestionListStyle;

  // ============================================================================
  // Text Editing and Formatters
  // ============================================================================
  TextEditingController? _textEditingController;
  bool _isMyController = true;
  late FocusNode _focusNode;

  /// Handle for the web `paste`-event listener (null on native). Removed on
  /// dispose. See [web_paste.registerClipboardPasteListener].
  Object? _pasteListenerHandle;

  /// Handle for the web drag-and-drop listener (null on native). Removed on
  /// dispose. See [web_drop.registerFileDropListener].
  Object? _dropListenerHandle;

  /// True (web) while a file is being dragged over the page — drives the
  /// "drop files here" overlay on the composer.
  bool _isDraggingFile = false;

  /// Keys the composer's own root — used to test a web drag's viewport
  /// position against the composer's on-screen bounds, so drag-and-drop only
  /// activates while the pointer is actually over the composer, not anywhere
  /// on the page.
  final GlobalKey _dropTargetKey = GlobalKey();

  /// True when (clientX, clientY) — a web drag event's viewport position, in
  /// CSS pixels — falls within the composer's current on-screen rect.
  bool _isPointOverComposer(double clientX, double clientY) {
    final renderObject = _dropTargetKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return false;
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return rect.contains(Offset(clientX, clientY));
  }

  List<CometChatTextFormatter> _formatters = [];

  // ============================================================================
  // Suggestion List
  // ============================================================================
  List<SuggestionListItem> _suggestions = [];
  late StreamSubscription<List<SuggestionListItem>> _subscription;
  final StreamController<List<SuggestionListItem>> _suggestionListController =
      StreamController<List<SuggestionListItem>>();
  late Stream<List<SuggestionListItem>> _suggestionListStream;
  final StreamController<String> _previousTextController =
      StreamController<String>();
  late Stream<String> _previousTextStream;
  String _previousText = '';
  String? _currentSearchKeyword;
  bool _searchKeywordChanged = true;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  // ============================================================================
  // Attachment Options
  // ============================================================================
  final List<ActionItem> _actionItems = [];
  bool _getAttachmentOptionsCalled = false;
  CometChatAttachmentOptionSheetStyle? _actionStyle;

  // Flag to track if theme has been initialized (prevents re-init during keyboard animation)
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;
  // Keyboard Height Tracking (for instant keyboard positioning)
  // ============================================================================
  final ValueNotifier<double> _bottomPaddingNotifier = ValueNotifier<double>(0);
  double _safeAreaBottom = 0;
  double _maxBottomHeight =
      0; // Max height = keyboard height (when keyboard is open)
  double _lastStickerTotalHeight =
      0; // Total height when sticker keyboard was shown (for smooth transition)
  double _lastBottomPadding = 0; // Track last padding to detect sudden jumps
  final KeyboardHeightPlugin _keyboardHeightPlugin = KeyboardHeightPlugin();
  bool _isDisposing =
      false; // Prevents keyboard height updates during navigation
  bool _isKeyboardVisible = false; // Track keyboard visibility

  // Debouncing for fast transitions
  Timer? _keyboardHeightDebouncer;
  double _pendingPadding = 0; // Pending padding value during debounce
  bool _isTransitioning =
      false; // True when transitioning between keyboard/sticker

  // Track whether text field has content (for mic button visibility)
  bool _hadText = false;
  static const Duration _debounceDelay = Duration(
    milliseconds: 50,
  ); // Short debounce for fast transitions

  // Timer to clear sticker height after transition window
  Timer? _stickerHeightClearTimer;
  static const Duration _stickerHeightClearDelay = Duration(
    milliseconds: 300,
  ); // Reduced from 500ms
  bool _expectingKeyboardOpen =
      false; // True when we just closed sticker and expect keyboard to open

  // Sticker panel extra height added by drag gesture
  final ValueNotifier<double> _stickerExtraHeight = ValueNotifier<double>(0);

  // Stable keyboard height - the height after keyboard animation settles
  // This is used to prevent jiggle when keyboard height fluctuates during animation
  double _stableKeyboardHeight = 0;
  Timer? _stableHeightTimer;
  static const Duration _stableHeightDelay = Duration(
    milliseconds: 150,
  ); // Wait for keyboard to settle

  // Maximum allowed change per update to prevent sudden jumps (in logical pixels)
  // This smooths out rapid state changes during transitions
  static const double _maxPaddingChangePerUpdate = 100.0;

  // Resume protection: after app resumes with keyboard open, ignore spurious
  // close events that the OS fires as part of the resume cycle.
  bool _ignoreNextKeyboardClose = false;
  Timer? _resumeProtectionTimer;

  // ============================================================================
  // Overlay and Preview
  // ============================================================================
  final OverlayPortalController _overlayPortalController =
      OverlayPortalController();

  // ============================================================================
  // Reply/Edit Preview Animation
  // ============================================================================
  /// Composer-owned staging tray (created when [CometChatMessageComposer
  /// .enableMultipleAttachments] is on and no external controller was given).
  AttachmentTrayController? _internalTrayController;

  /// The effective staging tray: external controller if provided, else the
  /// composer-owned one; null when multi-attachment is disabled.
  AttachmentTrayController? get _tray =>
      widget.attachmentTrayController ?? _internalTrayController;

  /// Refreshes the composer-owned tray's receiver from the live conversation.
  /// Called right before every stage so the upload always presigns with the
  /// current recipient — chat-api requires `receiver`/`receiverType` for
  /// RBAC/SBAC and rejects a presign without them. (A host-supplied controller
  /// owns its own receiver; we don't override it.)
  void _syncTrayReceiver() {
    final tray = _internalTrayController;
    if (tray == null) return;
    tray.receiverId = widget.user?.uid ?? widget.group?.guid;
    tray.receiverType = widget.user != null
        ? ReceiverTypeConstants.user
        : ReceiverTypeConstants.group;
  }

  late final AnimationController _previewAnimController;
  late final Animation<Offset> _previewSlideAnimation;
  late final Animation<double> _previewFadeAnimation;
  bool _previewVisible = false;
  // Cached preview data so content remains visible during reverse animation
  String _lastPreviewTitle = '';
  String _lastPreviewSubtitle = '';
  Widget? _lastPreviewSubtitleWidget;
  BaseMessage? _lastPreviewMessage;

  // Attachment overlay state management
  final LayerLink _attachmentButtonLink = LayerLink();
  final LayerLink _composerLink =
      LayerLink(); // Link for positioning overlay above composer
  final OverlayPortalController _attachmentOverlayController =
      OverlayPortalController();
  final ValueNotifier<bool> _attachmentOpenNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> _suggestionOpenNotifier = ValueNotifier<bool>(
    false,
  );

  // ============================================================================
  // Auxiliary Options
  // ============================================================================
  Widget? _auxiliaryOptions;

  // ============================================================================
  // Rich Text Formatting
  // ============================================================================
  /// Single unified markdown formatter for bubble display (replaces 10+ legacy formatter instances)
  MarkdownTextFormatter? _markdownFormatter;
  bool _showRichTextToolbar = false;

  /// Tracks whether the user has tapped the `Aa` format toggle in the
  /// double-line layout. When true, the composer's action row is swapped
  /// for `[✕] + <toolbar>`. See [_isToolbarSwapActive] for the derived
  /// gate that also enforces the double-line + formatting-enabled
  /// requirements.
  bool _isToolbarToggleOpen = false;

  /// Whether the composer should use the WYSIWYG [RichTextEditingController]
  /// instead of a plain TextEditingController. Rich text rendering (bold
  /// spans, lists, etc. while typing) requires this controller even when the
  /// toolbar UI is hidden.
  bool get _useRichTextEditingController =>
      widget.enableRichTextFormatting && _hasAnyFormatEnabled;

  /// Whether the stacked (singleLine) rich-text toolbar should render below
  /// the composer. True when formatting is enabled, the options flag is on,
  /// and we're in singleLine layout.
  bool get _useStackedToolbar =>
      widget.enableRichTextFormatting &&
      widget.showRichTextFormattingOptions &&
      widget.layout == CometChatComposerLayout.singleLine;

  /// Whether the toggleable (doubleLine) toolbar flow is active. The `Aa`
  /// button is visible in the action row, and tapping swaps in the toolbar.
  bool get _useToggleableToolbar =>
      widget.enableRichTextFormatting &&
      widget.showRichTextFormattingOptions &&
      widget.layout == CometChatComposerLayout.doubleLine;

  /// Whether any rich-text format is enabled after applying the user's
  /// `hideRichTextFormattingOptions` filter.
  bool get _hasAnyFormatEnabled {
    if (!widget.enableRichTextFormatting) return false;
    final hide = widget.hideRichTextFormattingOptions;
    // If every format is in the hide set, none are enabled.
    const all = <FormatType>{
      FormatType.bold,
      FormatType.italic,
      FormatType.underline,
      FormatType.strikethrough,
      FormatType.inlineCode,
      FormatType.codeBlock,
      FormatType.link,
      FormatType.bulletList,
      FormatType.orderedList,
      FormatType.blockquote,
    };
    return all.any((f) => !hide.contains(f));
  }

  /// Whether a specific format is enabled given the current props.
  bool _isFormatEnabled(FormatType format) =>
      widget.enableRichTextFormatting &&
      !widget.hideRichTextFormattingOptions.contains(format);

  /// ValueNotifier for active formats - only rebuilds toolbar when formats change
  final ValueNotifier<Set<FormatType>> _activeFormatsNotifier =
      ValueNotifier<Set<FormatType>>({});

  /// Track previous active formats to detect changes
  Set<FormatType> _previousActiveFormats = {};

  /// Segment-based composer controller for Slack-style code blocks
  /// When active, code blocks are rendered as separate segments with their own text fields
  SegmentComposerController? _segmentComposerController;

  /// Whether segment-based code blocks are enabled
  bool get _useSegmentBasedCodeBlocks => _segmentComposerController != null;

  // ============================================================================
  // Lifecycle Methods
  // ============================================================================

  @override
  void initState() {
    super.initState();

    // Multi-attachment staging: the composer owns its tray controller unless
    // the host supplied one (enableMultipleAttachments default-on, zero wiring).
    // The conversation's receiver is passed through so uploads carry it to the
    // server for RBAC/SBAC at presign time.
    if (widget.enableMultipleAttachments &&
        widget.attachmentTrayController == null) {
      _internalTrayController = AttachmentTrayController(
        receiverId: widget.user?.uid ?? widget.group?.guid,
        receiverType: widget.user != null
            ? ReceiverTypeConstants.user
            : ReceiverTypeConstants.group,
      );
    }

    // Initialize reply/edit preview animation
    _previewAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _previewAnimController.addStatusListener((status) {
      // Rebuild when reverse animation completes to remove cached preview content
      if (status == AnimationStatus.dismissed) {
        setState(() {});
      }
    });
    _previewSlideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _previewAnimController,
            curve: Curves.easeOutCubic,
          ),
        );
    _previewFadeAnimation = CurvedAnimation(
      parent: _previewAnimController,
      curve: Curves.easeOut,
    );

    // Register for metrics changes (keyboard open/close)
    WidgetsBinding.instance.addObserver(this);

    // Initialize text editing controller
    if (widget.textEditingController != null) {
      _textEditingController = widget.textEditingController;
      _isMyController = false;
    }

    // Initialize composer ID
    _composerId = _buildComposerId();

    // Initialize streams
    _suggestionListStream = _suggestionListController.stream;
    _previousTextStream = _previousTextController.stream;

    // Subscribe to suggestion stream
    _subscription = _suggestionListStream.listen(_onSuggestionListUpdate);
    _previousTextStream.listen((value) => _previousText = value);

    // Initialize focus node
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);

    // Web: images can't be pulled off the clipboard on demand, so listen for
    // the browser `paste` event and stage any image while the composer is
    // focused. No-op on native (handled via the platform channel instead).
    if (!widget.disableImagePaste) {
      _pasteListenerHandle = web_paste.registerClipboardPasteListener(
        (bytes, mimeType, fileName) =>
            _stagePastedBytes(bytes, mimeType, fileName),
        _isComposerFocused,
      );
    }

    // Web: stage files dragged from the OS onto the chat while the pointer is
    // over the composer's own on-screen area, and toggle the "drop here"
    // overlay while such a drag is in progress. No-op on native.
    if (!widget.disableDragAndDrop) {
      _dropListenerHandle = web_drop.registerFileDropListener(
        _stageDroppedFiles,
        (x, y) => mounted && _isPointOverComposer(x, y),
        onDragActive: (active) {
          if (!mounted || _isDraggingFile == active) return;
          setState(() => _isDraggingFile = active);
        },
      );
    }

    // Initialize service locator
    if (!MessageComposerServiceLocator.instance.isInitialized) {
      MessageComposerServiceLocator.instance.setup();
    }

    // Initialize keyboard height listener for instant keyboard positioning
    // Native plugin provides real-time keyboard height updates
    // Skip when resizeToAvoidBottomInset is true — the parent Scaffold handles keyboard insets
    if (!widget.resizeToAvoidBottomInset) {
      _keyboardHeightPlugin.onKeyboardHeightChanged((
        double keyboardHeight,
        double safeAreaBottom,
      ) {
        // Skip updates during disposal to prevent jumps during navigation
        if (_isDisposing) return;

        // Cache latest raw native values for diagnostics (regardless of layout path)
        _lastNativeKeyboardHeight = keyboardHeight;
        if (safeAreaBottom > 0) {
          _lastNativeSafeAreaBottom = safeAreaBottom;
        }

        // Clamp native keyboardHeight to Flutter's viewInsets (ENG-34434).
        // Some Android OEMs (MIUI, ColorOS, etc.) report an `ime()` inset that
        // includes the system nav bar, making the native height ~48dp larger
        // than the space Flutter actually reclaims from content. Using the raw
        // native value as bottom padding produces a persistent gap between the
        // composer and the visible keyboard.
        //
        // If Flutter already sees the keyboard (viewInsets > 0), cap to that.
        // On the first native event viewInsets may still be 0 — the reconcile
        // step in `didChangeMetrics` below corrects that case once Flutter
        // catches up.
        if (keyboardHeight > 0) {
          final view = WidgetsBinding.instance.platformDispatcher.views.first;
          final flutterKbHeight =
              view.viewInsets.bottom / view.devicePixelRatio;
          if (flutterKbHeight > 0 && keyboardHeight > flutterKbHeight) {
            keyboardHeight = flutterKbHeight;
          }
        }

        // NOTE: Deliberately do NOT overwrite `_safeAreaBottom` from the native
        // plugin's `safeAreaBottom` field. It's captured once in
        // didChangeDependencies from `MediaQuery.paddingOf(context).bottom`,
        // which is the correct source of truth — it respects any `SafeArea`
        // ancestor and display-cutout consumption. The native value can differ
        // (iPads, gesture-nav, split-screen, `SafeArea(bottom: false)` wrappers)
        // and overwriting it here causes a visible gap when the keyboard is
        // closed. See bug notes `composer-big-safe-area-some-devices` and
        // `extra-space-composer-keyboard` (ENG-34434).

        // Track keyboard visibility
        final wasKeyboardVisible = _isKeyboardVisible;
        _isKeyboardVisible = keyboardHeight > 0;

        // Detect transition (keyboard visibility changed)
        final isVisibilityChange = wasKeyboardVisible != _isKeyboardVisible;

        // Resume protection: the OS sometimes fires a spurious close event right
        // after the open event when the app returns from background. Ignore it.
        if (isVisibilityChange &&
            !_isKeyboardVisible &&
            _ignoreNextKeyboardClose) {
          _isKeyboardVisible = true; // revert — keyboard is actually still open
          _ignoreNextKeyboardClose = false;
          _resumeProtectionTimer?.cancel();
          return;
        }

        if (isVisibilityChange) {
          _isTransitioning = true;
          // Cancel any pending debounced update
          _keyboardHeightDebouncer?.cancel();
        }

        // Track max bottom height when keyboard is open
        // IMPORTANT: Native keyboard height ALREADY includes safe area (on iOS: keyboardFrame.height,
        // on Android: screenHeight - visibleArea which includes nav bar)
        // So we DON'T add safe area again here
        if (_isKeyboardVisible) {
          _maxBottomHeight = keyboardHeight;
          // Keyboard opened - clear the expectation flag
          if (isVisibilityChange) {
            _expectingKeyboardOpen = false;
            _stickerHeightClearTimer?.cancel();
          }

          // Update stable keyboard height after a delay (when keyboard settles)
          // This prevents using fluctuating heights during animation
          // Only set stable height if we don't have one yet (first keyboard open)
          // This ensures we use a consistent height for the session
          if (_stableKeyboardHeight == 0) {
            _stableHeightTimer?.cancel();
            _stableHeightTimer = Timer(_stableHeightDelay, () {
              if (_isKeyboardVisible &&
                  !_isDisposing &&
                  _stableKeyboardHeight == 0) {
                _stableKeyboardHeight = _maxBottomHeight;
              }
            });
          }
        } else {
          // Keyboard closed - cancel stable height timer but DON'T clear stable height
          // We keep the stable height for future keyboard opens
          _stableHeightTimer?.cancel();
        }

        // Calculate target bottom padding
        // When keyboard is visible:
        //   - If we have a stable height cached, use it to prevent jiggle
        //   - Otherwise use the current keyboard height
        // When keyboard is closed:
        //   - If expecting keyboard to open (sticker→keyboard transition), maintain last sticker height
        //   - Otherwise, use safe area bottom
        double targetPadding;
        if (_isKeyboardVisible) {
          // Use stable height if available, otherwise use current height
          // This prevents the 383→336 jiggle during keyboard animation
          if (_stableKeyboardHeight > 0) {
            targetPadding = _stableKeyboardHeight;
          } else {
            targetPadding = keyboardHeight;
          }
        } else if (_expectingKeyboardOpen && _lastStickerTotalHeight > 0) {
          // During sticker→keyboard transition, maintain sticker height to prevent jump
          targetPadding = _lastStickerTotalHeight;
        } else {
          targetPadding = _safeAreaBottom;
        }

        // For visibility changes (keyboard opening/closing), apply immediately
        // For intermediate updates during animation, debounce to prevent jitter
        if (isVisibilityChange) {
          // Immediate update for visibility changes
          _applyBottomPadding(targetPadding);

          // Schedule end of transition after a short delay
          _keyboardHeightDebouncer?.cancel();
          _keyboardHeightDebouncer = Timer(_debounceDelay * 2, () {
            _isTransitioning = false;
          });
        } else if (_isTransitioning) {
          // During transition, debounce intermediate updates
          _pendingPadding = targetPadding;
          _keyboardHeightDebouncer?.cancel();
          _keyboardHeightDebouncer = Timer(_debounceDelay, () {
            if (!_isDisposing) {
              _applyBottomPadding(_pendingPadding);
            }
          });
        } else {
          // Normal update (not transitioning)
          _applyBottomPadding(targetPadding);
        }

        // Fire diagnostic — captures padding just written + native values.
        _emitKeyboardDiagnostics(
          CometChatKeyboardDiagnosticsSource.nativePlugin,
          nativeKeyboardHeight: keyboardHeight,
          nativeSafeAreaBottom: safeAreaBottom > 0 ? safeAreaBottom : null,
        );
      });
    } // end if (!widget.resizeToAvoidBottomInset)
  }

  /// Latest raw values received from the native `KeyboardHeightPlugin`.
  /// Cached so diagnostics sourced from non-plugin paths (viewInsets, resume,
  /// activate) can still report the last native sample alongside their own
  /// values.
  double _lastNativeKeyboardHeight = 0;
  double _lastNativeSafeAreaBottom = 0;

  /// Emits a keyboard diagnostics snapshot to the consumer callback.
  /// Safe to call during any phase — captures all current state and the most
  /// recently reported native values.
  void _emitKeyboardDiagnostics(
    CometChatKeyboardDiagnosticsSource source, {
    double? nativeKeyboardHeight,
    double? nativeSafeAreaBottom,
  }) {
    final callback = widget.onKeyboardDiagnostics;
    if (callback == null) return;
    if (_isDisposing || !mounted) return;

    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final dpr = view.devicePixelRatio;
    final viewInsetsBottom = view.viewInsets.bottom / dpr;
    final mqSafeBottom = MediaQuery.maybeOf(context)?.padding.bottom ?? 0.0;

    callback(
      CometChatKeyboardDiagnostics(
        source: source,
        nativeKeyboardHeight: nativeKeyboardHeight ?? _lastNativeKeyboardHeight,
        nativeSafeAreaBottom: nativeSafeAreaBottom ?? _lastNativeSafeAreaBottom,
        viewInsetsBottom: viewInsetsBottom,
        mediaQuerySafeAreaBottom: mqSafeBottom,
        appliedBottomPadding: _bottomPaddingNotifier.value,
        isKeyboardVisible: _isKeyboardVisible,
        stableKeyboardHeight: _stableKeyboardHeight,
        maxBottomHeight: _maxBottomHeight,
        devicePixelRatio: dpr,
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      ),
    );
  }

  /// Applies the bottom padding with change capping to prevent sudden jumps
  void _applyBottomPadding(double targetPadding) {
    double newPadding = targetPadding;

    // Apply smooth transition to prevent sudden jumps
    // But allow larger changes during transitions
    if (_lastBottomPadding > 0 && !_isTransitioning) {
      final change = targetPadding - _lastBottomPadding;
      if (change.abs() > _maxPaddingChangePerUpdate) {
        // Large change detected - this might be a glitch, cap it
        // But allow it if it's moving towards safe area (closing) or max height (opening)
        if (targetPadding != _safeAreaBottom &&
            targetPadding != _maxBottomHeight) {
          newPadding =
              _lastBottomPadding +
              (change > 0
                  ? _maxPaddingChangePerUpdate
                  : -_maxPaddingChangePerUpdate);
        }
      }
    }

    _lastBottomPadding = newPadding;

    _bottomPaddingNotifier.value = newPadding;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize theme once to avoid expensive lookups during keyboard animation
    // But re-initialize when brightness changes (dark mode toggle)
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (_themeInitialized && !brightnessChanged) return;
    _cachedBrightness = currentBrightness;
    _themeInitialized = true;

    // Cache safe area bottom for keyboard positioning
    _safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    // Initialize bottom padding with safe area (keyboard closed state)
    // But if keyboard is already open (e.g. hot restart), use viewInsets instead
    final currentViewInsets = MediaQuery.viewInsetsOf(context).bottom;
    if (currentViewInsets > 0) {
      // Keyboard is already open — seed with keyboard height
      _bottomPaddingNotifier.value = currentViewInsets;
      _isKeyboardVisible = true;
      _maxBottomHeight = currentViewInsets;
      _stableKeyboardHeight = currentViewInsets;
    } else {
      _bottomPaddingNotifier.value = _safeAreaBottom;
    }

    // Initialize theme
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    _typography = CometChatThemeHelper.getTypography(context);
    _spacing = CometChatThemeHelper.getSpacing(context);
    _style = CometChatThemeHelper.getTheme<CometChatMessageComposerStyle>(
      context: context,
      defaultTheme: CometChatMessageComposerStyle.of,
    ).merge(widget.messageComposerStyle);

    _suggestionListStyle =
        CometChatThemeHelper.getTheme<CometChatSuggestionListStyle>(
          context: context,
          defaultTheme: CometChatSuggestionListStyle.of,
        ).merge(_style.suggestionListStyle);

    // Initialize BLoC
    _initializeBloc();

    // Initialize formatters
    _initializeFormatters();

    // Initialize rich text formatter manager (must be before text controller creation)
    _initializeRichTextFormatting();

    // Initialize text editing controller with formatters
    // Use RichTextEditingController for WYSIWYG mode when rich text is enabled
    if (_textEditingController == null) {
      if (_useRichTextEditingController) {
        _textEditingController = RichTextEditingController(
          text: widget.text,
          formatters: _formatters,
        );
        // Add listener to update toolbar when selection changes (cursor moves into formatted text)
        _textEditingController!.addListener(_onRichTextControllerChanged);
        // Add listener to track text empty/non-empty for mic button visibility
        _textEditingController!.addListener(_onTextEmptyChanged);

        // Wire up link tap handler for Edit / Remove popup
        (_textEditingController as RichTextEditingController).onLinkTap =
            _onLinkTapped;

        // Wire up formatter notification for programmatic text changes
        // (editLinkFormat / removeLinkFormat) so mentions etc. stay in sync.
        (_textEditingController as RichTextEditingController)
                .onFormatterTextChanged =
            _onFormatterTextChanged;

        // Wire up segment controller to RichTextEditingController AFTER controller is created
        if (_segmentComposerController != null) {
          (_textEditingController as RichTextEditingController)
                  .onInsertCodeBlock =
              _segmentComposerController!.toggleCodeBlock;
        }
      } else {
        _textEditingController = CustomTextEditingController(
          text: widget.text,
          formatters: _formatters,
        );
        // Add listener to track text empty/non-empty for mic button visibility
        _textEditingController!.addListener(_onTextEmptyChanged);
      }
    }

    // Initialize attachment options
    if (!_getAttachmentOptionsCalled) {
      _getAttachmentOptionsCalled = true;
      _getAttachmentOptions();
    }

    // Initialize auxiliary options
    _auxiliaryOptions = _initAuxiliaryOptions();
  }

  @override
  void didUpdateWidget(covariant CometChatMessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A conversation switch on a REUSED composer instance must not carry staged
    // attachments across: the files were presigned for the previous recipient
    // and would otherwise be sent into the new conversation (R2). Drop the
    // composer-owned tray (aborting its in-flight uploads server-side) and
    // re-point the receiver. A host-supplied controller owns its own lifecycle,
    // so we leave it untouched.
    final oldConversation = oldWidget.user?.uid ?? oldWidget.group?.guid;
    final newConversation = widget.user?.uid ?? widget.group?.guid;
    if (oldConversation != newConversation) {
      _internalTrayController?.clear();
      _syncTrayReceiver();
    }

    // Reinitialize style if messageComposerStyle changed
    if (widget.messageComposerStyle != oldWidget.messageComposerStyle) {
      _style = CometChatThemeHelper.getTheme<CometChatMessageComposerStyle>(
        context: context,
        defaultTheme: CometChatMessageComposerStyle.of,
      ).merge(widget.messageComposerStyle);

      // Reinitialize auxiliary options since they depend on style
      _auxiliaryOptions = _initAuxiliaryOptions();
    }

    // Reinitialize rich text formatting if any rich-text-related prop changed
    final richTextPropsChanged =
        widget.enableRichTextFormatting != oldWidget.enableRichTextFormatting ||
        widget.showRichTextFormattingOptions !=
            oldWidget.showRichTextFormattingOptions ||
        !_setsEqual(
          widget.hideRichTextFormattingOptions,
          oldWidget.hideRichTextFormattingOptions,
        );
    if (richTextPropsChanged) {
      _initializeRichTextFormatting();
    }

    // Reinitialize auxiliary options if relevant props changed
    final stickerButtonChanged =
        widget.hideStickersButton != oldWidget.hideStickersButton ||
        widget.stickerIcon != oldWidget.stickerIcon ||
        widget.stickerActiveIcon != oldWidget.stickerActiveIcon;
    if (stickerButtonChanged) {
      _auxiliaryOptions = _initAuxiliaryOptions();
    }

    // Force rebuild if any visual property changed
    if (widget.messageComposerStyle != oldWidget.messageComposerStyle ||
        richTextPropsChanged ||
        stickerButtonChanged ||
        widget.hideSendButton != oldWidget.hideSendButton ||
        widget.hideAttachmentButton != oldWidget.hideAttachmentButton ||
        widget.hideVoiceRecordingButton != oldWidget.hideVoiceRecordingButton ||
        widget.placeholderText != oldWidget.placeholderText ||
        widget.maxLine != oldWidget.maxLine) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Cheap equality for [Set]s used by rich-text prop diffing.
  static bool _setsEqual(Set<FormatType> a, Set<FormatType> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  @override
  void didChangeMetrics() {
    // Called when keyboard finishes animating (viewInsets change)
    // Only reset keyboard height when keyboard is ACTUALLY closed
    // (not during the opening animation when viewInsets is still 0)
    if (_isDisposing) return;

    // Don't update keyboard height if we're not the current route (navigating away)
    // This prevents the composer from jumping when Navigator.pop is called
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return;
    }

    final viewInsets =
        WidgetsBinding.instance.platformDispatcher.views.first.viewInsets;
    final bottomInset =
        viewInsets.bottom /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    // Only reset if:
    // 1. viewInsets shows keyboard is closed (bottomInset == 0)
    // 2. Our notifier still has a value > safe area (meaning we were tracking an open keyboard)
    if (bottomInset == 0 &&
        _bottomPaddingNotifier.value > _safeAreaBottom &&
        !_isKeyboardVisible) {
      _bottomPaddingNotifier.value = _safeAreaBottom;
    }

    // Reconcile padding with Flutter's viewInsets when the keyboard is open
    // (ENG-34434). On some Android OEMs, the native plugin reports a
    // keyboardHeight that includes the gesture-nav / system bar, which is
    // larger than the actual space Flutter reclaims (viewInsets). The
    // in-callback clamp inside the native plugin handler caps
    // `keyboardHeight` to `viewInsets.bottom` BEFORE applying it — that
    // handles the Android overshoot case directly, because Android fires
    // `keyboardHeight` events AFTER Flutter's viewInsets have already
    // updated.
    //
    // A `didChangeMetrics` reconcile was tried here as a second safety net
    // for the case where native fires before viewInsets catch up. It was
    // removed (2026-05-06) because it regressed iOS. `didChangeMetrics` fires
    // on every animation frame; iOS `keyboardWillShow` arrives before
    // Flutter animates viewInsets 0 → final, and any gate short enough to
    // let the reconcile correct a legitimate overshoot is also short enough
    // to fire during the iOS animation tail — latching intermediate values
    // into `_stableKeyboardHeight` and leaving the composer 10-34 px below
    // the keyboard on subsequent opens.
    //
    // If a future OEM fires `keyboardHeight` before viewInsets, re-evaluate
    // — but only with a strict "N consecutive identical viewInsets readings"
    // settled-signal, never a timer/debouncer.

    // Fire diagnostic — helps catch cases where viewInsets disagree with the
    // native plugin (e.g. OEMs where ime() inset includes the gesture-nav bar).
    _emitKeyboardDiagnostics(CometChatKeyboardDiagnosticsSource.viewInsets);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isDisposing || !mounted) return;

    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — re-sync keyboard state.
      // The keyboard height plugin may not re-fire after resume, so we
      // read viewInsets directly to determine if the keyboard is still open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isDisposing || !mounted) return;

        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
        final keyboardOpen = bottomInset > 0;

        if (keyboardOpen) {
          // Keyboard is open — ensure our state reflects that and padding is correct.
          _isKeyboardVisible = true;
          final targetPadding = _stableKeyboardHeight > 0
              ? _stableKeyboardHeight
              : (_maxBottomHeight > 0 ? _maxBottomHeight : bottomInset);
          _applyBottomPadding(targetPadding);
        } else if (!keyboardOpen && _isKeyboardVisible) {
          // Keyboard closed while in background — reset to safe area.
          _ignoreNextKeyboardClose = false;
          _resumeProtectionTimer?.cancel();
          _isKeyboardVisible = false;
          _applyBottomPadding(_safeAreaBottom);
        }

        _emitKeyboardDiagnostics(CometChatKeyboardDiagnosticsSource.appResumed);

        // Defer clearing the protection flag to a second post-frame callback.
        // The keyboard height plugin may fire spurious close events during the
        // current or next frame after resume. Clearing too early lets those
        // events through, causing the composer to drop below the keyboard.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isDisposing || !mounted) return;
          _ignoreNextKeyboardClose = false;
          _resumeProtectionTimer?.cancel();
        });
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Going to background — reset transition flags so we start clean on resume.
      // Pre-arm the resume protection: if the keyboard is currently open, we expect
      // the plugin to fire open+close on resume. Set the flag now so it's ready
      // before any plugin callbacks fire (postFrameCallback would be too late).
      _isTransitioning = false;
      _keyboardHeightDebouncer?.cancel();
      if (_isKeyboardVisible) {
        _ignoreNextKeyboardClose = true;
        _resumeProtectionTimer?.cancel();
        // Auto-clear after a generous window in case resume never comes
        _resumeProtectionTimer = Timer(const Duration(seconds: 3), () {
          _ignoreNextKeyboardClose = false;
        });
      }
    }
  }

  @override
  void activate() {
    super.activate();
    // Reset the flag set by deactivate() — the widget is back in the tree
    // (e.g. user navigated back from image viewer / thread).
    _isDisposing = false;

    // Re-sync keyboard state from the current view insets so the composer
    // picks up the correct bottom padding after returning from navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposing) return;

      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
      final keyboardOpen = bottomInset > 0;

      if (keyboardOpen) {
        _isKeyboardVisible = true;
        final targetPadding = _stableKeyboardHeight > 0
            ? _stableKeyboardHeight
            : (_maxBottomHeight > 0 ? _maxBottomHeight : bottomInset);
        _applyBottomPadding(targetPadding);
      } else {
        _isKeyboardVisible = false;
        _applyBottomPadding(_safeAreaBottom);
      }

      _emitKeyboardDiagnostics(
        CometChatKeyboardDiagnosticsSource.widgetActivate,
      );
    });
  }

  @override
  void deactivate() {
    // Hide overlays, but only if we're not in the middle of a persistent
    // callbacks phase (e.g. during route transitions triggered by a rebuild).
    // Calling OverlayPortalController.hide() during persistentCallbacks
    // triggers a "schedulerPhase != SchedulerPhase.persistentCallbacks"
    // assertion because hide() marks the overlay entry as needing rebuild.
    final phase = SchedulerBinding.instance.schedulerPhase;
    final canHideOverlay = phase != SchedulerPhase.persistentCallbacks;

    if (canHideOverlay) {
      if (_attachmentOverlayController.isShowing) {
        _attachmentOverlayController.hide();
        _attachmentOpenNotifier.value = false;
      }
      if (_overlayPortalController.isShowing) {
        _overlayPortalController.hide();
        _suggestionOpenNotifier.value = false;
      }
    }
    // Set flag early to prevent keyboard height updates during navigation
    // deactivate() is called before dispose() when widget is removed from tree
    _isDisposing = true;
    super.deactivate();
  }

  @override
  void dispose() {
    // Flag already set in deactivate(), but set again for safety
    _isDisposing = true;

    // Only the internally-owned tray is disposed here (external ones belong to
    // the host).
    _internalTrayController?.dispose();

    // Cancel timers
    _keyboardHeightDebouncer?.cancel();
    _stickerHeightClearTimer?.cancel();
    _stableHeightTimer?.cancel();
    _resumeProtectionTimer?.cancel();

    // Dismiss sticker overlay if showing (web)
    _hideStickerOverlay();

    // Remove metrics observer
    WidgetsBinding.instance.removeObserver(this);

    // Close BLoC
    _bloc.onFocusRequested = null;
    _bloc.close();

    // Remove rich text controller listener and dispose if we created it
    if (_textEditingController is RichTextEditingController) {
      _textEditingController!.removeListener(_onRichTextControllerChanged);
      _textEditingController!.removeListener(_onTextEmptyChanged);
      // Clear callbacks
      (_textEditingController as RichTextEditingController).onInsertCodeBlock =
          null;
      (_textEditingController as RichTextEditingController).onLinkTap = null;
      (_textEditingController as RichTextEditingController)
              .onFormatterTextChanged =
          null;
    } else {
      // Remove text empty listener for non-rich-text controller
      _textEditingController?.removeListener(_onTextEmptyChanged);
    }
    if (_isMyController) {
      _textEditingController?.dispose();
    }

    // Dispose segment composer controller
    _segmentComposerController?.dispose();
    _segmentComposerController = null;

    // Remove the web paste + drag-drop listeners (no-op on native)
    web_paste.unregisterClipboardPasteListener(_pasteListenerHandle);
    _pasteListenerHandle = null;
    web_drop.unregisterFileDropListener(_dropListenerHandle);
    _dropListenerHandle = null;

    // Dispose focus node
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();

    // Cancel subscriptions
    _subscription.cancel();
    _suggestionListController.close();
    _previousTextController.close();

    // Dispose keyboard height plugin and notifiers
    _keyboardHeightPlugin.dispose();
    _bottomPaddingNotifier.dispose();
    _stickerExtraHeight.dispose();
    _attachmentOpenNotifier.dispose();
    _suggestionOpenNotifier.dispose();
    _activeFormatsNotifier.dispose();
    _previewAnimController.dispose();

    super.dispose();
  }

  // ============================================================================
  // Initialization Methods
  // ============================================================================

  void _initializeBloc() {
    _bloc = MessageComposerBloc(
      context: context,
      user: widget.user,
      group: widget.group,
      parentMessageId: widget.parentMessageId,
      disableTypingEvents: widget.disableTypingEvents,
      disableSoundForMessages: widget.disableSoundForMessages,
      customSoundForMessage: widget.customSoundForMessage,
      customSoundForMessagePackage: widget.customSoundForMessagePackage,
      onSendButtonTap: widget.onSendButtonTap,
      errorCallback: widget.onError,
    );

    // Provide state callback for backward compatibility
    if (widget.stateCallBack != null) {
      widget.stateCallBack!(_bloc);
    }

    // Wire up focus request callback so BLoC can request focus without owning FocusNode
    _bloc.onFocusRequested = () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    };
  }

  Map<String, dynamic> _buildComposerId() => buildUiEventId(
    uid: widget.user?.uid,
    guid: widget.group?.guid,
    parentMessageId: widget.parentMessageId,
  );

  void _initializeFormatters() {
    // Copy rather than alias: the list is mutated below (mention formatter
    // swap, defaults appended), and an integrator passing `const [...]`
    // would otherwise crash with "Cannot add to an unmodifiable list".
    _formatters = List<CometChatTextFormatter>.of(widget.textFormatters ?? []);

    int mentionFormatterIndex = _formatters.indexWhere(
      (element) => element is CometChatMentionsFormatter,
    );

    if (widget.disableMentions != true) {
      if (mentionFormatterIndex != -1) {
        _formatters[mentionFormatterIndex] = CometChatMentionsFormatter(
          style: _style.mentionsStyle,
          disableMentionAll: widget.disableMentionAll,
          mentionAllLabel: widget.mentionAllLabel,
          mentionAllLabelId: widget.mentionAllLabelId,
        );
      } else {
        var formatter = CometChatMentionsFormatter(
          style: _style.mentionsStyle,
          disableMentionAll: widget.disableMentionAll,
          mentionAllLabelId: widget.mentionAllLabelId,
          mentionAllLabel: widget.mentionAllLabel,
        );
        _formatters.add(formatter);
      }
    }

    for (var element in _formatters) {
      element.composerId = _composerId;
      element.suggestionListEventSink = _suggestionListController.sink;
      element.previousTextEventSink = _previousTextController.sink;
      element.onSearch = _onFormatterSearch;
      element.user = widget.user;
      element.group = widget.group;
      element.init();
    }
  }

  Widget? _initAuxiliaryOptions() {
    // If user provided a custom auxiliary button view, use that
    if (widget.auxiliaryButtonView != null) {
      return widget.auxiliaryButtonView!(
        context,
        widget.user,
        widget.group,
        _composerId,
      );
    }

    // Hide sticker button if explicitly requested
    if (widget.hideStickersButton == true) {
      return null;
    }

    return StickerAuxiliaryButton(
      composerId: _composerId,
      stickerButtonIcon: widget.stickerIcon,
      keyboardButtonIcon: widget.stickerActiveIcon,
      stickerIconTint:
          _style.stickerIconColor ?? _style.auxiliaryButtonIconColor,
      keyboardIconTint: _style.stickerActiveIconColor,
      onStickerTap: () {
        // Capture the keyboard height before dismissing so we can size the
        // sticker keyboard to match. Use stable height if available (avoids
        // jiggle from animation frames), otherwise fall back to current max.
        final double knownKeyboardHeight = _stableKeyboardHeight > 0
            ? _stableKeyboardHeight
            : _maxBottomHeight;

        // Dismiss OS keyboard by unfocusing whatever currently has focus.
        // Using primaryFocus instead of _focusNode because the active focus
        // may be on a segment composer's focus node, not the main text field.
        FocusManager.instance.primaryFocus?.unfocus();

        // Dismiss attachment overlay if showing
        if (_attachmentOverlayController.isShowing) {
          _attachmentOverlayController.hide();
          _attachmentOpenNotifier.value = false;
        }

        // On web with wide screens, show sticker keyboard as a floating popup
        // above the composer (like WhatsApp Web emoji picker)
        if (kIsWeb && MediaQuery.of(context).size.width > 600) {
          _showStickerOverlay(context);
          return;
        }

        // Calculate sticker keyboard content height.
        // knownKeyboardHeight is the full keyboard frame (includes safe area
        // on iOS). The sticker keyboard widget only needs the content portion;
        // safe area padding is handled by _buildBottomArea.
        final double stickerContentHeight =
            knownKeyboardHeight > _safeAreaBottom
            ? knownKeyboardHeight - _safeAreaBottom
            : CometChatStickerKeyboard.defaultHeight;

        // Reset any previous drag extra height
        _stickerExtraHeight.value = 0;

        // Show sticker keyboard in the footer panel
        CometChatUIEvents.showPanel(
          _composerId,
          CustomUIPosition.composerBottom,
          (context) => CometChatStickerKeyboard(
            height: stickerContentHeight,
            style: _style.stickerKeyboardStyle,
            onStickerTap: (Sticker sticker) {
              _bloc.add(
                SendCustomMessage(
                  customData: {
                    'sticker_url': sticker.stickerUrl,
                    'sticker_name': sticker.stickerName,
                  },
                  type: ExtensionType.sticker,
                ),
              );
              // Keep sticker keyboard open so user can send more stickers.
              // User can dismiss it manually via the keyboard toggle button.
            },
          ),
        );
      },
      onKeyboardTap: () {
        // Close the sticker panel and collapse the bottom area.
        _lastStickerTotalHeight = 0;
        _expectingKeyboardOpen = false;
        _stickerHeightClearTimer?.cancel();
        _resetStickerExtraHeight();

        // Dismiss web sticker overlay if showing
        _hideStickerOverlay();

        CometChatUIEvents.hidePanel(
          _composerId,
          CustomUIPosition.composerBottom,
        );

        if (mounted && !_isDisposing) {
          _bottomPaddingNotifier.value = _safeAreaBottom;
        }
      },
    );
  }

  void _initializeRichTextFormatting() {
    // Remove old markdown formatter from the formatters list
    if (_markdownFormatter != null) {
      _formatters.remove(_markdownFormatter);
      _markdownFormatter = null;
    }

    // Dispose old segment controller if exists
    _segmentComposerController?.dispose();
    _segmentComposerController = null;

    // Derive configuration from public props
    final enableBold = _isFormatEnabled(FormatType.bold);
    final enableItalic = _isFormatEnabled(FormatType.italic);
    final enableUnderline = _isFormatEnabled(FormatType.underline);
    final enableStrikethrough = _isFormatEnabled(FormatType.strikethrough);
    final enableInlineCode = _isFormatEnabled(FormatType.inlineCode);
    final enableCodeBlock = _isFormatEnabled(FormatType.codeBlock);
    final enableLinks = _isFormatEnabled(FormatType.link);
    final enableBulletList = _isFormatEnabled(FormatType.bulletList);
    final enableOrderedList = _isFormatEnabled(FormatType.orderedList);
    final enableBlockquote = _isFormatEnabled(FormatType.blockquote);

    // Bullet/ordered/blockquote implicitly enabled when code-block is enabled
    // (mirrors the old config's computed getters so list rendering keeps
    // working when only codeBlock is on).
    final effectiveBulletList = enableBulletList || enableCodeBlock;
    final effectiveOrderedList = enableOrderedList || enableCodeBlock;
    final effectiveBlockquote = enableBlockquote || enableCodeBlock;

    if (_hasAnyFormatEnabled) {
      // Use unified MarkdownTextFormatter for bubble display (replaces 10+ legacy classes)
      _markdownFormatter = MarkdownTextFormatter(
        enableBold: enableBold,
        enableItalic: enableItalic,
        enableStrikethrough: enableStrikethrough,
        enableUnderline: enableUnderline,
        enableInlineCode: enableInlineCode,
        enableCodeBlock: enableCodeBlock,
        enableLink: enableLinks,
        enableBulletList: effectiveBulletList,
        enableOrderedList: effectiveOrderedList,
        enableBlockquote: effectiveBlockquote,
      );
      _formatters.add(_markdownFormatter!);

      // Initialize segment-based code blocks when:
      // - code block is enabled, AND
      // - toolbar is visible in single-line layout (segment widget needs the
      //   stacked toolbar's persistent space).
      //
      // Skip in toggleable (double-line) mode: the toolbar-swap flow has its
      // own controller-binding rules and mixing a segment controller in
      // causes text-loss bugs (see [[toggleable-toolbar-text-lost-on-toggle]]).
      // Code block still works there via the backtick fallback in
      // `_wrapSelectionWithCodeBlockMarkdown`.
      if (enableCodeBlock && _useStackedToolbar) {
        _segmentComposerController = SegmentComposerController();
        // Pass text formatters (mentions, etc.) so normal segments use
        // CustomTextEditingController for styled text display
        _segmentComposerController!.formatters = _formatters.isNotEmpty
            ? _formatters
            : null;
        // Wire link tap handler so tapping a link in any segment shows Edit / Remove
        _segmentComposerController!.onLinkTap = _onLinkTapped;
        // Wire formatter notification for programmatic text changes in segments
        _segmentComposerController!.onFormatterTextChanged =
            _onFormatterTextChanged;
        _segmentComposerController!.addListener(() {
          if (!mounted) return;
          // Update active formats notifier so toolbar reflects code block state
          final currentFormats = _getActiveFormats();
          if (!_setEquals(currentFormats, _previousActiveFormats)) {
            _previousActiveFormats = currentFormats;
            _activeFormatsNotifier.value = currentFormats;
          }

          // When any segment gets focus, hide sticker keyboard and unlock bottom padding
          // (mirrors _onFocusChange behavior for the regular text field)
          final focused = _segmentComposerController!.focusedSegment;
          if (focused != null) {
            CometChatUIEvents.hidePanel(
              _composerId,
              CustomUIPosition.composerBottom,
            );
            CometChatUIEvents.unlockBottomPadding(_composerId);
            _resetStickerExtraHeight();
            if (_attachmentOverlayController.isShowing) {
              _hideAttachmentOverlay();
            }
          }

          setState(() {});
        });

        // Note: onInsertCodeBlock is wired up in didChangeDependencies after text controller is created
      }

      // Update toolbar visibility based on mode
      _updateRichTextToolbarVisibility();
    } else {
      // No rich text formatting enabled
      _showRichTextToolbar = false;
    }
  }

  void _updateRichTextToolbarVisibility() {
    if (!_useRichTextEditingController) {
      _showRichTextToolbar = false;
      return;
    }

    // Stacked toolbar is only shown in single-line layout. Double-line uses
    // the toggleable swap-row flow instead.
    _showRichTextToolbar = _useStackedToolbar;
  }

  /// Whether the format-toggle swap row is currently active.
  ///
  /// True when:
  /// 1. The toggleable (double-line) toolbar flow is enabled, AND
  /// 2. The user has tapped the `Aa` toggle and not dismissed it yet.
  ///
  /// When this is true the composer hides the usual action row (divider +
  /// buttons) and renders `[✕] + <toolbar>` in its place.
  bool get _isToolbarSwapActive =>
      _useToggleableToolbar && _isToolbarToggleOpen;

  /// Whether the `Aa` format toggle should be shown in the auxiliary cluster.
  bool get _shouldShowFormatToggle =>
      _useToggleableToolbar && _hasAnyFormatEnabled;

  void _toggleRichTextSwap() {
    // When closing the swap row, keep already-formatted text intact but
    // disable formatting for any future typing. Use `clearPendingFormats()`
    // (not `clearFormatting()`) so existing bold/italic/etc. spans stay as
    // they are and only new insertions revert to plain.
    final closing = _isToolbarToggleOpen;
    if (closing) {
      if (_textEditingController is RichTextEditingController) {
        (_textEditingController as RichTextEditingController)
            .clearPendingFormats();
      }
      // Reset toolbar's active-format notifier so any highlighted buttons
      // deactivate immediately (they'll light up again on their own if the
      // cursor later lands inside an existing formatted span).
      _previousActiveFormats = const {};
      _activeFormatsNotifier.value = const {};
    }
    setState(() {
      _isToolbarToggleOpen = !_isToolbarToggleOpen;
    });
  }

  void _getAttachmentOptions() {
    final attachmentOptionSheetStyle =
        CometChatThemeHelper.getTheme<CometChatAttachmentOptionSheetStyle>(
          context: context,
          defaultTheme: CometChatAttachmentOptionSheetStyle.of,
        ).merge(_style.attachmentOptionSheetStyle);

    if (widget.attachmentOptions != null) {
      List<CometChatMessageComposerAction> actionList =
          widget.attachmentOptions!(context, widget.user, widget.group, {});

      for (CometChatMessageComposerAction attachmentOption in actionList) {
        _actionStyle = CometChatAttachmentOptionSheetStyle(
          border:
              attachmentOption.style?.border ??
              attachmentOptionSheetStyle.border,
          borderRadius:
              attachmentOption.style?.borderRadius ??
              attachmentOptionSheetStyle.borderRadius,
          titleColor:
              attachmentOption.style?.titleColor ??
              attachmentOptionSheetStyle.titleColor,
          backgroundColor:
              attachmentOption.style?.backgroundColor ??
              attachmentOptionSheetStyle.backgroundColor,
          iconColor:
              attachmentOption.style?.iconColor ??
              attachmentOptionSheetStyle.iconColor,
          titleTextStyle:
              attachmentOption.style?.titleTextStyle ??
              attachmentOptionSheetStyle.titleTextStyle,
        );
        _actionItems.add(
          ActionItem(
            id: attachmentOption.id,
            title: attachmentOption.title,
            icon: attachmentOption.icon,
            style: CometChatAttachmentOptionSheetStyle(
              titleTextStyle: TextStyle(
                color: _actionStyle?.titleColor,
                fontSize: _typography.body?.regular?.fontSize,
                fontWeight: _typography.body?.regular?.fontWeight,
              ).merge(_actionStyle?.titleTextStyle),
              backgroundColor: _actionStyle?.backgroundColor,
              iconColor: _actionStyle?.iconColor,
              titleColor: _actionStyle?.titleColor,
              borderRadius: _actionStyle?.borderRadius,
              border: _actionStyle?.border,
            ).merge(_actionStyle),
            onItemClick: attachmentOption.onItemClick,
          ),
        );
      }
    } else {
      _getDefaultAttachmentOptions(attachmentOptionSheetStyle);
    }
  }

  void _getDefaultAttachmentOptions(
    CometChatAttachmentOptionSheetStyle attachmentOptionSheetStyle,
  ) {
    AdditionalConfigurations additionalConfigurations =
        AdditionalConfigurations(
          attachmentOptionSheetStyle: attachmentOptionSheetStyle,
          hideAudioAttachmentOption: widget.hideAudioAttachmentOption,
          hideCollaborativeDocumentOption:
              widget.hideCollaborativeDocumentOption,
          hideCollaborativeWhiteboardOption:
              widget.hideCollaborativeWhiteboardOption,
          hideFileAttachmentOption: widget.hideFileAttachmentOption,
          hideImageAttachmentOption: widget.hideImageAttachmentOption,
          hidePollsOption: widget.hidePollsOption,
          hideVideoAttachmentOption: widget.hideVideoAttachmentOption,
          hideTakPhotoOption: widget.hideTakePhotoOption,
        );
    final defaultOptions = ComposerAttachmentUtils.getAttachmentOptions(
      context,
      _composerId,
      additionalConfigurations,
    );
    for (CometChatMessageComposerAction defaultAttachmentOptions
        in defaultOptions) {
      _actionStyle = CometChatAttachmentOptionSheetStyle(
        border: defaultAttachmentOptions.style?.border,
        borderRadius: defaultAttachmentOptions.style?.borderRadius,
        titleColor: defaultAttachmentOptions.style?.titleColor,
        backgroundColor: defaultAttachmentOptions.style?.backgroundColor,
        iconColor: defaultAttachmentOptions.style?.iconColor,
        titleTextStyle: defaultAttachmentOptions.style?.titleTextStyle,
      );
      _actionItems.add(
        ActionItem(
          id: defaultAttachmentOptions.id,
          title: defaultAttachmentOptions.title,
          icon: defaultAttachmentOptions.icon,
          style: CometChatAttachmentOptionSheetStyle(
            titleTextStyle: TextStyle(
              color: _actionStyle?.titleColor,
              fontSize: _typography.body?.regular?.fontSize,
              fontWeight: _typography.body?.regular?.fontWeight,
            ).merge(_actionStyle?.titleTextStyle),
            backgroundColor: _actionStyle?.backgroundColor,
            iconColor: _actionStyle?.iconColor,
            titleColor: _actionStyle?.titleColor,
            borderRadius: _actionStyle?.borderRadius,
            border: _actionStyle?.border,
          ).merge(_actionStyle),
          onItemClick: defaultAttachmentOptions.onItemClick,
        ),
      );
    }
  }

  // ============================================================================
  // Focus Debouncer (for keyboard transition performance)
  // ============================================================================
  final Debouncer _focusDebouncer = Debouncer(milliseconds: 250);

  // ============================================================================
  // Event Handlers
  // ============================================================================

  /// Reset sticker drag height when sticker panel closes.
  void _resetStickerExtraHeight() {
    _stickerExtraHeight.value = 0;
  }

  // ============================================================================
  // Web Sticker Overlay (WhatsApp Web-style floating popup)
  // ============================================================================

  OverlayEntry? _stickerOverlayEntry;

  void _showStickerOverlay(BuildContext context) {
    // If already showing, dismiss it (toggle behavior)
    if (_stickerOverlayEntry != null) {
      _hideStickerOverlay();
      return;
    }

    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    // The popup's own fill matches the keyboard inside it.
    final keyboardBackground =
        CometChatThemeHelper.getTheme<CometChatStickerKeyboardStyle>(
          context: context,
          defaultTheme: CometChatStickerKeyboardStyle.of,
        ).merge(_style.stickerKeyboardStyle).backgroundColor;
    // Use the root overlay to ensure correct positioning in nested navigator layouts
    final overlay = Overlay.of(context, rootOverlay: true);

    // Get the composer's position to anchor the popup above it
    final RenderBox? composerBox = context.findRenderObject() as RenderBox?;
    if (composerBox == null) return;
    final composerPosition = composerBox.localToGlobal(Offset.zero);
    final composerWidth = composerBox.size.width;

    // Popup dimensions — similar to WhatsApp Web emoji picker
    const double popupWidth = 360;
    const double popupHeight = 400;

    // Position: anchored to the bottom-right of the composer, floating above the sticker icon
    final double screenWidth = MediaQuery.of(context).size.width;
    // right inset = distance from screen right edge to composer's right edge
    final double composerRight =
        screenWidth - (composerPosition.dx + composerWidth);
    final double right = composerRight.clamp(8, screenWidth - popupWidth - 24);
    // Use the actual screen height from the root view for correct positioning
    // in nested navigator layouts (e.g., split-pane desktop layout)
    final double screenHeight = MediaQuery.of(context).size.height;
    final double bottom = screenHeight - composerPosition.dy + 8;

    _stickerOverlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          // Tap-away dismissal barrier
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideStickerOverlay,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          // Floating sticker popup
          Positioned(
            right: right,
            bottom: bottom,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              color:
                  keyboardBackground ??
                  colorPalette.background1 ??
                  Colors.white,
              child: SizedBox(
                width: popupWidth.clamp(0, composerWidth.toDouble()),
                height: popupHeight,
                child: CometChatStickerKeyboard(
                  height: popupHeight - 16,
                  style: _style.stickerKeyboardStyle,
                  onStickerTap: (Sticker sticker) {
                    _bloc.add(
                      SendCustomMessage(
                        customData: {
                          'sticker_url': sticker.stickerUrl,
                          'sticker_name': sticker.stickerName,
                        },
                        type: ExtensionType.sticker,
                      ),
                    );
                    // Collapse popup after sending sticker
                    _hideStickerOverlay();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_stickerOverlayEntry!);
  }

  void _hideStickerOverlay() {
    _stickerOverlayEntry?.remove();
    _stickerOverlayEntry = null;
    // Notify StickerAuxiliaryButton to update its icon state
    CometChatUIEvents.hidePanel(_composerId, CustomUIPosition.composerBottom);
  }

  void _onFocusChange() {
    if (!mounted) return;

    if (_focusNode.hasFocus) {
      // When text field gets focus, hide sticker keyboard immediately
      // (no debounce) so the panel disappears as the OS keyboard opens.
      CometChatUIEvents.hidePanel(_composerId, CustomUIPosition.composerBottom);
      CometChatUIEvents.unlockBottomPadding(_composerId);
      _resetStickerExtraHeight();
      // Dismiss attachment overlay when text field gains focus
      if (_attachmentOverlayController.isShowing) {
        _hideAttachmentOverlay();
      }
    } else {
      // Debounce focus-loss to avoid triggering panel events during
      // keyboard animation (e.g. sticker tap calls unfocus first).
      _focusDebouncer.run(() {
        if (!mounted) return;
        _initializeFooterView();
      });
    }
  }

  /// Called on every text change to detect empty↔non-empty transitions.
  /// Triggers setState only when the boolean flips so the auxiliary buttons
  /// (mic) rebuild with the correct hideVoiceRecordingButton value.
  void _onTextEmptyChanged() {
    if (!mounted) return;
    final hasText = _textEditingController!.text.isNotEmpty;
    if (hasText != _hadText) {
      _hadText = hasText;
      setState(() {});
    }
  }

  /// Called when the RichTextEditingController changes (text or selection)
  /// Only updates the ValueNotifier when active formats actually change
  void _onRichTextControllerChanged() {
    if (!mounted) return;

    // Get current active formats
    final currentFormats = _getActiveFormats();

    // Only update if formats changed (avoid unnecessary rebuilds)
    if (!_setEquals(currentFormats, _previousActiveFormats)) {
      _previousActiveFormats = currentFormats;
      _activeFormatsNotifier.value = currentFormats;
    }
  }

  /// Compare two sets for equality
  bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  void _onFormatterSearch(String? searchKeyword) {
    _searchKeywordChanged = _currentSearchKeyword != searchKeyword;
    _currentSearchKeyword = searchKeyword;

    if (_currentSearchKeyword == null) {
      CometChatUIEvents.hidePanel(
        _composerId,
        CustomUIPosition.composerPreview,
      );
      _suggestions.clear();
    }
    setState(() {});
  }

  void _onSuggestionListUpdate(List<SuggestionListItem> value) {
    bool shouldScrollDown = false;
    if (value.isNotEmpty && _currentSearchKeyword != null) {
      if (_searchKeywordChanged) {
        _suggestions = value;
        _searchKeywordChanged = false;
      } else {
        for (var element in value) {
          if (!_suggestions.contains(element)) {
            _suggestions.add(element);
          }
        }
        shouldScrollDown = true;
      }
      _hasMore = true;
      setState(() {});

      CometChatUIEvents.showPanel(
        _composerId,
        CustomUIPosition.composerPreview,
        (context) => _buildSuggestionList(),
      );
      _overlayPortalController.show();
      _suggestionOpenNotifier.value = true;
      // Dismiss attachment overlay when suggestion list appears
      if (_attachmentOverlayController.isShowing) {
        _hideAttachmentOverlay();
      }
      if (shouldScrollDown) {
        _scrollDown();
      } else {
        if (_searchKeywordChanged) {
          CometChatUIEvents.hidePanel(
            _composerId,
            CustomUIPosition.composerPreview,
          );
          _suggestions.clear();
        }
        _hasMore = false;
        setState(() {});
      }
    }
  }

  void _scrollDown() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _checkFormatter() {
    // Use the focused segment's controller when in segment mode,
    // so formatters (mentions, etc.) see the correct text and cursor position.
    final activeController = _getActiveTextController();
    if (activeController == null) return;

    // In segment mode, use the focused segment's per-segment previousText
    // so the mentions formatter doesn't see a diff from a different segment.
    final prevText = _getSegmentPreviousText() ?? _previousText;

    for (var element in _formatters) {
      if (_currentSearchKeyword == null ||
          (_currentSearchKeyword != null &&
              _currentSearchKeyword!.isNotEmpty &&
              element.trackingCharacter == _currentSearchKeyword![0])) {
        try {
          element.onChange(activeController, prevText);
        } catch (err) {
          if (kDebugMode) {}
        }
      }
    }
  }

  /// Returns the focused segment's [previousText] when in segment mode,
  /// or null if not in segment mode / no focused segment.
  String? _getSegmentPreviousText() {
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      final focused = _segmentComposerController!.focusedSegment;
      if (focused != null && focused.type == SegmentType.normal) {
        return focused.previousText;
      }
    }
    return null;
  }

  /// Updates the focused segment's [previousText] when in segment mode,
  /// and also keeps the global [_previousText] in sync.
  void _updatePreviousText(String newText) {
    _previousText = newText;
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      final focused = _segmentComposerController!.focusedSegment;
      if (focused != null && focused.type == SegmentType.normal) {
        focused.previousText = newText;
      }
    }
  }

  /// Returns the text controller that formatters should operate on.
  /// In segment mode, returns the focused normal segment's controller
  /// so mentions/suggestions work within the active segment.
  /// Falls back to the main _textEditingController otherwise.
  TextEditingController? _getActiveTextController() {
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      final focused = _segmentComposerController!.focusedSegment;
      if (focused != null && focused.type == SegmentType.normal) {
        return focused.controller;
      }
      // If focused segment is code or null, don't run formatters
      return null;
    }
    return _textEditingController;
  }

  void _onTyping() {
    final activeController = _getActiveTextController();
    // Allow typing events even when no active text controller (e.g. code segment)
    // but skip formatter checks
    if (activeController == null) {
      if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
        // Still trigger typing event for code segments
        _bloc.add(const StartTyping());
      }
      return;
    }
    // Use per-segment previousText in segment mode so formatter diffs are correct
    final prevText = _getSegmentPreviousText() ?? _previousText;
    if ((prevText.isEmpty && activeController.text.isNotEmpty) ||
        (prevText.isNotEmpty && activeController.text.isEmpty)) {
      setState(() {});
    }
    if (prevText.length > activeController.text.length) {
      _checkFormatter();
      _updatePreviousText(activeController.text);
      return;
    }

    _checkFormatter();
    _updatePreviousText(activeController.text);

    // Trigger typing event through BLoC
    _bloc.add(const StartTyping());
  }

  void _onChange(dynamic val) {
    // Determine the active text controller for formatter operations
    final activeController = _getActiveTextController();

    // Get the text from the active controller for BLoC updates
    final activeText =
        activeController?.text ?? _textEditingController?.text ?? '';

    if (widget.onChange != null) {
      widget.onChange!(activeText);
    }
    _onTyping();
    _bloc.add(UpdateComposeText(activeText));
  }

  // ============================================================================
  // Message Handling
  // ============================================================================

  void _handlePreMessageSend(BaseMessage baseMessage) {
    for (var element in _formatters) {
      element.handlePreMessageSend(context, baseMessage);
    }
  }

  void _onSendButtonClick() {
    // Block sending while AI is streaming
    if (_bloc.state.isActiveStreaming) return;

    // Get text from segment controller or text editing controller
    String? text;
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      text = _segmentComposerController!.finalText.trim();
    } else {
      text = _textEditingController?.text.trim();
    }

    // Staging tray: if attachments are uploaded, the send button sends them as
    // one message per attachment kind (using the typed text as the caption on
    // the last), then clears the composer input exactly like a normal text send.
    final tray = _tray;
    // Mirror the send button's disabled gate exactly: with anything staged,
    // sending is allowed only once every attachment has finished uploading and
    // none is in error. Guarding only `hasErrors` left the still-uploading case
    // to fall through to the plain-text branch below, which sent the typed text
    // on its own and orphaned the in-flight attachments — reachable even with
    // the button disabled, via the keyboard's send key / Enter.
    if (tray != null && tray.tiles.isNotEmpty && !tray.canSend) return;
    if (tray != null && tray.canSend) {
      // Capture the caption exactly like a normal text send: rich-text input is
      // serialized to markdown so the gallery caption renders identical
      // formatting (bold/italic/code/etc.) through the same formatter pipeline.
      String captionText;
      if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
        captionText = _segmentComposerController!.finalText;
      } else if (_textEditingController is RichTextEditingController) {
        captionText = (_textEditingController as RichTextEditingController)
            .toMarkdown();
      } else {
        captionText = _textEditingController?.text ?? '';
      }
      tray.caption = captionText.trim();
      // Host override wins (back-compat); otherwise the composer sends the
      // batch itself — one message per attachment kind, grouped by batchId.
      if (widget.onAttachmentTraySend != null) {
        widget.onAttachmentTraySend!.call();
      } else {
        _sendStagedBatch(tray);
      }
      // Clear formatting + content (mirrors _sendTextMessage).
      if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
        _segmentComposerController!.clear();
      } else if (_textEditingController is RichTextEditingController) {
        (_textEditingController as RichTextEditingController).clearFormatting();
      }
      _textEditingController?.clear();
      _previousText = '';
      _hideSuggestionOverlay();
      _previousActiveFormats = {};
      _activeFormatsNotifier.value = {};
      setState(() {});
      return;
    }

    // Don't send if text is empty or contains only line-format prefixes
    // (e.g. "1. ", "- ", "> ", "> > " with no actual content)
    if (text == null || text.isEmpty || _isOnlyLineFormatPrefix(text)) return;

    if (_bloc.state.isEditMode) {
      _editTextMessage();
    } else if (_bloc.state.isReplyMode) {
      _sendTextMessageWithReply();
    } else {
      _sendTextMessage();
    }
  }

  /// Returns true if the text contains only line-format prefixes with no real content.
  /// Handles ordered lists (1. ), bullets (- ), and blockquotes (> ) including nested.
  static bool _isOnlyLineFormatPrefix(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      // Strip all leading blockquote markers ("> " or ">")
      String stripped = line;
      while (stripped.startsWith('> ') || stripped.startsWith('>')) {
        stripped = stripped.startsWith('> ')
            ? stripped.substring(2)
            : stripped.substring(1);
      }
      stripped = stripped.trim();
      // Strip ordered list prefix (e.g. "1. ", "12. ")
      stripped = stripped.replaceFirst(RegExp(r'^\d+\.\s*$'), '');
      // Strip bullet prefix
      stripped = stripped.replaceFirst(RegExp(r'^[-*]\s*$'), '');
      if (stripped.isNotEmpty) return false;
    }
    return true;
  }

  void _sendTextMessage() {
    if (_textEditingController == null && _segmentComposerController == null) {
      return;
    }

    // Get text from segment controller or text editing controller
    String messagesText;
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      messagesText = _segmentComposerController!.finalText;
    } else if (_textEditingController is RichTextEditingController) {
      messagesText = (_textEditingController as RichTextEditingController)
          .toMarkdown();
    } else {
      messagesText = _textEditingController!.text;
    }

    TextMessage textMessage = TextMessage(
      sender: _bloc.state.loggedInUser,
      text: messagesText,
      receiverUid: _bloc.state.receiverId,
      receiverType: _bloc.state.receiverType,
      type: MessageTypeConstants.text,
      parentMessageId: widget.parentMessageId,
      muid: DateTime.now().microsecondsSinceEpoch.toString(),
      category: CometChatMessageCategory.message,
      sentAt: DateTime.now(),
    );

    _handlePreMessageSend(textMessage);
    textMessage.text = textMessage.text.trim();

    // Clear formatting and content
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      _segmentComposerController!.clear();
    } else if (_textEditingController is RichTextEditingController) {
      (_textEditingController as RichTextEditingController).clearFormatting();
    }
    _textEditingController?.clear();
    _previousText = '';
    _hideSuggestionOverlay();
    // Reset active formats so toolbar reflects cleared state
    _previousActiveFormats = {};
    _activeFormatsNotifier.value = {};
    setState(() {});

    if (widget.onSendButtonTap != null) {
      widget.onSendButtonTap!(context, textMessage, PreviewMessageMode.none);
    } else {
      _bloc.add(SendTextMessage(processedMessage: textMessage));
    }
  }

  void _sendTextMessageWithReply() {
    if (_textEditingController == null && _segmentComposerController == null) {
      return;
    }

    // Get text from segment controller or text editing controller
    String messagesText;
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      messagesText = _segmentComposerController!.finalText;
    } else if (_textEditingController is RichTextEditingController) {
      messagesText = (_textEditingController as RichTextEditingController)
          .toMarkdown();
    } else {
      messagesText = _textEditingController!.text;
    }

    TextMessage textMessage = TextMessage(
      sender: _bloc.state.loggedInUser,
      text: messagesText,
      receiverUid: _bloc.state.receiverId,
      receiverType: _bloc.state.receiverType,
      type: MessageTypeConstants.text,
      parentMessageId: widget.parentMessageId,
      muid: DateTime.now().microsecondsSinceEpoch.toString(),
      category: CometChatMessageCategory.message,
      sentAt: DateTime.now(),
    );

    // Set quoted message fields from reply state
    if (_bloc.state.replyMessage != null) {
      textMessage.quotedMessage = _bloc.state.replyMessage;
      if (_bloc.state.replyMessage!.id > 0) {
        textMessage.quotedMessageId = _bloc.state.replyMessage!.id;
      }
    }

    _handlePreMessageSend(textMessage);
    textMessage.text = textMessage.text.trim();

    // Clear formatting and content
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      _segmentComposerController!.clear();
    } else if (_textEditingController is RichTextEditingController) {
      (_textEditingController as RichTextEditingController).clearFormatting();
    }
    _textEditingController?.clear();
    _previousText = '';
    _hideSuggestionOverlay();

    // Clear reply state immediately before sending
    _bloc.add(const ClearReplyMessage());

    // Reset active formats so toolbar reflects cleared state
    _previousActiveFormats = {};
    _activeFormatsNotifier.value = {};
    setState(() {});

    if (widget.onSendButtonTap != null) {
      widget.onSendButtonTap!(context, textMessage, PreviewMessageMode.reply);
    } else {
      _bloc.add(SendTextMessage(processedMessage: textMessage));
    }
  }

  void _editTextMessage() {
    if (_textEditingController == null && _segmentComposerController == null) {
      return;
    }
    final state = _bloc.state;
    final editTarget = state.editMessage;
    if (editTarget == null ||
        (editTarget is! TextMessage && editTarget is! MediaMessage)) {
      return;
    }

    // Get text from segment controller or text editing controller
    String newText;
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      newText = _segmentComposerController!.finalText;
    } else if (_textEditingController is RichTextEditingController) {
      newText = (_textEditingController as RichTextEditingController)
          .toMarkdown();
    } else {
      newText = _textEditingController!.text;
    }

    // Create a copy — do NOT mutate the original message object.
    // The original is the same reference held by the message list's state.
    // Mutating it in-place causes BLoC's Equatable deduplication to suppress
    // the subsequent emit when the SDK returns the edited message, because
    // the "old" list already contains the mutated text.
    final BaseMessage editedMessage;
    if (editTarget is TextMessage) {
      if (!_hasMeaningfulChange(editTarget.text, newText)) return;
      editedMessage = TextMessage(
        id: editTarget.id,
        sender: editTarget.sender,
        receiver: editTarget.receiver,
        text: newText,
        receiverUid: editTarget.receiverUid,
        receiverType: editTarget.receiverType,
        type: editTarget.type,
        metadata: editTarget.metadata != null
            ? Map<String, dynamic>.from(editTarget.metadata!)
            : null,
        parentMessageId: editTarget.parentMessageId,
        muid: editTarget.muid,
        category: editTarget.category,
        sentAt: editTarget.sentAt,
        deliveredAt: editTarget.deliveredAt,
        readAt: editTarget.readAt,
        readByMeAt: editTarget.readByMeAt,
        deliveredToMeAt: editTarget.deliveredToMeAt,
        updatedAt: editTarget.updatedAt,
        conversationId: editTarget.conversationId,
        replyCount: editTarget.replyCount,
        mentionedUsers: editTarget.mentionedUsers,
        hasMentionedMe: editTarget.hasMentionedMe,
        reactions: editTarget.reactions,
        tags: editTarget.tags,
        quotedMessage: editTarget.quotedMessage,
        quotedMessageId: editTarget.quotedMessageId,
      );
    } else {
      // Caption-bearing MediaMessage: edit only the caption. Requires an
      // existing non-empty caption and a non-empty, meaningful change.
      final media = editTarget as MediaMessage;
      final oldCaption = media.caption ?? '';
      if (oldCaption.trim().isEmpty) return;
      if (newText.trim().isEmpty) return;
      if (!_hasMeaningfulChange(oldCaption, newText)) return;
      editedMessage = MessageComposerBloc.cloneMediaWithCaption(
        media,
        newText.trim(),
      );
    }
    _handlePreMessageSend(editedMessage);

    // Clear formatting and content
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      _segmentComposerController!.clear();
    } else if (_textEditingController is RichTextEditingController) {
      (_textEditingController as RichTextEditingController).clearFormatting();
    }
    _textEditingController?.clear();
    _previousText = '';
    _hideSuggestionOverlay();
    // Reset active formats so toolbar reflects cleared state
    _previousActiveFormats = {};
    _activeFormatsNotifier.value = {};
    setState(() {});

    if (widget.onSendButtonTap != null) {
      _bloc.add(const ClearComposer());
      widget.onSendButtonTap!(context, editedMessage, PreviewMessageMode.edit);
    } else {
      _bloc.add(EditTextMessage(processedMessage: editedMessage));
    }
  }

  bool _hasMeaningfulChange(String original, String edited) {
    return original.trim() != edited.trim();
  }

  /// Sends the staged tray attachments as one message per attachment kind
  /// (image → video → audio → file), all sharing a metadata `batchId`. Fires
  /// the optimistic events in kind order, then sends SEQUENTIALLY so the
  /// server assigns monotonically increasing ids in that order (concurrent
  /// sends would let the batch reorder on reload / for the recipient).
  Future<void> _sendStagedBatch(AttachmentTrayController tray) async {
    final msgs = tray.buildBatchMessages(
      receiverUid: _bloc.state.receiverId,
      receiverType: _bloc.state.receiverType,
      sender: _bloc.state.loggedInUser,
    );
    if (msgs.isEmpty) return;

    // Reply mode: the quoted message rides on the FIRST message of the batch
    // (the caption rides on the last), then the reply preview is cleared —
    // mirroring the single-message send flows.
    final replyMsg = _bloc.state.isReplyMode ? _bloc.state.replyMessage : null;
    if (replyMsg != null) {
      msgs.first.quotedMessage = replyMsg;
      if (replyMsg.id > 0) {
        msgs.first.quotedMessageId = replyMsg.id;
      }
      _bloc.add(const ClearComposer());
    }

    // Reset the tray UI + release the SDK upload group (attachments are
    // already captured in [msgs]).
    unawaited(tray.clear());

    for (final msg in msgs) {
      msg.parentMessageId = widget.parentMessageId;
      CometChatMessageEvents.ccMessageSent(
        msg,
        core_enums.MessageStatus.inProgress,
      );
    }
    for (final msg in msgs) {
      await _sendOneBatchMessage(msg);
    }
  }

  /// Sends one batch message and completes when the server responds, so the
  /// caller can serialize sends.
  Future<void> _sendOneBatchMessage(MediaMessage msg) {
    final completer = Completer<void>();
    CometChat.sendMediaMessage(
      msg,
      onSuccess: (MediaMessage sent) {
        if (sent.muid.isEmpty) sent.muid = msg.muid;
        // Preserve batch metadata if the server didn't echo it back.
        sent.metadata ??= msg.metadata;
        CometChatMessageEvents.ccMessageSent(
          sent,
          core_enums.MessageStatus.sent,
        );
        if (!completer.isCompleted) completer.complete();
      },
      onError: (CometChatException e) {
        msg.metadata = {...?msg.metadata, 'error': e.message};
        CometChatMessageEvents.ccMessageSent(
          msg,
          core_enums.MessageStatus.error,
        );
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  void _sendMediaRecording(BuildContext ctx, String path) {
    // Mark recorded audio as a voice note so the list renders it with the
    // waveform VoiceNoteBubble instead of the audio-file rows.
    final metadata = <String, dynamic>{
      'localPath': path,
      CometChatVoiceNoteBubble.audioTypeKey:
          CometChatVoiceNoteBubble.audioTypeVoiceNote,
    };
    if (widget.onSendButtonTap != null) {
      MediaMessage mediaMessage = MediaMessage(
        receiverType: _bloc.state.receiverType,
        type: MessageTypeConstants.audio,
        receiverUid: _bloc.state.receiverId,
        file: path,
        sender: _bloc.state.loggedInUser,
        parentMessageId: widget.parentMessageId,
        muid: DateTime.now().microsecondsSinceEpoch.toString(),
        category: CometChatMessageCategory.message,
        metadata: metadata,
        sentAt: DateTime.now(),
      );

      // Set quoted message fields if in reply mode
      final replyMsg = _bloc.state.replyMessage;
      PreviewMessageMode mode = PreviewMessageMode.none;
      if (_bloc.state.isReplyMode && replyMsg != null) {
        mediaMessage.quotedMessage = replyMsg;
        if (replyMsg.id > 0) {
          mediaMessage.quotedMessageId = replyMsg.id;
        }
        mode = PreviewMessageMode.reply;
        _bloc.add(const ClearComposer());
      }

      widget.onSendButtonTap!(context, mediaMessage, mode);
    } else {
      _bloc.add(
        SendMediaMessage(
          path: path,
          messageType: MessageTypeConstants.audio,
          metadata: metadata,
        ),
      );
    }
  }

  void _previewMessage(BaseMessage message, PreviewMessageMode mode) {
    if (mode == PreviewMessageMode.edit) {
      _bloc.add(SetEditMessage(message));
      _overlayPortalController.show();

      if (message is TextMessage) {
        int mentionFormatterIndex = _formatters.indexWhere(
          (element) => element is CometChatMentionsFormatter,
        );

        // In segment mode, populate the segment controller with the edit text
        if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
          String editText = message.text;
          if (mentionFormatterIndex != -1) {
            // Process mentions for display
            editText = _processEditText(editText, message);
          }
          // Clear and populate segment controller
          _segmentComposerController!.clear();
          // Set the text in the first normal segment, hydrating any markdown
          // links into FormatType.link spans so the URL is preserved.
          final segments = _segmentComposerController!.segments;
          if (segments.isNotEmpty) {
            final segController = segments.first.controller;
            if (segController is RichTextEditingController) {
              segController.hydrateFromMarkdown(editText);
            } else {
              segController.text = editText;
            }
            _previousText = segController.text;
          }
        } else if (mentionFormatterIndex != -1) {
          CometChatMentionsFormatter mentionsFormatter =
              _formatters[mentionFormatterIndex] as CometChatMentionsFormatter;

          // Hydrate markdown links ([text](url)) into FormatType.link spans so
          // the URL portion doesn't disappear into hidden markers. Falls back
          // to a plain text assignment for non-rich controllers.
          final controller = _textEditingController;
          if (controller is RichTextEditingController) {
            controller.hydrateFromMarkdown(message.text);
          } else {
            controller?.text = message.text;
          }
          _previousText = _textEditingController!.text;

          mentionsFormatter.onMessageEdit(
            _textEditingController!,
            mentionedUsers: message.mentionedUsers,
          );

          _previousText = _textEditingController!.text;
        } else {
          String editText = message.text;
          editText = _processEditText(editText, message);
          final controller = _textEditingController;
          if (controller is RichTextEditingController) {
            controller.hydrateFromMarkdown(editText);
          } else {
            controller?.text = editText;
          }
          _previousText = _textEditingController?.text ?? editText;
        }
      } else if (message is MediaMessage) {
        // Text sent alongside attachments lives in the caption — load it into
        // the composer so it can be edited (mirrors the plain-text edit path,
        // hydrating any markdown into rich spans).
        final editText = message.caption ?? '';
        if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
          _segmentComposerController!.clear();
          final segments = _segmentComposerController!.segments;
          if (segments.isNotEmpty) {
            final segController = segments.first.controller;
            if (segController is RichTextEditingController) {
              segController.hydrateFromMarkdown(editText);
            } else {
              segController.text = editText;
            }
            _previousText = segController.text;
          }
        } else {
          final controller = _textEditingController;
          if (controller is RichTextEditingController) {
            controller.hydrateFromMarkdown(editText);
          } else {
            controller?.text = editText;
          }
          _previousText = _textEditingController?.text ?? editText;
        }
      }
    } else if (mode == PreviewMessageMode.reply) {
      _bloc.add(SetReplyMessage(message));
      _overlayPortalController.show();
    }
    setState(() {});
  }

  String _processEditText(String editText, TextMessage message) {
    if (widget.mentionAllLabelId != null) {
      String specificPattern = '<@all:${widget.mentionAllLabelId}>';
      String replacement = widget.mentionAllLabel ?? '@all';
      editText = editText.replaceAll(specificPattern, replacement);
    }
    editText = editText.replaceAll(
      '<@all:all>',
      widget.mentionAllLabel ?? '@all',
    );

    if (message.mentionedUsers.isNotEmpty) {
      editText = CometChatMentionsFormatter.getTextWithMentions(
        editText,
        message.mentionedUsers,
      );
    }
    return editText;
  }

  void _onMessagePreviewClose() {
    if (_overlayPortalController.isShowing) {
      _overlayPortalController.hide();
    }

    // Clear segment controller in segment mode
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      _segmentComposerController!.clear();
    }
    _textEditingController?.clear();

    for (var element in _formatters) {
      if (element is CometChatMentionsFormatter) {
        // Use the active controller for mentions cleanup
        final activeController =
            _getActiveTextController() ?? _textEditingController;
        if (activeController != null) {
          element.onMessageEdit(activeController, mentionedUsers: []);
        }
      }
    }

    _bloc.add(const ClearComposer());
    setState(() {});
  }

  void _initializeFooterView() {
    // Footer view is handled through BLoC state
  }

  // ============================================================================
  // Attachment and AI Options
  // ============================================================================

  /// Hides the suggestion list overlay and updates the notifier.
  void _hideSuggestionOverlay() {
    if (_overlayPortalController.isShowing) {
      _overlayPortalController.hide();
    }
    _suggestionOpenNotifier.value = false;
  }

  /// Shows the attachment options overlay popup above the attachment button.
  ///
  /// The keyboard stays open so the user can continue typing after
  /// dismissing the overlay without needing to tap the text field again.
  void _showAttachmentOverlay() {
    _attachmentOpenNotifier.value = true;
    // Show the overlay on the next frame so the attachment button's
    // `CompositedTransformTarget` has completed a layout pass and
    // the `LayerLink` has a valid leader offset. Otherwise the
    // follower (overlay) can read `(0,0)` as the leader position
    // and paint off-screen — especially when the button is nested
    // inside `Flexible`/`Row` layouts (double-line composer).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachmentOverlayController.show();
      // Request another frame to force the follower to re-resolve the
      // leader geometry now that the overlay is in the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    });
  }

  /// Hides the attachment options overlay popup.
  ///
  /// This method dismisses the overlay popup when the user selects an option
  /// or taps outside the overlay.
  void _hideAttachmentOverlay() {
    _attachmentOverlayController.hide();
    _attachmentOpenNotifier.value = false;
  }

  /// Dismisses the attachment overlay without restoring focus.
  ///
  /// This method is called when the user taps outside the overlay popup.
  /// It only hides the overlay - it does NOT request focus on the text input
  /// to avoid opening the keyboard unexpectedly.
  /// Requirements: 4.3, 4.4
  void _dismissAttachmentOverlayAndRestoreFocus() {
    _hideAttachmentOverlay();
    // Don't restore focus - user tapped outside, they don't want the keyboard
  }

  /// Toggles the attachment options overlay popup.
  ///
  /// If the overlay is currently showing, it will be hidden.
  /// If the overlay is currently hidden, it will be shown.
  /// This replaces the previous bottom sheet behavior with an overlay popup.
  void _toggleAttachmentOverlay() {
    if (_attachmentOverlayController.isShowing) {
      _hideAttachmentOverlay();
    } else {
      // Dismiss suggestion overlay when attachment opens
      if (_overlayPortalController.isShowing) {
        _hideSuggestionOverlay();
        CometChatUIEvents.hidePanel(
          _composerId,
          CustomUIPosition.composerPreview,
        );
        _suggestions.clear();
        _currentSearchKeyword = null;
        _searchKeywordChanged = true;
      }
      _showAttachmentOverlay();
    }
  }

  /// Handles selection of an attachment option from the overlay.
  ///
  /// This method is called when the user taps an item in the attachment
  /// options overlay. It dismisses the overlay and then either executes
  /// the item's custom callback or handles the default attachment selection.
  void _onAttachmentItemSelected(ActionItem item) {
    // Dismiss the overlay first
    _hideAttachmentOverlay();

    // Execute the item's custom callback if provided
    if (item.onItemClick != null) {
      item.onItemClick!(context, widget.user, widget.group);
    } else {
      // Handle default attachment selection
      _handleAttachmentSelection(item);
    }
  }

  Future<void> _handleAttachmentSelection(ActionItem item) async {
    _syncTrayReceiver();
    // Extension options are unchanged regardless of the tray.
    if (item.id == ExtensionType.extensionPoll) {
      _handleCreatePoll();
      return;
    } else if (item.id == ExtensionType.document) {
      _handleCreateCollaborativeDocument();
      return;
    } else if (item.id == ExtensionType.whiteboard) {
      _handleCreateCollaborativeWhiteboard();
      return;
    }

    final tray = _tray;

    // When the staging tray is active, picking ADDS to the tray (uploads) instead
    // of sending immediately. Image/video options allow multi-select. Picking is
    // gated by the per-message attachment limit (file.count.max).
    if (tray != null) {
      // The server-authoritative upload limits actually in force (from the app
      // settings the SDK cached); they cap the OS picker's selection count.
      ccLog(
        '📎 [limits] maxFileCount=${tray.maxFileCount} '
        'maxFileSize=${tray.maxFileSize}B '
        '(${(tray.maxFileSize / (1024 * 1024)).toStringAsFixed(1)} MB) '
        'staged=${tray.activeCount} remainingSlots=${tray.remainingSlots}',
      );
      if (!tray.canAddMore) {
        _showAttachmentLimitNote(tray.maxFileCount);
        return;
      }
      final isMedia =
          item.id == MessageTypeConstants.attachPhoto ||
          item.id == MessageTypeConstants.attachVideo ||
          item.id == MessageTypeConstants.image ||
          item.id == MessageTypeConstants.video;
      if (isMedia) {
        // Cap the OS picker to the remaining attachment slots (SDK max) so the
        // limit is enforced during selection where the platform honours it
        // (native); web has no such enforcement, so re-check below.
        final picked = await MediaPicker.pickMultipleMedia(
          limit: tray.remainingSlots,
        );
        if (picked.isEmpty) return;
        // A selection bigger than the remaining slots is rejected outright —
        // nothing is staged, not even the files that would fit (mainly a web
        // concern: the browser's file dialog has no selection-count cap).
        if (_rejectIfTooMany(tray, picked.length)) return;
        final accepted = _withinLimits(
          tray,
          picked.map(_toUploadFile).toList(),
        );
        if (accepted.isNotEmpty) await _stageWithFeedback(tray, accepted);
        return;
      }
      // Camera stays single-shot; audio and document pickers are multi-select.
      if (item.id == 'takePhoto') {
        final pf = await MediaPicker.takePhoto();
        if (pf == null) return;
        final accepted = _withinLimits(tray, [_toUploadFile(pf)]);
        if (accepted.isNotEmpty) await _stageWithFeedback(tray, accepted);
        return;
      }
      final pickedFiles = item.id == MessageTypeConstants.audio
          ? await MediaPicker.pickMultipleAudio(limit: tray.remainingSlots)
          : await MediaPicker.pickMultipleAnyFiles(limit: tray.remainingSlots);
      if (pickedFiles.isEmpty) return;
      if (_rejectIfTooMany(tray, pickedFiles.length)) return;
      final accepted = _withinLimits(
        tray,
        pickedFiles.map(_toUploadFile).toList(),
      );
      if (accepted.isNotEmpty) await _stageWithFeedback(tray, accepted);
      return;
    }

    // Legacy single-attachment send (no tray controller attached).
    PickedFile? pickedFile;
    String? type;
    if (item.id == MessageTypeConstants.attachPhoto) {
      pickedFile = await MediaPicker.pickImage();
      type = pickedFile?.fileType;
    } else if (item.id == MessageTypeConstants.attachVideo) {
      pickedFile = await MediaPicker.pickVideo();
      type = pickedFile?.fileType;
    } else if (item.id == 'takePhoto') {
      pickedFile = await MediaPicker.takePhoto();
      type = MessageTypeConstants.image;
    } else if (item.id == MessageTypeConstants.file) {
      pickedFile = await MediaPicker.pickAnyFile();
      type = MessageTypeConstants.file;
    } else if (item.id == MessageTypeConstants.audio) {
      pickedFile = await MediaPicker.pickAudio();
      type = MessageTypeConstants.audio;
    } else if (item.id == MessageTypeConstants.image) {
      pickedFile = await MediaPicker.pickImage();
      type = MessageTypeConstants.image;
    } else if (item.id == MessageTypeConstants.video) {
      pickedFile = await MediaPicker.pickVideo();
      type = MessageTypeConstants.video;
    }

    if (pickedFile != null && type != null) {
      Map<String, dynamic> metadata = {};
      metadata["localPath"] = pickedFile.path;
      _bloc.add(
        SendMediaMessage(
          path: pickedFile.path,
          messageType: type,
          metadata: metadata,
          fileBytes: pickedFile.bytes,
          fileName: pickedFile.name,
        ),
      );
    }
  }

  /// Tells the user the per-message attachment limit has been reached.
  void _showAttachmentLimitNote(int max) => _showComposerToast(
    Translations.of(context).attachmentCountLimit.replaceAll('{limit}', '$max'),
  );

  /// Stages a batch and surfaces a toast when the SDK can't start the upload
  /// (presign/network failure, or fewer returned fileIds than files). Without
  /// this, a throw from [AttachmentTrayController.stage] becomes a silent
  /// unhandled async error and the user sees nothing happen (R6).
  Future<void> _stageWithFeedback(
    AttachmentTrayController tray,
    List<UploadFile> accepted,
  ) async {
    try {
      await tray.stage(accepted);
    } on AttachmentStageException catch (e) {
      ccLog(
        '🟥 [stage] AttachmentStageException: ${e.message}'
        '${e.cause != null ? ' (cause: ${e.cause})' : ''}',
      );
      if (!mounted) return;
      _showComposerToast(Translations.of(context).uploadFailed);
    } catch (e, stack) {
      // Never swallow this: it drives the generic "something went wrong" toast,
      // and without the cause there's nothing to debug from a release build.
      ccLog('🟥 [stage] unexpected error: $e');
      ccLog('$stack');
      if (!mounted) return;
      _showComposerToast(Translations.of(context).somethingWentWrongError);
    }
  }

  void _showComposerToast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final style = widget.attachmentErrorAlertStyle;
    final colors = _colorPalette;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            style?.icon ??
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: style?.iconColor ?? colors.error,
                ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                // neutral50 (not white): it inverts with the neutral900 fill —
                // white on near-black in light, near-black on white in dark.
                // Hardcoded white rendered white-on-white in dark theme.
                style: TextStyle(
                  color: colors.neutral50,
                ).merge(style?.textStyle),
              ),
            ),
          ],
        ),
        backgroundColor: style?.backgroundColor ?? colors.neutral900,
        behavior: style?.behavior ?? SnackBarBehavior.floating,
        shape:
            style?.shape ??
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: style?.margin,
        duration: style?.duration ?? const Duration(seconds: 2),
      ),
    );
  }

  static String _formatBytes(int b) {
    if (b >= 1 << 30) {
      final gb = b / (1 << 30);
      return '${gb % 1 == 0 ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1)} GB';
    }
    if (b >= 1 << 20) return '${(b / (1 << 20)).round()} MB';
    if (b >= 1 << 10) return '${(b / (1 << 10)).round()} KB';
    return '$b B';
  }

  /// Rejects the WHOLE batch (stages nothing) with a toast when [count]
  /// exceeds the tray's remaining slots — the picker/drag-drop entry points
  /// call this before staging anything, so a selection that's too big never
  /// partially lands (no tiles at all, not even the ones that would fit).
  /// Returns true when the batch was rejected.
  bool _rejectIfTooMany(AttachmentTrayController tray, int count) {
    if (count <= tray.remainingSlots) return false;
    _showAttachmentLimitNote(tray.maxFileCount);
    return true;
  }

  /// Filters [files] against the tray's per-file SIZE limit — showing a toast
  /// and staging an error tile for whatever is oversized — and returns only
  /// the files that fit. Callers must gate the batch's overall COUNT via
  /// [_rejectIfTooMany] first; this no longer rejects on count.
  List<UploadFile> _withinLimits(
    AttachmentTrayController tray,
    List<UploadFile> files,
  ) {
    final maxSize = tray.maxFileSize;
    final accepted = <UploadFile>[];

    for (final f in files) {
      // An empty (0-byte) file — e.g. a corrupt/blank image picked on web — is
      // rejected here with a short "Invalid File" reason, before it reaches the
      // SDK (which would otherwise surface its verbose ERR_INVALID_FILE_OBJECT
      // message on the tile).
      if (f.size <= 0) {
        tray.addLimitRejected(f, Translations.of(context).invalidFile);
        continue;
      }
      // An oversized file stays in the tray as an error tile (rejected) so the
      // user sees exactly which file failed and why. Tapping the tile
      // surfaces the reason via the attachment error snackbar.
      if (maxSize > 0 && f.size > maxSize) {
        tray.addLimitRejected(
          f,
          Translations.of(context).attachmentFileSizeLimit.replaceAll(
            '{limit}',
            _formatBytes(maxSize),
          ),
        );
        continue;
      }
      accepted.add(f);
    }

    return accepted;
  }

  /// Converts a picked file into the SDK's [UploadFile] (path-based on
  /// mobile/desktop, bytes-based on web). mimeType is inferred from the name.
  UploadFile _toUploadFile(PickedFile pf) {
    if (pf.bytes != null) {
      return UploadFile.fromBytes(pf.bytes!, name: pf.name, size: pf.size);
    }
    // Some platform pickers (e.g. the iOS document picker) don't report a size;
    // recover it from disk so the SDK doesn't reject the file as size-zero.
    var size = pf.size ?? 0;
    if (size <= 0) size = platform.fileSizeOf(pf.path);
    return UploadFile.fromPath(pf.path, size: size, name: pf.name);
  }

  /// Handles media content inserted from the keyboard (e.g. GIF, sticker).
  /// Writes the content data to a temp file and sends it as a media message.
  Future<void> _handleKeyboardContentInserted(
    KeyboardInsertedContent content,
  ) async {
    if (kIsWeb) return; // Not supported on web
    final data = content.data;
    if (data == null || data.isEmpty) {
      // If there's a URI but no data, try sending the URI directly
      if (content.uri.isNotEmpty) {
        _bloc.add(
          SendMediaMessage(
            path: content.uri,
            messageType: MessageTypeConstants.image,
            metadata: {'localPath': content.uri},
          ),
        );
      }
      return;
    }

    try {
      // Determine file extension from mime type
      final mimeType = content.mimeType;
      String extension = 'gif';
      if (mimeType.contains('png')) {
        extension = 'png';
      } else if (mimeType.contains('jpeg') || mimeType.contains('jpg')) {
        extension = 'jpg';
      } else if (mimeType.contains('webp')) {
        extension = 'webp';
      }

      final fileName =
          'keyboard_media_${DateTime.now().millisecondsSinceEpoch}.$extension';
      // Route through the shared paste path so a keyboard insertion behaves
      // exactly like any other paste: staged as a tile (previewable, captionable,
      // retryable) when the tray is active, sent immediately only when it isn't.
      // This used to send straight away, which is why pasting an image on
      // Android — where Gboard delivers it via content insertion rather than the
      // context menu — skipped the tray entirely, while iOS (no such API, so it
      // goes through the paste menu) staged correctly.
      await _stagePastedBytes(data, mimeType, fileName);
    } catch (_) {
      // No-op: image send failures are surfaced via message delivery status.
    }
  }

  /// Reads an image off the system clipboard (e.g. one copied from the Files
  /// app) and stages it in the attachment tray — the same path a picked image
  /// takes, so it shows a tile with progress/retry and can be captioned before
  /// sending. Falls back to an immediate send when the staging tray isn't
  /// active. Returns true when an image was found and handled, so the caller
  /// suppresses the default text paste; false means "no image" → normal paste.
  Future<bool> _pasteClipboardFile() async {
    // Native and web both read any pasted file kind (image/video/audio/
    // document) — native via the platform channel, web via the DOM listener.
    final file = await platform.readClipboardImage();
    if (file == null) return false;
    await _stagePastedBytes(file.bytes, file.mimeType, file.fileName);
    return true;
  }

  /// Stages pasted file bytes (image / video / audio / document) as an
  /// attachment tile (or sends immediately when the staging tray isn't active).
  /// Shared by the mobile pull path ([_pasteClipboardFile]) and the web
  /// `paste`-event listener. [fileName] is the browser-provided name when
  /// present (documents/media carry one); otherwise one is synthesized.
  Future<void> _stagePastedBytes(
    List<int> bytes,
    String mimeType,
    String? fileName,
  ) async {
    if (bytes.isEmpty) return;
    _syncTrayReceiver();
    final name = (fileName != null && fileName.isNotEmpty)
        ? fileName
        : _synthPastedName(mimeType);

    final tray = _tray;
    if (tray != null) {
      // Native: materialize the bytes to a temp file so the tile has a real
      // path to preview from. The tray builds its thumbnail from the path, else
      // from objectUrlFromBytes — which is web-only (a stub returning null off
      // web), so a bytes-only pasted image staged with NO preview on iOS and
      // Android. On web writeBytesToTempFile is a no-op and the blob: URL
      // already covers it, so the bytes are kept there.
      final tempPath = kIsWeb
          ? null
          : await platform.writeBytesToTempFile(bytes, name);
      final pasted = tempPath != null
          ? UploadFile.fromPath(
              tempPath,
              name: name,
              size: bytes.length,
              mimeType: mimeType,
            )
          : UploadFile.fromBytes(
              bytes,
              name: name,
              size: bytes.length,
              mimeType: mimeType,
            );
      // Over-count / over-size files are dropped with a toast, not staged.
      final accepted = _withinLimits(tray, [pasted]);
      if (accepted.isNotEmpty) await _stageWithFeedback(tray, accepted);
      return;
    }

    // No staging tray → write to a temp file and send immediately (mirrors the
    // keyboard-insertion path in _handleKeyboardContentInserted). On web
    // writeBytesToTempFile is a no-op, so staging is the only path there.
    final path = await platform.writeBytesToTempFile(bytes, name);
    if (path == null) return;
    _bloc.add(
      SendMediaMessage(
        path: path,
        messageType: _messageTypeForMime(mimeType),
        metadata: {'localPath': path},
      ),
    );
  }

  /// Synthesizes a filename for a pasted file that arrived without one (e.g. a
  /// raw screenshot). Best-effort extension from the MIME subtype.
  String _synthPastedName(String mimeType) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final mime = mimeType.toLowerCase();
    final slash = mime.indexOf('/');
    final subtype = slash >= 0 ? mime.substring(slash + 1) : '';
    final ext = mime.contains('jpeg')
        ? 'jpg'
        : (subtype.isNotEmpty && !subtype.contains('+') ? subtype : 'bin');
    final base = mime.startsWith('image/')
        ? 'pasted_image'
        : mime.startsWith('video/')
        ? 'pasted_video'
        : mime.startsWith('audio/')
        ? 'pasted_audio'
        : 'pasted_file';
    return '${base}_$ts.$ext';
  }

  /// Maps a MIME type to a CometChat message type for the tray-less send path.
  String _messageTypeForMime(String mimeType) {
    final m = mimeType.toLowerCase();
    if (m.startsWith('image/')) return MessageTypeConstants.image;
    if (m.startsWith('video/')) return MessageTypeConstants.video;
    if (m.startsWith('audio/')) return MessageTypeConstants.audio;
    return MessageTypeConstants.file;
  }

  /// Stages files dragged from the OS onto the chat (web only). A drop bigger
  /// than the remaining slots is rejected outright (a toast, nothing staged);
  /// otherwise oversized files are dropped individually as before. Each
  /// accepted file keeps its real name/MIME, so the tray renders it by kind
  /// (image / video / audio / file) just like a picked one.
  Future<void> _stageDroppedFiles(List<web_drop.DroppedFile> files) async {
    if (files.isEmpty) return;
    _syncTrayReceiver();
    final tray = _tray;
    if (tray == null) return;
    if (_rejectIfTooMany(tray, files.length)) return;
    final uploads = <UploadFile>[
      for (final f in files)
        UploadFile.fromBytes(f.bytes, name: f.name, size: f.bytes.length),
    ];
    final accepted = _withinLimits(tray, uploads);
    if (accepted.isNotEmpty) await _stageWithFeedback(tray, accepted);
  }

  /// True while any of the composer's text fields (plain input or a rich-text
  /// segment) holds focus — the gate for the web paste listener so it doesn't
  /// capture pastes intended for other fields.
  bool _isComposerFocused() {
    if (!mounted) return false;
    if (_focusNode.hasFocus) return true;
    final segments = _segmentComposerController?.segments;
    if (segments != null) {
      for (final segment in segments) {
        if (segment.focusNode.hasFocus) return true;
      }
    }
    return false;
  }

  /// Opens the create poll bottom sheet
  void _handleCreatePoll() {
    final replyMessage = _bloc.state.replyMessage;
    // Clear reply state immediately so the preview dismisses
    if (replyMessage != null) {
      _bloc.add(const ClearReplyMessage());
    }
    showCometChatCreatePoll(
      context: context,
      colorPalette: _colorPalette,
      spacing: _spacing,
      uid: widget.user?.uid,
      guid: widget.group?.guid,
      userObject: widget.user,
      groupObject: widget.group,
      quotedMessage: replyMessage,
    );
  }

  /// Creates a collaborative document via CometChat extension
  void _handleCreateCollaborativeDocument() {
    final receiverId = widget.user?.uid ?? widget.group?.guid ?? '';
    final receiverType = widget.user != null
        ? ReceiverTypeConstants.user
        : ReceiverTypeConstants.group;

    final replyMessage = _bloc.state.replyMessage;
    // Clear reply state immediately so the preview dismisses
    if (replyMessage != null) {
      _bloc.add(const ClearReplyMessage());
    }

    final Map<String, dynamic> body = {
      'receiver': receiverId,
      'receiverType': receiverType,
    };
    if (replyMessage != null && replyMessage.id > 0) {
      body['quotedMessageId'] = replyMessage.id;
    }

    CometChat.callExtension(
      ExtensionConstants.document,
      'POST',
      ExtensionUrls.document,
      body,
      onSuccess: (Map<String, dynamic> map) {},
      onError: (CometChatException e) {
        if (widget.onError != null) {
          widget.onError!(e);
        }
      },
    );
  }

  /// Creates a collaborative whiteboard via CometChat extension
  void _handleCreateCollaborativeWhiteboard() {
    final receiverId = widget.user?.uid ?? widget.group?.guid ?? '';
    final receiverType = widget.user != null
        ? ReceiverTypeConstants.user
        : ReceiverTypeConstants.group;

    final replyMessage = _bloc.state.replyMessage;
    // Clear reply state immediately so the preview dismisses
    if (replyMessage != null) {
      _bloc.add(const ClearReplyMessage());
    }

    final Map<String, dynamic> body = {
      'receiver': receiverId,
      'receiverType': receiverType,
    };
    if (replyMessage != null && replyMessage.id > 0) {
      body['quotedMessageId'] = replyMessage.id;
    }

    CometChat.callExtension(
      ExtensionConstants.whiteboard,
      'POST',
      ExtensionUrls.whiteboard,
      body,
      onSuccess: (Map<String, dynamic> map) {},
      onError: (CometChatException e) {
        if (widget.onError != null) {
          widget.onError!(e);
        }
      },
    );
  }

  void _showVoiceRecordingSheet() {
    FocusManager.instance.primaryFocus?.unfocus();

    if (widget.useInlineAudioRecorder) {
      // Use inline audio recorder in the composer
      _bloc.add(const StartAudioRecording());
    } else {
      // Use bottom sheet recorder (legacy mode)
      _showVoiceRecordingBottomSheet();
    }
  }

  /// Shows the bottom sheet recorder (legacy mode)
  void _showVoiceRecordingBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return CometChatMediaRecorder(
          startButtonIcon: widget.recorderStartButtonIcon,
          pauseButtonIcon: widget.recorderPauseButtonIcon,
          stopButtonIcon: widget.recorderStopButtonIcon,
          deleteButtonIcon: widget.recorderDeleteButtonIcon,
          sendButtonIcon: widget.recorderSendButtonIcon,
          style: _style.mediaRecorderStyle,
          onSubmit: _sendMediaRecording,
        );
      },
    );
  }

  /// Ensures a normal segment has focus in segment mode.
  /// If no segment is focused, focuses the first normal segment.
  /// Returns the focused segment's controller and focus node as a list [controller, focusNode],
  /// or falls back to the main _textEditingController / _focusNode.
  List<dynamic> _ensureSegmentFocus() {
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      var focused = _segmentComposerController!.focusedSegment;
      if (focused == null || focused.type != SegmentType.normal) {
        // No segment focused — find the first normal segment and focus it
        ComposerSegment? firstNormal;
        for (final s in _segmentComposerController!.segments) {
          if (s.type == SegmentType.normal) {
            firstNormal = s;
            break;
          }
        }
        if (firstNormal != null) {
          firstNormal.focusNode.requestFocus();
          return [firstNormal.controller, firstNormal.focusNode];
        }
      } else {
        return [focused.controller, focused.focusNode];
      }
    }
    // Non-segment mode or no normal segment found
    if (_textEditingController != null) {
      _focusNode.requestFocus();
    }
    return [_textEditingController!, _focusNode];
  }

  void _showLinkEditDialog() {
    // Ensure a segment has focus and get the active controller
    final result = _ensureSegmentFocus();
    final activeController = result[0] as TextEditingController;
    final savedFocusNode = result[1] as FocusNode?;

    // Capture selection and text BEFORE dialog opens — dialog steals focus and resets selection.
    // Guard against invalid selection (baseOffset == -1 when field was never focused).
    final sel = activeController.selection;
    final savedText = activeController.text;
    final isSelectionValid =
        sel.isValid && sel.start >= 0 && sel.end <= savedText.length;
    final savedSelection = isSelectionValid
        ? sel
        : TextSelection.collapsed(offset: savedText.length);
    final selectedText = savedSelection.isCollapsed
        ? ''
        : savedText.substring(savedSelection.start, savedSelection.end);

    // Hold references so the closure uses the correct objects even after
    // focus shifts while the dialog is open.
    final controllerToUpdate = activeController;
    final focusToRestore = savedFocusNode;

    showDialog(
      context: context,
      builder: (dialogContext) => LinkEditDialog(
        initialDisplayText: selectedText,
        style: CometChatLinkPreviewStyle.of(context),
        onSubmit: (displayText, url) {
          Navigator.of(dialogContext).pop();
          _applyLinkFormat(
            displayText,
            url,
            savedText,
            savedSelection,
            controllerToUpdate,
            focusToRestore,
          );
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _applyLinkFormat(
    String displayText,
    String url,
    String savedText,
    TextSelection savedSelection,
    TextEditingController controller,
    FocusNode? focusToRestore,
  ) {
    // Restore focus first so the text field is ready to accept the value change.
    // Use a post-frame callback to ensure the dialog is fully dismissed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Re-focus the text field
      focusToRestore?.requestFocus();

      if (controller is RichTextEditingController) {
        // WYSIWYG mode: use span system so formatting survives editing.
        // Restore selection first so applyLinkFormat knows where to insert.
        controller.selection = savedSelection;
        controller.applyLinkFormat(displayText, url);
      } else {
        // Legacy mode: insert raw markdown
        final linkMarkdown = '[$displayText]($url)';
        final newText =
            savedText.substring(0, savedSelection.start) +
            linkMarkdown +
            savedText.substring(savedSelection.end);
        final newCursorPos = savedSelection.start + linkMarkdown.length;

        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursorPos),
        );
      }

      widget.onRichTextFormatApplied?.call(FormatType.link);
    });
  }

  /// Called when a link span is tapped in the text field.
  /// Called by the input's `onTap` callback whenever the user taps the
  /// TextField. Schedules a post-frame link-at-cursor check on the active
  /// [RichTextEditingController]. This complements the controller's internal
  /// selection-change listener, which does not reliably fire on iOS when the
  /// user taps an unfocused field (iOS prioritises focus acquisition over
  /// cursor movement on the first tap).
  void _handleComposerTap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = _getActiveTextController();
      if (ctrl is RichTextEditingController) {
        ctrl.checkLinkAtCursor();
      }
    });
  }

  /// Shows a popup with Edit and Remove options.
  void _onLinkTapped(LinkTapDetails details) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final spacing = CometChatThemeHelper.getSpacing(context);
    final typography = CometChatThemeHelper.getTypography(context);

    // Capture the active controller NOW (before dialog steals focus).
    // In segment mode, the link lives in the focused segment's controller.
    final activeCtrl = _getActiveTextController();
    final richCtrl = (activeCtrl is RichTextEditingController)
        ? activeCtrl
        : (_textEditingController is RichTextEditingController
              ? _textEditingController as RichTextEditingController
              : null);

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: colorPalette.borderLight ?? Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.all(
            Radius.circular(spacing.radius4 ?? 16),
          ),
        ),
        backgroundColor: colorPalette.background1,
        iconPadding: EdgeInsets.only(
          left: spacing.padding6 ?? 24,
          right: spacing.padding6 ?? 24,
          top: spacing.padding6 ?? 24,
          bottom: spacing.padding3 ?? 12,
        ),
        icon: Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: colorPalette.background2,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.link, color: colorPalette.primary, size: 32),
        ),
        titlePadding: EdgeInsets.only(
          left: spacing.padding6 ?? 24,
          right: spacing.padding6 ?? 24,
          bottom: spacing.padding1 ?? 4,
        ),
        title: Text(
          details.displayText,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        titleTextStyle: TextStyle(
          fontSize: typography.heading3?.medium?.fontSize,
          fontWeight: typography.heading3?.medium?.fontWeight,
          fontFamily: typography.heading3?.medium?.fontFamily,
          color: colorPalette.textPrimary,
        ),
        contentPadding: EdgeInsets.only(
          left: spacing.padding6 ?? 24,
          right: spacing.padding6 ?? 24,
          bottom: spacing.padding3 ?? 12,
        ),
        content: Text(
          details.url,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        contentTextStyle: TextStyle(
          fontSize: typography.body?.regular?.fontSize,
          fontWeight: typography.body?.regular?.fontWeight,
          fontFamily: typography.body?.regular?.fontFamily,
          color: colorPalette.textSecondary,
        ),
        actionsPadding: EdgeInsets.only(
          left: spacing.padding6 ?? 24,
          right: spacing.padding6 ?? 24,
          bottom: spacing.padding3 ?? 12,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.margin3 ?? 12),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: spacing.padding2 ?? 8),
                    child: Semantics(
                      button: true,
                      label: Translations.of(context).edit,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _showLinkEditDialogForExisting(details, richCtrl);
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                          side: WidgetStateProperty.all(
                            BorderSide(
                              color:
                                  colorPalette.borderDark ?? Colors.transparent,
                              width: 1,
                            ),
                          ),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(spacing.radius2 ?? 8),
                              ),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: colorPalette.textPrimary,
                            ),
                            SizedBox(width: spacing.padding1 ?? 4),
                            Text(
                              Translations.of(context).edit,
                              style: TextStyle(
                                fontSize: typography.button?.medium?.fontSize,
                                fontWeight:
                                    typography.button?.medium?.fontWeight,
                                fontFamily:
                                    typography.button?.medium?.fontFamily,
                                color: colorPalette.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: Translations.of(context).delete,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        richCtrl?.removeLinkFormat(details.start, details.end);
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          colorPalette.error,
                        ),
                        side: WidgetStateProperty.all(
                          BorderSide(
                            color: colorPalette.error ?? Colors.transparent,
                            width: 0,
                          ),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(spacing.radius2 ?? 8),
                            ),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.link_off,
                            size: 18,
                            color: colorPalette.white,
                          ),
                          SizedBox(width: spacing.padding1 ?? 4),
                          Text(
                            Translations.of(context).delete,
                            style: TextStyle(
                              fontSize: typography.button?.medium?.fontSize,
                              fontWeight: typography.button?.medium?.fontWeight,
                              fontFamily: typography.button?.medium?.fontFamily,
                              color: colorPalette.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the link edit dialog pre-filled with the existing link's text and URL.
  void _showLinkEditDialogForExisting(
    LinkTapDetails details,
    RichTextEditingController? richCtrl,
  ) {
    final controller = richCtrl;
    if (controller == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => LinkEditDialog(
        initialDisplayText: details.displayText,
        initialUrl: details.url,
        style: CometChatLinkPreviewStyle.of(context),
        onSubmit: (newDisplayText, newUrl) {
          Navigator.of(dialogContext).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            controller.editLinkFormat(
              details.start,
              details.end,
              newDisplayText,
              newUrl,
            );
          });
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  /// Called by [RichTextEditingController.onFormatterTextChanged] after
  /// [editLinkFormat] or [removeLinkFormat] change text programmatically.
  /// Runs each formatter's [onChange] so tracked positions (e.g. mentions)
  /// stay in sync with the new text.
  void _onFormatterTextChanged(String previousText) {
    final activeController = _getActiveTextController();
    if (activeController == null) return;

    for (var formatter in _formatters) {
      try {
        formatter.onChange(activeController, previousText);
      } catch (err) {
        if (kDebugMode) {}
      }
    }
    // Keep previousText in sync so the next _onTyping diff is correct.
    _updatePreviousText(activeController.text);
  }

  Widget? _buildRichTextToolbar() {
    if (!_showRichTextToolbar || _textEditingController == null) {
      return null;
    }

    // Use custom view if provided
    if (widget.richTextToolbarView != null) {
      return widget.richTextToolbarView!(context, _textEditingController!);
    }

    // Get active formats - use centralized helper that handles segment mode
    final activeFormats = _getActiveFormats();
    // Get hidden formats from configuration
    final hiddenFormats = _getHiddenFormats();

    return CometChatRichTextToolbar(
      onFormatTap: _applyToolbarFormat,
      activeFormats: activeFormats,
      hiddenFormats: hiddenFormats,
      style: _style.richTextToolbarStyle,
    );
  }

  // ============================================================================
  // UI Building Methods - Using Extracted Widgets
  // ============================================================================

  Widget _buildSuggestionList() {
    // The suggestion list is rendered inline as the `composerPreview` panel
    // inside the bottom composer Column (mainAxisSize.min), so it is laid out
    // with an unbounded height. It therefore must NOT contain an `Expanded`
    // child — doing so throws "RenderFlex children have non-zero flex but
    // incoming height constraints are unbounded" in debug builds and silently
    // collapses in release. Return the list directly so it shrink-wraps.
    return MessageComposerSuggestionList(
      suggestions: _suggestions,
      onItemTap: (item) {
        if (item.onTap != null) {
          item.onTap!();
        }
        // Selecting a suggestion inserts the mention programmatically, which
        // does NOT flow through the field's onChanged/_onTyping — so the
        // formatter's previousText baseline is never synced here. Without this,
        // the next keystroke diffs against a stale (shorter) baseline and the
        // mentions formatter misreads the new "@" as a paste, suppressing the
        // suggestion list after the first successful mention. (ENG-36741)
        final activeController = _getActiveTextController();
        if (activeController != null) {
          _updatePreviousText(activeController.text);
        }
        _hideSuggestionOverlay();
        _suggestions.clear();
        _currentSearchKeyword = null;
        _searchKeywordChanged = true;
      },
      onScrollToBottom: () {
        final activeController = _getActiveTextController();
        if (activeController == null) return;
        for (var element in _formatters) {
          if (_currentSearchKeyword != null &&
              _currentSearchKeyword!.isNotEmpty &&
              element.trackingCharacter == _currentSearchKeyword![0]) {
            element.onScrollToBottom(activeController);
          }
        }
      },
      scrollController: _scrollController,
      hasMore: _hasMore,
      style: _suggestionListStyle,
      colorPalette: _colorPalette,
      spacing: _spacing,
      typography: _typography,
    );
  }

  Widget _buildSendButton(MessageComposerState state) {
    if (widget.hideSendButton == true) {
      return const SizedBox();
    }

    // AI streaming: show stop button (visual only, no tap action)
    if (state.isActiveStreaming) {
      return Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: _colorPalette.textPrimary ?? Colors.black,
          borderRadius:
              _style.sendButtonBorderRadius ??
              BorderRadius.circular(_spacing.radiusMax ?? 20),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.stop_rounded,
          color: _colorPalette.background1 ?? Colors.white,
          size: 20,
        ),
      );
    }

    if (widget.sendButtonView != null) {
      return GestureDetector(
        onTap: _onSendButtonClick,
        child: widget.sendButtonView,
      );
    }

    // Staged attachments (uploaded, ready) enable the send button on their own
    // — no typed text required. The tray is a Listenable, so wrap the button in
    // it for reactivity as uploads complete / tiles are removed.
    final tray = _tray;

    Widget buildCore() {
      final trayCanSend = tray?.canSend ?? false;
      // Once ANY attachment is staged, the send gate becomes the tray's own
      // readiness (trayCanSend = ≥1 done, none uploading, none errored),
      // regardless of typed text: a combined text+media message must wait for
      // its uploads to finish and must not go out while any tile is still
      // uploading or in an error state (ENG-36985). With no staged attachments,
      // the gate falls back to "text must be non-empty".
      final trayHasTiles = tray != null && tray.tiles.isNotEmpty;

      // When using segment-based code blocks, we need to listen to segment
      // changes instead of just the text controller
      if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
        return ListenableBuilder(
          listenable: _segmentComposerController!,
          builder: (context, child) {
            final hasContent = _segmentComposerController!.hasContent;
            final shouldDisable = trayHasTiles ? !trayCanSend : !hasContent;

            return MessageComposerSendButton(
              onPressed: _onSendButtonClick,
              isDisabled: shouldDisable,
              hideSendButton: widget.hideSendButton ?? false,
              customSendButtonView: widget.sendButtonView,
              sendButtonIcon: widget.sendButtonIcon,
              sendButtonIconColor: _style.sendButtonIconColor,
              sendButtonIconBackgroundColor:
                  _style.sendButtonIconBackgroundColor,
              sendButtonBorderRadius: _style.sendButtonBorderRadius,
              colorPalette: _colorPalette,
              spacing: _spacing,
            );
          },
        );
      }

      // Wrap in ValueListenableBuilder to rebuild when text changes
      // This ensures the send button color updates immediately when typing in edit mode
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: _textEditingController!,
        builder: (context, textValue, child) {
          final isTextControllerEmpty = textValue.text.trim().isEmpty;

          // Edit target's current text: a TextMessage's body, or a
          // MediaMessage's caption (text sent alongside attachments).
          final editMsg = state.editMessage;
          final String? editOldText = editMsg is TextMessage
              ? editMsg.text
              : editMsg is MediaMessage
              ? (editMsg.caption ?? '')
              : null;

          final isSameAsOldMessage =
              state.isEditMode &&
              editOldText != null &&
              textValue.text == editOldText;

          final isEditModeWithoutChanges =
              state.isEditMode &&
              editOldText != null &&
              !_hasMeaningfulChange(editOldText, textValue.text);

          final shouldDisable =
              (trayHasTiles ? !trayCanSend : isTextControllerEmpty) ||
              isSameAsOldMessage ||
              isEditModeWithoutChanges;

          return MessageComposerSendButton(
            onPressed: _onSendButtonClick,
            isDisabled: shouldDisable,
            hideSendButton: widget.hideSendButton ?? false,
            customSendButtonView: widget.sendButtonView,
            sendButtonIcon: widget.sendButtonIcon,
            sendButtonIconColor: _style.sendButtonIconColor,
            sendButtonIconBackgroundColor: _style.sendButtonIconBackgroundColor,
            sendButtonBorderRadius: _style.sendButtonBorderRadius,
            colorPalette: _colorPalette,
            spacing: _spacing,
          );
        },
      );
    }

    if (tray == null) return buildCore();
    return ListenableBuilder(
      listenable: tray,
      builder: (context, _) => buildCore(),
    );
  }

  Widget _buildSecondaryButtonView(MessageComposerState state) {
    if (widget.secondaryButtonView != null) {
      return widget.secondaryButtonView!(
        context,
        widget.user,
        widget.group,
        _composerId,
      );
    }

    final secondaryButtons = MessageComposerSecondaryButtons(
      onAttachmentTap: _toggleAttachmentOverlay,
      hideAttachmentButton: widget.hideAttachmentButton ?? false,
      attachmentIcon: widget.attachmentIcon,
      attachmentIconURL: widget.attachmentIconURL,
      secondaryButtonIconColor: _style.secondaryButtonIconColor,
      secondaryButtonIconBackgroundColor:
          _style.secondaryButtonIconBackgroundColor,
      secondaryButtonBorderRadius: _style.secondaryButtonBorderRadius,
      colorPalette: _colorPalette,
      spacing: _spacing,
      attachmentButtonLink: _attachmentButtonLink,
      attachmentOpenNotifier: _attachmentOpenNotifier,
      // Adding attachments while editing an existing message's text/caption
      // isn't meaningful — the edit pipeline only changes text.
      disabled: state.isEditMode,
    );

    // Wrap with OverlayPortal for attachment options overlay
    return OverlayPortal(
      controller: _attachmentOverlayController,
      overlayChildBuilder: (context) {
        return Stack(
          children: [
            // Full-screen barrier to detect taps outside the overlay
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismissAttachmentOverlayAndRestoreFocus,
                child: const SizedBox.expand(),
              ),
            ),
            // Positioned attachment options overlay - appears ABOVE the + button
            CompositedTransformFollower(
              link: _attachmentButtonLink,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.bottomLeft,
              offset: Offset(0, -(_spacing.padding2 ?? 5)),
              child: AttachmentOptionsOverlay(
                actionItems: _actionItems,
                onItemSelected: _onAttachmentItemSelected,
                onDismiss: _hideAttachmentOverlay,
                style: _style.attachmentOptionSheetStyle,
                colorPalette: _colorPalette,
                spacing: _spacing,
                typography: _typography,
              ),
            ),
          ],
        );
      },
      child: secondaryButtons,
    );
  }

  /// Resolves the effective auxiliary buttons alignment used internally.
  ///
  /// Rules:
  /// 1. If the caller passed [CometChatMessageComposer.auxiliaryButtonsAlignment],
  ///    that wins.
  /// 2. Otherwise, in [CometChatComposerLayout.doubleLine] the auxiliary
  ///    cluster (mic + stickers) defaults to the LEFT side of the toolbar row
  ///    so the visual order is `[+][mic][stickers] ... [send]`, matching v5
  ///    and the Figma spec.
  /// 3. In [CometChatComposerLayout.singleLine] it defaults to the RIGHT side,
  ///    next to the send button — the historical v6 behaviour.
  AuxiliaryButtonsAlignment get _effectiveAuxiliaryAlignment {
    if (widget.auxiliaryButtonsAlignment != null) {
      return widget.auxiliaryButtonsAlignment!;
    }
    return widget.layout == CometChatComposerLayout.doubleLine
        ? AuxiliaryButtonsAlignment.left
        : AuxiliaryButtonsAlignment.right;
  }

  Widget _buildAuxiliaryButtonView(MessageComposerState state) {
    if (widget.auxiliaryButtonView != null) {
      return widget.auxiliaryButtonView!(
        context,
        widget.user,
        widget.group,
        _composerId,
      );
    }

    // The mic hides when there's typed content OR any staged attachment, so it
    // rebuilds reactively as the tray changes — wrap the cluster in a listener
    // on the tray (the auxiliary row isn't otherwise rebuilt on tray events;
    // only the send button and the tray widget are).
    final tray = _tray;

    Widget buildAux() {
      // Hide voice recording button when text is typed (like in Figma design)
      // Check both regular text controller and segment controller.
      final hasText =
          (_textEditingController != null &&
              _textEditingController!.text.isNotEmpty) ||
          (_segmentComposerController != null &&
              _segmentComposerController!.hasContent);

      // Also hide it once any attachment is staged — recording a voice note
      // doesn't apply while composing a multi-attachment message (ENG-37148).
      final hasStagedAttachments = tray != null && tray.tiles.isNotEmpty;

      // In double-line mode with left-aligned auxiliary, the visual row is
      // `[+][mic][stickers] ... [send]`. Inside the auxiliary cluster we
      // therefore want mic BEFORE stickers. In all other cases keep the
      // existing `[stickers][mic]` order so single-line layout is unchanged.
      final voiceFirst =
          widget.layout == CometChatComposerLayout.doubleLine &&
          _effectiveAuxiliaryAlignment == AuxiliaryButtonsAlignment.left;

      final aux = MessageComposerAuxiliaryButtons(
        onVoiceRecordingTap: _showVoiceRecordingSheet,
        hideVoiceRecordingButton:
            (widget.hideVoiceRecordingButton ?? false) ||
            hasText ||
            hasStagedAttachments,
        auxiliaryOptions: _auxiliaryOptions,
        voiceRecordingIcon: widget.voiceRecordingIcon,
        auxiliaryButtonIconColor: _style.auxiliaryButtonIconColor,
        auxiliaryButtonIconBackgroundColor:
            _style.auxiliaryButtonIconBackgroundColor,
        auxiliaryButtonBorderRadius: _style.auxiliaryButtonBorderRadius,
        colorPalette: _colorPalette,
        spacing: _spacing,
        voiceFirst: voiceFirst,
      );

      // When in toggleable rich-text mode (double-line only), append the `Aa`
      // format-toggle button after the auxiliary cluster so the visual order
      // is `[mic][stickers][Aa]`. The toggle swaps the entire action row for
      // `[✕] + <toolbar>` — see [_buildToolbarSwapRow].
      if (_shouldShowFormatToggle) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            aux,
            SizedBox(width: _spacing.margin4 ?? 4),
            _buildFormatToggleButton(),
          ],
        );
      }

      return aux;
    }

    if (tray == null) return buildAux();
    return ListenableBuilder(
      listenable: tray,
      builder: (context, _) => buildAux(),
    );
  }

  /// Builds the `Aa` format-toggle button used in the toggleable
  /// (double-line) toolbar flow. Matches the mic icon colour
  /// (`iconSecondary`) in both tapped and untapped states so it blends with
  /// the rest of the auxiliary cluster — no highlight on active.
  Widget _buildFormatToggleButton() {
    final iconColor = _colorPalette.iconSecondary ?? Colors.grey;
    return Semantics(
      label: Translations.of(context).richTextFormattingToolbar,
      button: true,
      toggled: _isToolbarToggleOpen,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_spacing.radius2 ?? 8),
          onTap: _toggleRichTextSwap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(Icons.text_format, size: 22, color: iconColor),
          ),
        ),
      ),
    );
  }

  /// Builds the close button used inside the toolbar swap row.
  /// Same colour as mic/`Aa` (`iconSecondary`) in both idle and tapped states.
  Widget _buildToolbarCloseButton() {
    final iconColor = _colorPalette.iconSecondary ?? Colors.grey;
    return Semantics(
      label: Translations.of(context).closeFormattingToolbar,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_spacing.radius2 ?? 8),
          onTap: _toggleRichTextSwap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(Icons.close, size: 22, color: iconColor),
          ),
        ),
      ),
    );
  }

  String _getMessagePreviewTitle(MessageComposerState state) {
    if (state.isEditMode) {
      return cc.Translations.of(context).editMessage;
    } else if (state.isReplyMode && state.replyMessage != null) {
      return state.replyMessage!.sender?.name ?? '';
    }
    return '';
  }

  String _getMessagePreviewSubtitle(MessageComposerState state) {
    BaseMessage? message;
    if (state.isEditMode) {
      message = state.editMessage;
    } else if (state.isReplyMode) {
      message = state.replyMessage;
    }

    if (message == null) return '';

    if (message is TextMessage) {
      String previewText = message.text;
      previewText = _processEditText(previewText, message);
      // Bug 1.9: Strip markdown syntax so preview shows plain text, not raw markdown
      previewText = ConversationUtils.stripMarkdownSyntax(previewText);
      return previewText;
    } else {
      // "N Images" / "N Videos" / etc. for a multi-attachment message,
      // matching the sent-bubble's quoted-reply subtitle.
      return AttachmentUtils.replySubtitleFor(message, context);
    }
  }

  // ============================================================================
  // Build Method
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates this widget's repaints from parent rebuilds
    // This helps reduce jank during keyboard open/close animations
    final Widget composerTree = ValueListenableBuilder<bool>(
      valueListenable: _attachmentOpenNotifier,
      builder: (context, isAttachmentOpen, _) => ValueListenableBuilder<bool>(
        valueListenable: _suggestionOpenNotifier,
        builder: (context, isSuggestionOpen, _) => PopScope(
          canPop: !isAttachmentOpen && !isSuggestionOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              // Just close the overlay — don't trigger navigation.
              // The user can press back again to dismiss the keyboard or navigate.
              if (isAttachmentOpen) {
                _hideAttachmentOverlay();
              } else if (isSuggestionOpen) {
                _hideSuggestionOverlay();
              }
            }
          },
          child: RepaintBoundary(
            child: BlocProvider.value(
              value: _bloc,
              child: MultiBlocListener(
                listeners: [
                  // The bloc can re-key this composer after it was built: an AI
                  // agent chat (loadLastAgentConversation) learns its thread's
                  // parentMessageId only after loading. The bloc then accepts
                  // only panels raised under the new id, so the widget and its
                  // formatters must raise them under that id too.
                  BlocListener<MessageComposerBloc, MessageComposerState>(
                    listenWhen: (previous, current) =>
                        !mapEquals(previous.composerId, current.composerId),
                    listener: (context, state) {
                      _composerId = state.composerId;
                      for (final formatter in _formatters) {
                        formatter.composerId = _composerId;
                      }
                    },
                  ),
                  BlocListener<MessageComposerBloc, MessageComposerState>(
                    listenWhen: (previous, current) =>
                        previous.composeText != current.composeText &&
                        current.composeText.isNotEmpty,
                    listener: (context, state) {
                      final controller = _getActiveTextController();
                      if (controller != null &&
                          controller.text != state.composeText) {
                        controller.text = state.composeText;
                        _bloc.add(const ClearComposeText());
                      }
                    },
                  ),
                  // Surfaces a send/edit failure (e.g. the media-caption-edit
                  // rejection) that would otherwise fail silently — only the
                  // attachment tray's own upload errors had a visible snackbar
                  // before this.
                  BlocListener<MessageComposerBloc, MessageComposerState>(
                    listenWhen: (previous, current) =>
                        previous.status != current.status &&
                        current.status == MessageComposerStatus.error,
                    listener: (context, state) {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      messenger?.hideCurrentSnackBar();
                      messenger?.showSnackBar(
                        SnackBar(
                          content: Text(
                            state.errorMessage ??
                                Translations.of(
                                  context,
                                ).somethingWentWrongError,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                child: BlocConsumer<MessageComposerBloc, MessageComposerState>(
                  // Only rebuild when state properties that affect UI change
                  // This prevents rebuilds during keyboard animation
                  buildWhen: (previous, current) {
                    final shouldRebuild =
                        previous.isEditMode != current.isEditMode ||
                        previous.isReplyMode != current.isReplyMode ||
                        previous.isRecordingMode != current.isRecordingMode ||
                        previous.editMessage != current.editMessage ||
                        previous.replyMessage != current.replyMessage ||
                        previous.headerPanel != current.headerPanel ||
                        previous.footerPanel != current.footerPanel ||
                        previous.previewPanel != current.previewPanel ||
                        previous.lockedBottomPadding !=
                            current.lockedBottomPadding ||
                        previous.isActiveStreaming != current.isActiveStreaming;
                    return shouldRebuild;
                  },
                  listener: (context, state) {
                    // Handle panel events from BLoC state
                    if (state.headerPanel != null) {
                      // Header panel is shown
                    }
                    if (state.footerPanel != null) {
                      // Footer panel is shown - sticker keyboard is visible
                    }
                    if (state.previewPanel != null) {
                      // Preview panel is shown
                    }

                    // Handle edit mode changes — need to populate text controller
                    if (state.isEditMode && state.editMessage != null) {
                      _previewMessage(
                        state.editMessage!,
                        PreviewMessageMode.edit,
                      );
                    }

                    // Drive reply/edit preview animation
                    final hasPreview =
                        (state.isEditMode && state.editMessage != null) ||
                        (state.isReplyMode && state.replyMessage != null);
                    if (hasPreview && !_previewVisible) {
                      _previewVisible = true;
                      _previewAnimController.forward(from: 0.0);
                    } else if (!hasPreview && _previewVisible) {
                      _previewVisible = false;
                      _previewAnimController.reverse();
                    }
                  },
                  listenWhen: (previous, current) =>
                      previous.isEditMode != current.isEditMode ||
                      previous.isReplyMode != current.isReplyMode ||
                      previous.editMessage != current.editMessage ||
                      previous.replyMessage != current.replyMessage ||
                      previous.headerPanel != current.headerPanel ||
                      previous.footerPanel != current.footerPanel ||
                      previous.previewPanel != current.previewPanel,
                  builder: (context, state) {
                    final messagePreviewTitle = _getMessagePreviewTitle(state);
                    final messagePreviewSubtitle = _getMessagePreviewSubtitle(
                      state,
                    );

                    return PopScope(
                      canPop: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: widget.padding,
                            child: Column(
                              children: [
                                // Header panel from BLoC state or widget
                                if (state.headerPanel != null)
                                  state.headerPanel!
                                else if (widget.headerView != null)
                                  widget.headerView!(
                                    context,
                                    widget.user,
                                    widget.group,
                                    _composerId,
                                  ),

                                // Inline message preview — renders directly above the input
                                // so they appear as one unified component
                                _buildInlinePreview(
                                  state,
                                  messagePreviewTitle,
                                  messagePreviewSubtitle,
                                ),

                                // Message input or Inline Audio Recorder
                                if (state.isRecordingMode)
                                  _buildInlineAudioRecorder()
                                else
                                  _buildMessageInputWithToolbar(state),

                                // Custom footer view from widget (not sticker keyboard)
                                if (state.footerPanel == null &&
                                    widget.footerView != null)
                                  widget.footerView!(
                                    context,
                                    widget.user,
                                    widget.group,
                                    _composerId,
                                  ),

                                // Combined bottom area: footer panel (sticker keyboard) + safe area padding
                                // This is a single widget to minimize rebuilds
                                if (!widget.hideBottomSafeArea &&
                                    !widget.resizeToAvoidBottomInset)
                                  _buildBottomArea(state)
                                // When resizeToAvoidBottomInset is true, the Scaffold handles keyboard
                                // insets but we still need to render the sticker panel if it's open.
                                else if (widget.resizeToAvoidBottomInset &&
                                    state.footerPanel != null)
                                  _buildStickerPanelOnly(state),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ), // Close MultiBlocListener
            ), // Close BlocProvider
          ), // Close RepaintBoundary
        ), // Close PopScope
      ), // Close inner ValueListenableBuilder (suggestion)
    ); // Close outer ValueListenableBuilder (attachment)

    // Web: overlay a "drop files here" prompt over the composer while a file is
    // being dragged over the composer's own area (see _isPointOverComposer).
    // Always return the Stack (overlay added as a second child only while
    // dragging) so the composer subtree keeps its state — swapping the root
    // widget would rebuild it and drop text-field focus. _dropTargetKey marks
    // this Stack's bounds as "the composer area" for the drag-position check.
    // _isDraggingFile is always false on native.
    return Stack(
      key: _dropTargetKey,
      children: [
        composerTree,
        // Inset the overlay so the scrim aligns with the *visible input bar*,
        // not the full composer container. The bar sits inside widget.padding
        // AND an extra horizontal messageInputPadding, so insetting by only the
        // former left the scrim reading wider than the bar (QA).
        if (_isDraggingFile)
          Positioned.fill(
            child: Padding(
              padding: _dropOverlayInsets(context),
              child: _buildDropOverlay(),
            ),
          ),
      ],
    );
  }

  /// Horizontal + vertical insets that align the drag scrim with the visible
  /// input bar. The bar is inset from this Stack by [widget.padding] plus the
  /// bar's own [messageInputPadding] (default `_spacing.padding2` on the
  /// sides), so the overlay must inset by the sum on left/right or it reads
  /// wider than the bar. Vertical stays at [widget.padding] (unchanged).
  EdgeInsets _dropOverlayInsets(BuildContext context) {
    final dir = Directionality.of(context);
    final base = (widget.padding ?? EdgeInsets.zero).resolve(dir);
    final p2 = _spacing.padding2 ?? 0;
    final input =
        (widget.messageInputPadding ?? EdgeInsets.fromLTRB(p2, 0, p2, p2))
            .resolve(dir);
    return EdgeInsets.only(
      left: base.left + input.left,
      right: base.right + input.right,
      top: base.top,
      bottom: base.bottom,
    );
  }

  /// The "Drop files here" panel shown over the composer during a web file
  /// drag — a dark translucent scrim rounded to the composer's corners, with
  /// a white upload glyph over bold white text (reference design).
  Widget _buildDropOverlay() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(_spacing.radius3 ?? 12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ios_share, color: Colors.white, size: 26),
              const SizedBox(height: 8),
              Text(
                Translations.of(context).dropFilesHere,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders the reply/edit preview inline, directly above the message input.
  /// When visible, the preview and input share a unified visual container —
  /// the preview has top-rounded corners and the input has square top corners.
  /// Animates in with a slide-up + fade when reply/edit mode activates.
  Widget _buildInlinePreview(
    MessageComposerState state,
    String messagePreviewTitle,
    String messagePreviewSubtitle,
  ) {
    final hasPreview = messagePreviewTitle.isNotEmpty;

    // Cache preview data when showing so reverse animation still has content
    if (hasPreview) {
      _lastPreviewTitle = messagePreviewTitle;
      _lastPreviewSubtitle = messagePreviewSubtitle;
      _lastPreviewMessage = state.isReplyMode
          ? state.replyMessage
          : state.editMessage;

      // Build formatted subtitle widget for text messages
      final previewMsg = _lastPreviewMessage;
      if (previewMsg is TextMessage) {
        final rawText = previewMsg.text;
        final formatters = FormatterUtils.ensureMarkdownFormatter(
          widget.textFormatters,
        );
        final subtitleTextStyle = TextStyle(
          fontSize: _typography.caption1?.regular?.fontSize,
          fontWeight: _typography.caption1?.regular?.fontWeight,
          color: _colorPalette.textSecondary,
        );
        _lastPreviewSubtitleWidget = RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: subtitleTextStyle,
            children: FormatterUtils.buildTextSpan(
              rawText,
              formatters,
              context,
              BubbleAlignment.left,
              forConversation: true,
              textStyle: subtitleTextStyle,
            ),
          ),
          textScaler: MediaQuery.textScalerOf(context),
        );
      } else {
        _lastPreviewSubtitleWidget = null;
      }
    }

    // Always build the preview panel outside the animation so it's not affected
    final previewPanel = state.previewPanel;

    // Use cached values during reverse animation, live values otherwise
    final isAnimating =
        _previewAnimController.isAnimating || _previewAnimController.value > 0;
    final showPreview = hasPreview || isAnimating;
    final title = hasPreview ? messagePreviewTitle : _lastPreviewTitle;
    final subtitle = hasPreview ? messagePreviewSubtitle : _lastPreviewSubtitle;
    final subtitleWidget = _lastPreviewSubtitleWidget;
    final message = hasPreview
        ? (state.isReplyMode ? state.replyMessage : state.editMessage)
        : _lastPreviewMessage;

    if (!showPreview && previewPanel == null) return const SizedBox.shrink();

    final hPad =
        (widget.messageInputPadding as EdgeInsets?)?.left ??
        _spacing.padding2 ??
        0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Suggestion list appears above the reply/edit preview
          ?previewPanel,
          if (showPreview && title.isNotEmpty)
            SizeTransition(
              sizeFactor: CurvedAnimation(
                parent: _previewAnimController,
                curve: Curves.easeOutCubic,
              ),
              // `alignment` needs Flutter 3.41; the package floor stays at 3.38.9 (DEPR1).
              // ignore: deprecated_member_use
              axisAlignment: 1.0, // grow from bottom edge (towards top)
              child: FadeTransition(
                opacity: _previewFadeAnimation,
                child: SlideTransition(
                  position: _previewSlideAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          _style.backgroundColor ?? _colorPalette.background1,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(_spacing.radius2 ?? 0),
                        topRight: Radius.circular(_spacing.radius2 ?? 0),
                      ),
                      border: Border(
                        top: BorderSide(
                          color:
                              _colorPalette.borderDefault ?? Colors.transparent,
                          width: 1,
                        ),
                        left: BorderSide(
                          color:
                              _colorPalette.borderDefault ?? Colors.transparent,
                          width: 1,
                        ),
                        right: BorderSide(
                          color:
                              _colorPalette.borderDefault ?? Colors.transparent,
                          width: 1,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.all(_spacing.padding1 ?? 4),
                    child: CometChatMessagePreview(
                      messagePreviewTitle: title,
                      messagePreviewSubtitle: subtitle,
                      subtitleWidget: subtitleWidget,
                      message: message,
                      onCloseClick: _onMessagePreviewClose,
                      messagePreviewStyle: CometChatMessagePreviewStyle(
                        closeIconColor:
                            _style.closeIconTint ?? _colorPalette.iconPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the combined bottom area containing footer panel (sticker keyboard) and safe area padding.
  /// This is a single widget to minimize rebuilds during keyboard transitions.
  Widget _buildBottomArea(MessageComposerState state) {
    // When footer panel (sticker keyboard) is shown, display it with locked padding below
    if (state.footerPanel != null) {
      // Cancel any pending clear timer since sticker is visible
      _stickerHeightClearTimer?.cancel();
      _expectingKeyboardOpen = false;

      // The sticker keyboard height should match the OS keyboard height exactly
      // _maxBottomHeight is the full keyboard height from native (includes safe area)
      // Only set the sticker height once when it first appears to avoid jiggle
      // when keyboard height changes (e.g., emoji suggestions appearing)
      if (_lastStickerTotalHeight == 0) {
        _lastStickerTotalHeight = _maxBottomHeight > 0
            ? _maxBottomHeight
            : (CometChatStickerKeyboard.defaultHeight + _safeAreaBottom);
      }

      // Max extra height the user can drag (total sticker area capped at 60% of screen)
      final double screenHeight = MediaQuery.sizeOf(context).height;
      final double baseContentHeight =
          _lastStickerTotalHeight - _safeAreaBottom;
      // Drag handle height: 4px pill + 6px top padding + 6px bottom padding = 16px
      const double dragHandleHeight = 16.0;
      final double maxTotalContent = screenHeight * 0.6;
      final double maxExtra = (maxTotalContent - baseContentHeight).clamp(
        0.0,
        double.infinity,
      );

      // Min negative extra = collapse the panel entirely
      final double minExtra = -(baseContentHeight - dragHandleHeight);

      return ValueListenableBuilder<double>(
        valueListenable: _stickerExtraHeight,
        builder: (context, extraHeight, _) {
          final double contentHeight =
              (baseContentHeight - dragHandleHeight + extraHeight).clamp(
                0.0,
                double.infinity,
              );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle — drag up to grow, drag down to shrink / close
              GestureDetector(
                onVerticalDragUpdate: (details) {
                  // Dragging up (negative dy) increases height,
                  // dragging down (positive dy) decreases height
                  final newExtra =
                      (_stickerExtraHeight.value - details.delta.dy).clamp(
                        minExtra,
                        maxExtra,
                      );
                  _stickerExtraHeight.value = newExtra;
                },
                onVerticalDragEnd: (details) {
                  // If dragged down past half the base height, close the panel
                  if (_stickerExtraHeight.value < minExtra * 0.5) {
                    _stickerExtraHeight.value = 0;
                    _lastStickerTotalHeight = 0;
                    _expectingKeyboardOpen = false;
                    _stickerHeightClearTimer?.cancel();
                    CometChatUIEvents.hidePanel(
                      _composerId,
                      CustomUIPosition.composerBottom,
                    );
                    CometChatUIEvents.unlockBottomPadding(_composerId);
                  } else if (_stickerExtraHeight.value < 0) {
                    // Snap back to base height if not dragged far enough
                    _stickerExtraHeight.value = 0;
                  }
                },
                child: Container(
                  color: Colors.transparent,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _colorPalette.neutral400 ?? Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              // Sticker keyboard with extra drag height.
              // Subtract dragHandleHeight so the total (handle + content + safeArea)
              // matches the original keyboard frame height when extraHeight is 0.
              SizedBox(height: contentHeight, child: state.footerPanel!),
              // Add safe area padding below the sticker keyboard content.
              SizedBox(height: _safeAreaBottom),
            ],
          );
        },
      );
    }

    // Sticker keyboard just closed — if _expectingKeyboardOpen was already
    // set by onKeyboardTap, we just need to keep waiting.  Otherwise (e.g.
    // user tapped the text field directly), set the flag now so the bottom
    // area maintains height while the OS keyboard animates in.
    if (_lastStickerTotalHeight > 0 &&
        !_expectingKeyboardOpen &&
        !_isKeyboardVisible) {
      _expectingKeyboardOpen = true;
      _stickerHeightClearTimer?.cancel();
      _stickerHeightClearTimer = Timer(_stickerHeightClearDelay, () {
        // If keyboard still hasn't opened after the delay, clear the sticker height
        if (!_isKeyboardVisible && _expectingKeyboardOpen) {
          _lastStickerTotalHeight = 0;
          _expectingKeyboardOpen = false;
          // Force update the notifier to safe area only
          if (mounted && !_isDisposing) {
            _bottomPaddingNotifier.value = _safeAreaBottom;
            if (mounted) {
              setState(() {});
            }
          }
        }
      });
    }

    // Normal case: use keyboard height when open, safe area when closed
    return ValueListenableBuilder<double>(
      valueListenable: _bottomPaddingNotifier,
      builder: (context, bottomPadding, child) {
        double effectivePadding;

        // During the transition window (expecting keyboard to open), maintain sticker height
        // This prevents the jump when switching from sticker to OS keyboard
        if (_expectingKeyboardOpen &&
            _lastStickerTotalHeight > 0 &&
            !_isKeyboardVisible) {
          effectivePadding = _lastStickerTotalHeight;
        } else if (_isKeyboardVisible) {
          // Keyboard is visible - use keyboard height
          effectivePadding = bottomPadding;
          // Clear sticker tracking
          if (_lastStickerTotalHeight > 0) {
            _lastStickerTotalHeight = 0;
          }
          if (_expectingKeyboardOpen) {
            _expectingKeyboardOpen = false;
            _stickerHeightClearTimer?.cancel();
          }
        } else {
          // Neither sticker nor keyboard visible - use safe area only
          effectivePadding = _safeAreaBottom;
        }

        return SizedBox(height: effectivePadding);
      },
    );
  }

  /// Renders the sticker panel without keyboard-height-based bottom padding.
  /// Used when [resizeToAvoidBottomInset] is true — the Scaffold handles
  /// keyboard insets, but we still need to show the sticker keyboard.
  Widget _buildStickerPanelOnly(MessageComposerState state) {
    final double stickerContentHeight = CometChatStickerKeyboard.defaultHeight;
    const double dragHandleHeight = 16.0;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double maxTotalContent = screenHeight * 0.6;
    final double maxExtra = (maxTotalContent - stickerContentHeight).clamp(
      0.0,
      double.infinity,
    );
    final double minExtra = -(stickerContentHeight - dragHandleHeight);

    // On wide screens (web), constrain width and align to the right
    final bool isWideScreen = kIsWeb || screenWidth > 600;
    final double maxPanelWidth = isWideScreen ? 360 : screenWidth;

    Widget panel = ValueListenableBuilder<double>(
      valueListenable: _stickerExtraHeight,
      builder: (context, extraHeight, _) {
        final double contentHeight =
            (stickerContentHeight - dragHandleHeight + extraHeight).clamp(
              0.0,
              double.infinity,
            );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            GestureDetector(
              onVerticalDragUpdate: (details) {
                final newExtra = (_stickerExtraHeight.value - details.delta.dy)
                    .clamp(minExtra, maxExtra);
                _stickerExtraHeight.value = newExtra;
              },
              onVerticalDragEnd: (details) {
                if (_stickerExtraHeight.value < minExtra * 0.5) {
                  _stickerExtraHeight.value = 0;
                  CometChatUIEvents.hidePanel(
                    _composerId,
                    CustomUIPosition.composerBottom,
                  );
                } else if (_stickerExtraHeight.value < 0) {
                  _stickerExtraHeight.value = 0;
                }
              },
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _colorPalette.neutral400 ?? Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: contentHeight, child: state.footerPanel!),
            // Safe area below sticker content
            SizedBox(height: _safeAreaBottom),
          ],
        );
      },
    );

    // On wide screens, constrain width and align to the right
    if (isWideScreen) {
      ccLog(
        '[StickerPanel] isWideScreen=true, screenWidth=$screenWidth, aligning to end',
      );
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxPanelWidth),
            child: panel,
          ),
        ],
      );
    }
    ccLog('[StickerPanel] isWideScreen=false, screenWidth=$screenWidth');
    return panel;
  }

  /// Builds the message input with an attached toolbar (if enabled).
  /// The toolbar and input share a unified visual container with:
  /// - Shared background color
  /// - Shared border
  /// - Divider between input and toolbar
  ///
  /// When the toggleable toolbar flow is active and the user has tapped
  /// the `Aa` format toggle ([_isToolbarSwapActive]), the regular button row
  /// is replaced by `[✕] + <rich-text-toolbar>`.
  Widget _buildMessageInputWithToolbar(MessageComposerState state) {
    final toolbar = _buildRichTextToolbar();
    final hasToolbar = toolbar != null;
    final showSwapRow = _isToolbarSwapActive;

    // In toggleable mode, always use the unified container even when the swap
    // is closed. Switching the ancestor chain between "unified" and the plain
    // `_buildMessageInput` tears down the TextField subtree, dropping focus
    // and, on some platforms, resetting the WYSIWYG controller's visible
    // text. Keeping the container stable avoids the rebuild pain.
    final isToggleableMode = _useToggleableToolbar;

    // When preview is showing (or animating out), the input visually connects to the preview container above
    final hasPreview =
        (state.isEditMode && state.editMessage != null) ||
        (state.isReplyMode && state.replyMessage != null) ||
        _previewAnimController.value > 0;

    // If nothing extra is expected (no toolbar, no swap, not toggleable), fall
    // back to the plain message input (no unified container).
    if (!hasToolbar && !showSwapRow && !isToggleableMode) {
      if (_tray == null) {
        return _buildMessageInput(state);
      }
      // No formatting toolbar: still render the tray directly under the input.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMessageInput(state),
          CometChatAttachmentTray(
            controller: _tray!,
            style: _style.attachmentTrayStyle,
            attachmentErrorAlertStyle: widget.attachmentErrorAlertStyle,
            attachmentErrorSnackBarBuilder:
                widget.attachmentErrorSnackBarBuilder,
            onAttachmentErrorTap: widget.onAttachmentErrorTap,
          ),
        ],
      );
    }

    // Build unified container with input + (divider + toolbar/swap row OR nothing)
    final topRadius = hasPreview
        ? Radius.zero
        : Radius.circular(_spacing.radius2 ?? 0);
    final bottomRadius = Radius.circular(_spacing.radius2 ?? 0);

    return CompositedTransformTarget(
      link: _composerLink,
      child: Padding(
        padding:
            widget.messageInputPadding ??
            EdgeInsets.fromLTRB(
              _spacing.padding2 ?? 0,
              0,
              _spacing.padding2 ?? 0,
              _spacing.padding2 ?? 0,
            ),
        child: Container(
          decoration: BoxDecoration(
            color: _style.backgroundColor ?? _colorPalette.background1,
            border:
                _style.border ??
                Border(
                  top: hasPreview
                      ? BorderSide.none
                      : BorderSide(
                          color:
                              _colorPalette.borderDefault ?? Colors.transparent,
                          width: 1,
                        ),
                  bottom: BorderSide(
                    color: _colorPalette.borderDefault ?? Colors.transparent,
                    width: 1,
                  ),
                  left: BorderSide(
                    color: _colorPalette.borderDefault ?? Colors.transparent,
                    width: 1,
                  ),
                  right: BorderSide(
                    color: _colorPalette.borderDefault ?? Colors.transparent,
                    width: 1,
                  ),
                ),
            borderRadius:
                _style.borderRadius ??
                BorderRadius.only(
                  topLeft: topRadius,
                  topRight: topRadius,
                  bottomLeft: bottomRadius,
                  bottomRight: bottomRadius,
                ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Message input (without its own border/background).
              _buildMessageInputContent(state),
              // Multi-attachment staging tray — sits BETWEEN the typing area and
              // the formatting toolbar (on by default via
              // enableMultipleAttachments).
              if (_tray != null)
                CometChatAttachmentTray(
                  controller: _tray!,
                  style: _style.attachmentTrayStyle,
                  attachmentErrorAlertStyle: widget.attachmentErrorAlertStyle,
                  attachmentErrorSnackBarBuilder:
                      widget.attachmentErrorSnackBarBuilder,
                  onAttachmentErrorTap: widget.onAttachmentErrorTap,
                ),
              // Divider + toolbar/swap row only when something is attached
              // below the input.
              if (showSwapRow) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color:
                      _colorPalette.borderLight ?? _colorPalette.borderDefault,
                  indent: _spacing.padding3 ?? 12,
                  endIndent: _spacing.padding3 ?? 12,
                ),
                _buildToolbarSwapRow(),
              ] else if (hasToolbar) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color:
                      _colorPalette.borderLight ?? _colorPalette.borderDefault,
                  indent: _spacing.padding3 ?? 12,
                  endIndent: _spacing.padding3 ?? 12,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ValueListenableBuilder<Set<FormatType>>(
                    valueListenable: _activeFormatsNotifier,
                    builder: (context, activeFormats, _) {
                      return _buildInlineRichTextToolbar(activeFormats);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Extracted inline toolbar builder. Shared by the stacked toolbar and the
  /// swap row so format dispatch logic lives in exactly one place.
  ///
  /// Set [tightLeading] to true when the toolbar is rendered right next to
  /// another icon (e.g. the close button in the swap row) — removes the
  /// toolbar's own horizontal padding so the first format icon sits snug.
  Widget _buildInlineRichTextToolbar(
    Set<FormatType> activeFormats, {
    bool tightLeading = false,
  }) {
    // Custom-toolbar escape hatch, honoured in the RENDERED path. It used to
    // live only in _buildRichTextToolbar(), whose output the layout consults
    // as a null check and then discards — so the hook never drew (Trailing
    // Toolbar Buttons DD, blocker B2). Both layout modes route through here.
    final customView = widget.richTextToolbarView;
    if (customView != null && _textEditingController != null) {
      return customView(context, _textEditingController!);
    }

    // Trailing consumer actions render only when the live controller can
    // actually service their taps — a caller-supplied plain
    // TextEditingController silently disables formatting (same gate the
    // built-in buttons have via _applyToolbarFormat), so trailing buttons
    // are withheld rather than rendered dead.
    //
    // Resolve the ACTIVE controller, not the composer-level one: with
    // segment-based code blocks the visible field is the focused segment's
    // own RichTextEditingController, and handing out the outer one would
    // give consumers a controller that neither holds the selection nor
    // paints the text. Returns null while a code segment has focus — there
    // is nothing meaningful to style there.
    final controller = _getActiveTextController();
    final trailingActions =
        (widget.richTextToolbarActions != null &&
            controller is RichTextEditingController)
        ? widget.richTextToolbarActions!(context, widget.user, widget.group, {})
        : const <CometChatMessageComposerAction>[];

    return CometChatRichTextToolbar(
      onFormatTap: _applyToolbarFormat,
      activeFormats: activeFormats,
      hiddenFormats: _getHiddenFormats(),
      trailingActions: trailingActions,
      trailingTapController: controller,
      style: CometChatRichTextToolbarStyle(
        backgroundColor: Colors.transparent,
        border: null,
        borderRadius: BorderRadius.zero,
        // Tighter spacing between format icons (default is 16)
        buttonSpacing: 4,
        // Kill the toolbar's own horizontal padding when rendering in the
        // swap row so `[✕]` sits directly next to the first format icon.
        padding: tightLeading
            ? const EdgeInsets.symmetric(horizontal: 0, vertical: 4)
            : null,
      ).merge(_style.richTextToolbarStyle),
    );
  }

  /// Shared format-tap handler used by both the stacked toolbar and the
  /// toggleable swap row. Mirrors the routing logic from the original
  /// inline handler (segment controller → WYSIWYG controller → legacy
  /// formatter manager).
  void _applyToolbarFormat(FormatType formatType) {
    // Handle link format specially
    if (formatType == FormatType.link) {
      _showLinkEditDialog();
      return;
    }

    // Ensure a segment has focus before applying format
    _ensureSegmentFocus();

    // Route through segment controller when active
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      if (formatType == FormatType.codeBlock) {
        _segmentComposerController!.toggleCodeBlock();
      } else {
        _segmentComposerController!.applyFormat(formatType);
      }
    } else if (formatType == FormatType.codeBlock &&
        _textEditingController is RichTextEditingController) {
      // Code block fallback when no segment controller exists (e.g.
      // toggleable mode). The WYSIWYG controller's `_applyCodeBlockFormat`
      // is a no-op without `onInsertCodeBlock`, so wrap the selection (or
      // insert an empty pair at the cursor) with triple backticks. The
      // markdown formatter on the receiving side renders the code block
      // correctly.
      _wrapSelectionWithCodeBlockMarkdown();
    } else if (_textEditingController is RichTextEditingController) {
      (_textEditingController as RichTextEditingController).applyFormat(
        formatType,
      );
    }

    // Notify callback
    widget.onRichTextFormatApplied?.call(formatType);

    // Update active formats notifier
    final currentFormats = _getActiveFormats();
    if (!_setEquals(currentFormats, _previousActiveFormats)) {
      _previousActiveFormats = currentFormats;
      _activeFormatsNotifier.value = currentFormats;
    }
  }

  /// Wraps the current selection with triple-backtick code block markers.
  /// If the selection is collapsed, inserts an empty ``` ``` pair and places
  /// the cursor between the fences. Used as the code-block fallback when the
  /// segment-based controller is unavailable (e.g. toggleable mode).
  void _wrapSelectionWithCodeBlockMarkdown() {
    final controller = _textEditingController;
    if (controller == null) return;

    final currentText = controller.text;
    final sel = controller.selection;
    if (!sel.isValid) return;

    final start = sel.start;
    final end = sel.end;

    const opener = '```\n';
    const closer = '\n```';
    final inner = currentText.substring(start, end);

    final newText =
        currentText.substring(0, start) +
        opener +
        inner +
        closer +
        currentText.substring(end);

    // Place cursor between the fences when inserting an empty block, otherwise
    // keep the selection around the wrapped content.
    final TextSelection newSel;
    if (inner.isEmpty) {
      final caret = start + opener.length;
      newSel = TextSelection.collapsed(offset: caret);
    } else {
      newSel = TextSelection(
        baseOffset: start + opener.length,
        extentOffset: start + opener.length + inner.length,
      );
    }

    controller.value = TextEditingValue(text: newText, selection: newSel);
  }

  /// Builds the row used when [_isToolbarSwapActive] is true.
  ///
  /// Renders `[✕] + <toolbar>`. The close button dismisses the swap row
  /// (same effect as re-tapping `Aa` — which is hidden while the swap is
  /// active because the auxiliary row is suppressed).
  Widget _buildToolbarSwapRow() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _spacing.padding2 ?? 8,
        vertical: _spacing.padding1 ?? 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Close button — dismisses the swap row
          _buildToolbarCloseButton(),
          // Toolbar takes remaining space (scrollable if it overflows).
          // No extra SizedBox gap here — the toolbar's internal horizontal
          // padding is also removed so the first format icon sits snug
          // next to the close icon.
          Expanded(
            child: ValueListenableBuilder<Set<FormatType>>(
              valueListenable: _activeFormatsNotifier,
              builder: (context, activeFormats, _) {
                return _buildInlineRichTextToolbar(
                  activeFormats,
                  tightLeading: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Get active formats for the toolbar
  Set<FormatType> _getActiveFormats() {
    // When using segment-based code blocks, check if we're in a code segment
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      return _segmentComposerController!.getActiveFormats();
    }

    if (_textEditingController is RichTextEditingController) {
      return (_textEditingController as RichTextEditingController)
          .getActiveFormats();
    }
    return {};
  }

  /// Get hidden formats for the toolbar.
  ///
  /// Returns the union of:
  /// * formats the user explicitly hid via
  ///   [CometChatMessageComposer.hideRichTextFormattingOptions], AND
  /// * formats implicitly disabled by [enableRichTextFormatting] being off
  ///   (in that case everything is hidden — but the toolbar itself is also
  ///   not rendered, so the set is academic).
  Set<FormatType> _getHiddenFormats() {
    if (!widget.enableRichTextFormatting) {
      return const {
        FormatType.bold,
        FormatType.italic,
        FormatType.underline,
        FormatType.strikethrough,
        FormatType.inlineCode,
        FormatType.codeBlock,
        FormatType.link,
        FormatType.bulletList,
        FormatType.orderedList,
        FormatType.blockquote,
      };
    }
    return widget.hideRichTextFormattingOptions;
  }

  /// Builds just the message input content without the outer container styling.
  /// Used when the input is part of a unified container with the toolbar.
  Widget _buildMessageInputContent(MessageComposerState state) {
    // When segment-based code blocks are active, use SegmentComposerWidget
    if (_useSegmentBasedCodeBlocks && _segmentComposerController != null) {
      return _buildSegmentBasedInput(state);
    }

    // In double-line mode the text row, divider, and button row need more
    // vertical space than 120 — so lift the cap for that layout while keeping
    // the existing single-line cap for backward-compat.
    final isDoubleLine = widget.layout == CometChatComposerLayout.doubleLine;
    final maxHeight = isDoubleLine ? 220.0 : 120.0;

    // Wrap in ConstrainedBox to limit max height and enable scrolling
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: CometChatMessageInput(
        text: widget.text,
        textEditingController: _textEditingController,
        placeholderText: widget.placeholderText,
        maxLine: widget.maxLine,
        onChange: _onChange,
        onContentInserted: _handleKeyboardContentInserted,
        onPasteImage: widget.disableImagePaste ? null : _pasteClipboardFile,
        onTap: _handleComposerTap,
        primaryButtonView: _buildSendButton(state),
        secondaryButtonView: _buildSecondaryButtonView(state),
        auxiliaryButtonsAlignment: _effectiveAuxiliaryAlignment,
        auxiliaryButtonView: _buildAuxiliaryButtonView(state),
        layout: widget.layout,
        // In toggleable mode, when the `Aa` swap is active, suppress the
        // input's built-in divider + button row — the swap row (Aa +
        // toolbar) takes its place.
        hideBottomView: _isToolbarSwapActive,
        // Code block is now inline - no special indicator needed
        showCodeBlockIndicator: false,
        codeBlockIndicatorColor: _colorPalette.primary,
        codeBlockContent: null,
        style: CometChatMessageInputStyle(
          filledColor: _style.filledColor,
          dividerTint: _style.dividerColor ?? _colorPalette.borderLight,
          dividerHeight: _style.dividerHeight,
          backgroundColor: Colors
              .transparent, // Transparent - parent container has background
          textStyle: TextStyle(
            color: _colorPalette.textPrimary,
            fontSize: _typography.body?.regular?.fontSize,
            fontWeight: _typography.body?.regular?.fontWeight,
            fontFamily: _typography.body?.regular?.fontFamily,
          ).merge(_style.textStyle).copyWith(color: _style.textColor),
          placeholderTextStyle:
              TextStyle(
                    color: _colorPalette.textTertiary,
                    fontSize: _typography.body?.regular?.fontSize,
                    fontWeight: _typography.body?.regular?.fontWeight,
                    fontFamily: _typography.body?.regular?.fontFamily,
                  )
                  .merge(_style.placeHolderTextStyle)
                  .copyWith(color: _style.placeHolderTextColor),
          border: null, // No border - parent container has border
          borderRadius:
              BorderRadius.zero, // No radius - parent container has radius
        ),
        focusNode: _focusNode,
      ),
    );
  }

  /// Builds segment-based input for Slack-style code blocks.
  /// Each segment (normal text or code block) has its own text field.
  /// Layout-aware — matches [CometChatMessageInput]'s single/double-line shape.
  Widget _buildSegmentBasedInput(MessageComposerState state) {
    final isDoubleLine = widget.layout == CometChatComposerLayout.doubleLine;
    return isDoubleLine
        ? _buildSegmentBasedInputDoubleLine(state)
        : _buildSegmentBasedInputSingleLine(state);
  }

  /// Single-row segment layout — existing behavior (all buttons inline).
  Widget _buildSegmentBasedInputSingleLine(MessageComposerState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Secondary buttons (left side - attachment button)
          if (widget.secondaryButtonView != null)
            Padding(
              padding: EdgeInsets.only(top: 12, bottom: kIsWeb ? 14 : 17),
              child: widget.secondaryButtonView!(
                context,
                widget.user,
                widget.group,
                _composerId,
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(top: 12, bottom: kIsWeb ? 14 : 17),
              child: _buildSecondaryButtonView(state),
            ),

          // Auxiliary buttons (left alignment option)
          if (_effectiveAuxiliaryAlignment == AuxiliaryButtonsAlignment.left)
            Padding(
              padding: EdgeInsets.only(top: 12, bottom: kIsWeb ? 12 : 17),
              child: _buildAuxiliaryButtonView(state),
            ),

          // Segment composer (center, expanded)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: _spacing.padding2 ?? 8,
                right: _spacing.padding2 ?? 8,
                top: 12,
                bottom: kIsWeb ? 14 : 12,
              ),
              child: SegmentComposerWidget(
                controller: _segmentComposerController!,
                placeholder:
                    widget.placeholderText ??
                    Translations.of(context).typeYourMessage,
                colorPalette: _colorPalette,
                spacing: _spacing,
                typography: _typography,
                textStyle: TextStyle(
                  color: _colorPalette.textPrimary,
                  fontSize: _typography.body?.regular?.fontSize,
                  fontWeight: _typography.body?.regular?.fontWeight,
                  fontFamily: _typography.body?.regular?.fontFamily,
                ).merge(_style.textStyle).copyWith(color: _style.textColor),
                placeholderStyle:
                    TextStyle(
                          color: _colorPalette.textTertiary,
                          fontSize: _typography.body?.regular?.fontSize,
                          fontWeight: _typography.body?.regular?.fontWeight,
                          fontFamily: _typography.body?.regular?.fontFamily,
                        )
                        .merge(_style.placeHolderTextStyle)
                        .copyWith(color: _style.placeHolderTextColor),
                maxHeight: 120,
                onContentInserted: _handleKeyboardContentInserted,
                onPasteImage: widget.disableImagePaste
                    ? null
                    : _pasteClipboardFile,
                onChange: (text) {
                  _onChange(text);
                },
              ),
            ),
          ),

          // Auxiliary buttons (right alignment - default)
          if (_effectiveAuxiliaryAlignment == AuxiliaryButtonsAlignment.right)
            Padding(
              padding: EdgeInsets.only(top: 12, bottom: kIsWeb ? 12 : 17),
              child: _buildAuxiliaryButtonView(state),
            ),

          // Primary/Send button (far right)
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              top: 12,
              bottom: kIsWeb ? 10 : 12,
            ),
            child: _buildSendButton(state),
          ),
        ],
      ),
    );
  }

  /// Double-line segment layout — text on row 1, buttons on row 2 separated by
  /// a divider. Mirrors `CometChatMessageInput._buildDoubleLineLayout`.
  Widget _buildSegmentBasedInputDoubleLine(MessageComposerState state) {
    final horizontalPadding = _spacing.padding3 ?? 12.0;
    final toolbarVerticalPadding = _spacing.padding2 ?? 8.0;
    final clusterIconGap = _spacing.margin4 ?? 4.0;
    final isLeftAligned =
        _effectiveAuxiliaryAlignment == AuxiliaryButtonsAlignment.left;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Row 1: Segment text input ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ConstrainedBox(
            // Give the segment text field at least 48dp of height (matches
            // Material's default TextField intrinsic height and v5).
            // SegmentComposerWidget uses `isDense: true` internally which
            // otherwise collapses it to ~20dp.
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentComposerWidget(
                controller: _segmentComposerController!,
                placeholder:
                    widget.placeholderText ??
                    Translations.of(context).typeYourMessage,
                colorPalette: _colorPalette,
                spacing: _spacing,
                typography: _typography,
                textStyle: TextStyle(
                  color: _colorPalette.textPrimary,
                  fontSize: _typography.body?.regular?.fontSize,
                  fontWeight: _typography.body?.regular?.fontWeight,
                  fontFamily: _typography.body?.regular?.fontFamily,
                ).merge(_style.textStyle).copyWith(color: _style.textColor),
                placeholderStyle:
                    TextStyle(
                          color: _colorPalette.textTertiary,
                          fontSize: _typography.body?.regular?.fontSize,
                          fontWeight: _typography.body?.regular?.fontWeight,
                          fontFamily: _typography.body?.regular?.fontFamily,
                        )
                        .merge(_style.placeHolderTextStyle)
                        .copyWith(color: _style.placeHolderTextColor),
                maxHeight: 120,
                onContentInserted: _handleKeyboardContentInserted,
                onPasteImage: widget.disableImagePaste
                    ? null
                    : _pasteClipboardFile,
                onChange: (text) {
                  _onChange(text);
                },
              ),
            ),
          ),
        ),

        // ── Divider ──
        if (!_isToolbarSwapActive)
          Divider(
            height: 1,
            thickness: 1,
            color: _colorPalette.borderLight ?? _colorPalette.borderDefault,
            indent: horizontalPadding,
            endIndent: horizontalPadding,
          ),

        // ── Row 2: Button toolbar ──
        if (!_isToolbarSwapActive)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: toolbarVerticalPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT cluster: secondary + left-aligned auxiliary
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSecondaryButtonView(state),
                      if (isLeftAligned)
                        Padding(
                          padding: EdgeInsets.only(left: clusterIconGap),
                          child: _buildAuxiliaryButtonView(state),
                        ),
                    ],
                  ),
                ),

                // RIGHT cluster: right-aligned auxiliary + send
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isLeftAligned) _buildAuxiliaryButtonView(state),
                      Padding(
                        padding: EdgeInsets.only(left: clusterIconGap),
                        child: _buildSendButton(state),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMessageInput(MessageComposerState state) {
    // When preview is showing (or animating out), the input visually connects to the preview container above:
    // - no top border (preview container provides it)
    // - square top corners (preview container has the rounded top)
    final hasPreview =
        (state.isEditMode && state.editMessage != null) ||
        (state.isReplyMode && state.replyMessage != null) ||
        _previewAnimController.value > 0;
    final topRadius = hasPreview
        ? Radius.zero
        : Radius.circular(_spacing.radius2 ?? 0);
    final bottomRadius = Radius.circular(_spacing.radius2 ?? 0);

    return CompositedTransformTarget(
      link: _composerLink,
      child: Padding(
        padding:
            widget.messageInputPadding ??
            EdgeInsets.fromLTRB(
              _spacing.padding2 ?? 0,
              0,
              _spacing.padding2 ?? 0,
              _spacing.padding2 ?? 0,
            ),
        child: CometChatMessageInput(
          text: widget.text,
          textEditingController: _textEditingController,
          placeholderText: widget.placeholderText,
          maxLine: widget.maxLine,
          onChange: _onChange,
          onTap: _handleComposerTap,
          primaryButtonView: _buildSendButton(state),
          secondaryButtonView: _buildSecondaryButtonView(state),
          auxiliaryButtonsAlignment: _effectiveAuxiliaryAlignment,
          auxiliaryButtonView: _buildAuxiliaryButtonView(state),
          layout: widget.layout,
          // Code block is now inline - no special indicator needed
          showCodeBlockIndicator: false,
          codeBlockIndicatorColor: _colorPalette.primary,
          codeBlockContent: null,
          style: CometChatMessageInputStyle(
            filledColor: _style.filledColor,
            dividerTint: _style.dividerColor ?? _colorPalette.borderLight,
            dividerHeight: _style.dividerHeight,
            backgroundColor:
                _style.backgroundColor ?? _colorPalette.background1,
            textStyle: TextStyle(
              color: _colorPalette.textPrimary,
              fontSize: _typography.body?.regular?.fontSize,
              fontWeight: _typography.body?.regular?.fontWeight,
              fontFamily: _typography.body?.regular?.fontFamily,
            ).merge(_style.textStyle).copyWith(color: _style.textColor),
            placeholderTextStyle:
                TextStyle(
                      color: _colorPalette.textTertiary,
                      fontSize: _typography.body?.regular?.fontSize,
                      fontWeight: _typography.body?.regular?.fontWeight,
                      fontFamily: _typography.body?.regular?.fontFamily,
                    )
                    .merge(_style.placeHolderTextStyle)
                    .copyWith(color: _style.placeHolderTextColor),
            border:
                _style.border ??
                Border(
                  top: hasPreview
                      ? BorderSide.none
                      : BorderSide(
                          color:
                              _colorPalette.borderDefault ?? Colors.transparent,
                          width: 1,
                        ),
                  bottom: BorderSide(
                    color: _colorPalette.borderDefault ?? Colors.transparent,
                    width: 1,
                  ),
                  left: BorderSide(
                    color: _colorPalette.borderDefault ?? Colors.transparent,
                    width: 1,
                  ),
                  right: BorderSide(
                    color: _colorPalette.borderDefault ?? Colors.transparent,
                    width: 1,
                  ),
                ),
            borderRadius:
                _style.borderRadius ??
                BorderRadius.only(
                  topLeft: topRadius,
                  topRight: topRadius,
                  bottomLeft: bottomRadius,
                  bottomRight: bottomRadius,
                ),
          ),
          focusNode: _focusNode,
        ),
      ),
    );
  }

  Widget _buildInlineAudioRecorder() {
    return Padding(
      padding:
          widget.messageInputPadding ??
          EdgeInsets.fromLTRB(
            _spacing.padding2 ?? 0,
            0,
            _spacing.padding2 ?? 0,
            _spacing.padding2 ?? 0,
          ),
      child: CometChatInlineAudioRecorder(
        style: _style.inlineAudioRecorderStyle,
        onSubmit: (path, {List<int>? fileBytes}) {
          _bloc.add(
            SubmitAudioRecording(
              path,
              fileBytes: fileBytes,
              fileName: 'audio.webm',
            ),
          );
        },
        onCancel: () {
          _bloc.add(const CancelAudioRecording());
        },
        deleteIcon: widget.recorderDeleteButtonIcon,
        sendIcon: widget.recorderSendButtonIcon,
        recordIcon: widget.recorderStartButtonIcon,
        pauseIcon: widget.recorderPauseButtonIcon,
        stopIcon: widget.recorderStopButtonIcon,
      ),
    );
  }
}
