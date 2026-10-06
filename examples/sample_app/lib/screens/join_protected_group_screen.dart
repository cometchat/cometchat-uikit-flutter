import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import 'messages_screen.dart';

/// Join Protected Group screen — shown as a bottom sheet for password groups.
class JoinProtectedGroupScreen extends StatefulWidget {
  final Group group;

  const JoinProtectedGroupScreen({super.key, required this.group});

  @override
  State<JoinProtectedGroupScreen> createState() =>
      _JoinProtectedGroupScreenState();
}

class _JoinProtectedGroupScreenState extends State<JoinProtectedGroupScreen> {
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isEmpty = false;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    _typography = CometChatThemeHelper.getTypography(context);
    _spacing = CometChatThemeHelper.getSpacing(context);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _joinGroup() {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _isEmpty = true);
      return;
    }

    setState(() {
      _isLoading = true;
      _isEmpty = false;
      _isError = false;
    });

    CometChat.joinGroup(
      widget.group.guid,
      GroupTypeConstants.password,
      password: password,
      onSuccess: (Group group) async {
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (!group.hasJoined) group.hasJoined = true;
        final user = await CometChat.getLoggedInUser();
        if (user != null) {
          CometChatGroupEvents.ccGroupMemberJoined(user, group);
        }
        if (!mounted) return;
        Navigator.pop(context); // close bottom sheet
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'messages'),
            builder: (_) => MessagesScreen(group: group),
          ),
        );
      },
      onError: (CometChatException e) {
        if (!mounted) return;
        debugPrint('Join group failed: ${e.message}');
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage =
              e.message ?? 'Something went wrong. Please try again.';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _colorPalette.background1,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(_spacing.radius6 ?? 0),
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            decoration: BoxDecoration(
              color: _colorPalette.background1,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_spacing.radius6 ?? 0),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: _spacing.padding5 ?? 0,
                left: _spacing.padding6 ?? 0,
                right: _spacing.padding6 ?? 0,
                bottom: _spacing.padding10 ?? 0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAvatar(),
                    _buildPasswordInput(),
                    _buildErrorBanner(),
                    _buildJoinButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: _spacing.padding5 ?? 0),
        child: Column(
          children: [
            Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: _spacing.padding3 ?? 0),
                  child: CometChatAvatar(
                    height: 60,
                    width: 60,
                    name: widget.group.name,
                    image: widget.group.icon ?? '',
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 5,
                  child: CometChatStatusIndicator(
                    style: CometChatStatusIndicatorStyle(
                      backgroundColor: _colorPalette.success,
                      border: Border.all(
                        color: _colorPalette.white ?? Colors.white,
                      ),
                    ),
                    backgroundImage: Icon(
                      Icons.lock,
                      size: 8,
                      color: _colorPalette.white,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(bottom: _spacing.padding1 ?? 0),
              child: Text(
                widget.group.name,
                style: TextStyle(
                  fontFamily: _typography.heading4?.medium?.fontFamily,
                  fontSize: _typography.heading4?.medium?.fontSize,
                  color: _colorPalette.textPrimary,
                  fontWeight: _typography.heading4?.medium?.fontWeight,
                ),
              ),
            ),
            Text(
              '${widget.group.membersCount} ${cc.Translations.of(context).members}',
              style: TextStyle(
                fontFamily: _typography.caption1?.regular?.fontFamily,
                fontSize: _typography.caption1?.regular?.fontSize,
                color: _colorPalette.textSecondary,
                fontWeight: _typography.caption1?.regular?.fontWeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordInput() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: _spacing.padding1 ?? 0),
            child: Text(
              'Enter Password',
              style: TextStyle(
                fontSize: _typography.caption1?.medium?.fontSize,
                fontWeight: _typography.caption1?.medium?.fontWeight,
                fontFamily: _typography.caption1?.medium?.fontFamily,
                color: _colorPalette.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: _spacing.padding6 ?? 0),
            child: TextFormField(
              controller: _passwordController,
              style: TextStyle(
                color: _colorPalette.textPrimary,
                fontSize: _typography.body?.regular?.fontSize,
                fontFamily: _typography.body?.regular?.fontFamily,
                fontWeight: _typography.body?.regular?.fontWeight,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: _spacing.padding2 ?? 0,
                  horizontal: _spacing.padding2 ?? 0,
                ),
                border: _inputBorder(),
                enabledBorder: _inputBorder(),
                focusedBorder: _inputBorder(),
                hintText: 'Enter the password',
                hintStyle: TextStyle(
                  color: _colorPalette.textTertiary,
                  fontSize: _typography.body?.regular?.fontSize,
                  fontFamily: _typography.body?.regular?.fontFamily,
                  fontWeight: _typography.body?.regular?.fontWeight,
                ),
                filled: true,
                fillColor: _colorPalette.background2,
                errorStyle: const TextStyle(fontSize: 0),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  setState(() => _isEmpty = true);
                  return '';
                }
                setState(() => _isEmpty = false);
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (!_isEmpty && !_isError) return const SizedBox();
    return Padding(
      padding: EdgeInsets.only(bottom: _spacing.padding4 ?? 20),
      child: Container(
        decoration: BoxDecoration(
          color: _colorPalette.error?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(_spacing.radius2 ?? 8),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: _spacing.padding2 ?? 8,
          vertical: _spacing.padding1 ?? 4,
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(right: _spacing.padding1 ?? 2),
              child: Icon(Icons.error_outline,
                  color: _colorPalette.error, size: 16),
            ),
            Expanded(
              child: Text(
                _isEmpty
                    ? 'Please fill in all required fields before joining a group.'
                    : _errorMessage.isNotEmpty
                        ? _errorMessage
                        : 'Something went wrong. Please try again.',
                style: TextStyle(
                  color: _colorPalette.error,
                  fontSize: _typography.caption1?.regular?.fontSize,
                  fontFamily: _typography.caption1?.regular?.fontFamily,
                  fontWeight: _typography.caption1?.regular?.fontWeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _joinGroup,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(_colorPalette.primary),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_spacing.radius2 ?? 8),
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
                'Join Group',
                style: TextStyle(
                  color: _colorPalette.buttonIconColor,
                  fontSize: _typography.button?.medium?.fontSize,
                  fontFamily: _typography.button?.medium?.fontFamily,
                  fontWeight: _typography.button?.medium?.fontWeight,
                ),
              ),
      ),
    );
  }

  OutlineInputBorder _inputBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_spacing.radius2 ?? 0),
      borderSide: BorderSide(
        width: 1,
        color: _colorPalette.borderLight ?? Colors.transparent,
      ),
    );
  }
}

/// Show the Join Protected Group bottom sheet (mobile + web).
Future<void> showJoinProtectedGroup({
  required BuildContext context,
  required CometChatColorPalette colorPalette,
  required Group group,
}) {
  final screenSize = MediaQuery.of(context).size;
  final isWide = screenSize.width >= 600;

  return showModalBottomSheet(
    backgroundColor: colorPalette.background1,
    context: context,
    isDismissible: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    constraints: isWide ? const BoxConstraints(maxWidth: 480) : null,
    builder: (ctx) => SizedBox(
      height: screenSize.height * 0.5,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: JoinProtectedGroupScreen(group: group),
      ),
    ),
  );
}
