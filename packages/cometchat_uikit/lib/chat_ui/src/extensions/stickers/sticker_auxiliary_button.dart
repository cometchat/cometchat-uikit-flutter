import 'package:flutter/material.dart';

import '../../../../cometchat_chat_uikit.dart';
import '../../../../shared_ui/src/clean_architecture/core/utils/ui_event_target.dart';

///[StickerAuxiliaryButton] is the widget that represents the `StickersExtension`
///in the auxiliary button view of the [CometChatMessageComposer].
///
///While the sticker panel is closed it shows [stickerButtonIcon], or the
///outline sticker icon tinted with [stickerIconTint] (secondary icon colour by
///default). While the panel is open it shows [keyboardButtonIcon], or the
///filled sticker icon tinted with [keyboardIconTint] (primary colour by
///default). Custom icons are shown as given, untinted. Tapping toggles the
///sticker panel open/closed.
class StickerAuxiliaryButton extends StatefulWidget {
  const StickerAuxiliaryButton({
    super.key,
    this.keyboardButtonIcon,
    this.stickerButtonIcon,
    this.onKeyboardTap,
    this.onStickerTap,
    this.stickerIconTint,
    this.keyboardIconTint,
    this.composerId,
  });

  ///[composerId] identifies the composer this button belongs to, so panel
  ///events raised by a different composer (a thread opened beside this one)
  ///do not reset this button's icon. Null keeps the old behaviour of reacting
  ///to any composer's panel.
  final Map<String, dynamic>? composerId;

  ///[stickerButtonIcon] custom icon shown while the sticker panel is closed
  final Widget? stickerButtonIcon;

  ///[keyboardButtonIcon] custom icon shown while the sticker panel is open
  final Widget? keyboardButtonIcon;

  ///[onStickerTap] called when the button is tapped while the panel is closed
  final Function()? onStickerTap;

  ///[onKeyboardTap] called when the button is tapped while the panel is open
  final Function()? onKeyboardTap;

  ///[stickerIconTint] tints the default icon while the panel is closed
  final Color? stickerIconTint;

  ///[keyboardIconTint] tints the default icon while the panel is open
  final Color? keyboardIconTint;

  @override
  State<StickerAuxiliaryButton> createState() => _StickerAuxiliaryButtonState();
}

class _StickerAuxiliaryButtonState extends State<StickerAuxiliaryButton>
    with CometChatUIEventListener {
  /// true = sticker panel is closed (default), false = sticker panel is open
  bool _isStickerPanelClosed = true;

  late String _listenerId;
  late CometChatColorPalette colorPalette;
  late CometChatSpacing spacing;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;
  @override
  void initState() {
    super.initState();
    // Was the constant "StickerAuxiliaryButtonListener". The listener map is
    // keyed by this string, so a second composer's button silently evicted the
    // first one's — leaving that button registered nowhere and permanently
    // deaf to hidePanel, with its icon stuck in the open state.
    _listenerId =
        'StickerAuxiliaryButtonListener_'
        '${identityHashCode(this)}';
    CometChatUIEvents.addUiListener(_listenerId, this);
  }

  @override
  void dispose() {
    CometChatUIEvents.removeUiListener(_listenerId);
    super.dispose();
  }

  @override
  void hidePanel(Map<String, dynamic>? id, CustomUIPosition uiPosition) {
    // A button built without a composerId keeps the old behaviour and reacts
    // to any composer's panel; one that has an id only reacts to its own.
    final composerId = widget.composerId;
    if (composerId != null &&
        !uiEventTargets(id, composerId, nullTargetsAll: true)) {
      return;
    }
    if (uiPosition == CustomUIPosition.composerBottom &&
        !_isStickerPanelClosed) {
      setState(() {
        _isStickerPanelClosed = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (_themeInitialized && !brightnessChanged) return;
    _cachedBrightness = currentBrightness;
    _themeInitialized = true;
    colorPalette = CometChatThemeHelper.getColorPalette(context);
    spacing = CometChatThemeHelper.getSpacing(context);
  }

  @override
  Widget build(BuildContext context) {
    final Color inactiveColor =
        widget.stickerIconTint ?? colorPalette.iconSecondary ?? Colors.grey;
    final Color activeColor =
        widget.keyboardIconTint ?? colorPalette.primary ?? Colors.purple;

    // Closed: the custom sticker icon, else the tinted outline icon.
    // Open: the custom active icon, else the tinted filled icon — a custom
    // closed-state icon is never carried into the open state (as Android).
    final Widget icon = _isStickerPanelClosed
        ? widget.stickerButtonIcon ??
              Image.asset(
                AssetConstants.smile,
                package: UIConstants.packageName,
                height: 24,
                width: 24,
                color: inactiveColor,
              )
        : widget.keyboardButtonIcon ??
              Image.asset(
                AssetConstants.stickerFilled,
                package: UIConstants.packageName,
                height: 24,
                width: 24,
                color: activeColor,
              );

    return SizedBox(
      height: 24,
      width: 24,
      child: IconButton(
        tooltip: Translations.of(context).sticker,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () {
          if (_isStickerPanelClosed) {
            widget.onStickerTap?.call();
            setState(() => _isStickerPanelClosed = false);
          } else {
            widget.onKeyboardTap?.call();
            setState(() => _isStickerPanelClosed = true);
          }
        },
        icon: icon,
      ),
    );
  }
}
