import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// Transfer Ownership screen — select a member to transfer group ownership to.
/// Uses CometChatGroupMembers with single selection mode.
class TransferOwnershipScreen extends StatefulWidget {
  final Group group;

  const TransferOwnershipScreen({super.key, required this.group});

  @override
  State<TransferOwnershipScreen> createState() =>
      _TransferOwnershipScreenState();
}

class _TransferOwnershipScreenState extends State<TransferOwnershipScreen> {
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;

  bool _isLoading = false;

  /// Controller reference obtained via stateCallBack — no GetX needed.
  CometChatGroupMembersController? _membersController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    _typography = CometChatThemeHelper.getTypography(context);
    _spacing = CometChatThemeHelper.getSpacing(context);
  }

  void _onTransferPressed() {
    final controller = _membersController;
    if (controller == null) return;

    if (controller.selectionMap.entries.isNotEmpty) {
      final member = controller.selectionMap.entries.first.value;
      if (member.uid == widget.group.owner) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _colorPalette.error,
          content: Text(
            'You are already the owner of this group.',
            style: TextStyle(
              color: _colorPalette.white,
              fontSize: _typography.button?.medium?.fontSize,
              fontWeight: _typography.button?.medium?.fontWeight,
              fontFamily: _typography.button?.medium?.fontFamily,
            ),
          ),
        ));
        return;
      }
      _showConfirmDialog(member);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _colorPalette.error,
        content: Text(
          'Please select a member before proceeding.',
          style: TextStyle(
            color: _colorPalette.white,
            fontSize: _typography.button?.medium?.fontSize,
            fontWeight: _typography.button?.medium?.fontWeight,
            fontFamily: _typography.button?.medium?.fontFamily,
          ),
        ),
      ));
    }
  }

  void _showConfirmDialog(GroupMember member) {
    CometChatConfirmDialog(
      context: context,
      showIcon: false,
      title: const Text('Ownership Transfer', textAlign: TextAlign.center),
      messageText: const Text(
        "Are you sure you want to transfer ownership? This can't be undone, and the new owner will take full control.",
        textAlign: TextAlign.center,
      ),
      confirmButtonText: 'Transfer',
      cancelButtonText: 'Cancel',
      style: CometChatConfirmDialogStyle(
        confirmButtonBackground: _colorPalette.primary,
        confirmButtonTextColor: _colorPalette.white,
        titleTextStyle: TextStyle(
          color: _colorPalette.textPrimary,
          fontSize: _typography.heading2?.medium?.fontSize,
          fontWeight: _typography.heading2?.medium?.fontWeight,
          fontFamily: _typography.heading2?.medium?.fontFamily,
        ),
        messageTextStyle: TextStyle(
          color: _colorPalette.textSecondary,
          fontSize: _typography.body?.regular?.fontSize,
          fontWeight: _typography.body?.regular?.fontWeight,
          fontFamily: _typography.body?.regular?.fontFamily,
        ),
        confirmButtonTextStyle: TextStyle(
          color: _colorPalette.white,
          fontSize: _typography.button?.medium?.fontSize,
          fontWeight: _typography.button?.medium?.fontWeight,
          fontFamily: _typography.button?.medium?.fontFamily,
        ),
        cancelButtonTextStyle: TextStyle(
          color: _colorPalette.textPrimary,
          fontSize: _typography.button?.medium?.fontSize,
          fontWeight: _typography.button?.medium?.fontWeight,
          fontFamily: _typography.button?.medium?.fontFamily,
        ),
      ),
      onCancel: (dialogContext) => Navigator.of(dialogContext).pop(),
      onConfirm: (dialogContext) => _performTransfer(member, dialogContext),
    ).show();
  }

  void _performTransfer(GroupMember member, BuildContext dialogContext) {
    setState(() => _isLoading = true);
    CometChat.transferGroupOwnership(
      guid: widget.group.guid,
      uid: member.uid,
      onSuccess: (_) {
        if (!mounted) return;
        widget.group.owner = member.uid;
        CometChatGroupEvents.ccOwnershipChanged(widget.group, member);
        Navigator.of(dialogContext).pop(); // close dialog
        Navigator.pop(context, 'LeaveGroup'); // close screen, signal leave
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.of(dialogContext).pop(); // close dialog
        debugPrint('Ownership transfer failed: ${e.message}');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _colorPalette.background1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _colorPalette.iconPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        centerTitle: false,
        title: Text(
          'Ownership Transfer',
          style: TextStyle(
            color: _colorPalette.textPrimary,
            fontSize: _typography.heading1?.bold?.fontSize,
            fontWeight: _typography.heading1?.bold?.fontWeight,
            fontFamily: _typography.heading1?.bold?.fontFamily,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CometChatGroupMembers(
              stateCallBack: (controller) => _membersController = controller,
              hideAppbar: true,
              selectionMode: SelectionMode.single,
              submitIcon: const SizedBox(),
              activateSelection: ActivateSelection.onClick,
              group: widget.group,
              setOptions: (group, groupMember, controller, context) => const [],
            ),
          ),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: _colorPalette.background1,
              border: Border(
                top: BorderSide(
                  color: _colorPalette.borderLight ?? Colors.transparent,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _spacing.margin3 ?? 0,
                vertical: _spacing.margin4 ?? 0,
              ),
              child: SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onTransferPressed,
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all(_colorPalette.primary),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(_spacing.radius2 ?? 8),
                    )),
                    padding: WidgetStateProperty.all(EdgeInsets.symmetric(
                      vertical: _spacing.padding2 ?? 8,
                      horizontal: _spacing.padding5 ?? 20,
                    )),
                  ),
                  child: Center(
                    child: _isLoading
                        ? CircularProgressIndicator(color: _colorPalette.white)
                        : Text(
                            'Ownership Transfer',
                            style: TextStyle(
                              color: _colorPalette.buttonIconColor,
                              fontSize: _typography.button?.medium?.fontSize,
                              fontFamily:
                                  _typography.button?.medium?.fontFamily,
                              fontWeight:
                                  _typography.button?.medium?.fontWeight,
                            ),
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
}
