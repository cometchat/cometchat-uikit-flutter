import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;

/// Create Group screen — shown as a bottom sheet.
/// Supports Public, Private, and Password group types.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen>
    with SingleTickerProviderStateMixin {
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;

  late TabController _tabController;
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _groupType = GroupTypeConstants.public;
  bool _isLoading = false;
  bool _isEmpty = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    _typography = CometChatThemeHelper.getTypography(context);
    _spacing = CometChatThemeHelper.getSpacing(context);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _groupType = switch (_tabController.index) {
          0 => GroupTypeConstants.public,
          1 => GroupTypeConstants.private,
          2 => GroupTypeConstants.password,
          _ => GroupTypeConstants.public,
        };
      });
    }
  }

  void _createGroup() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _isEmpty = true);
      return;
    }
    if (_groupType == GroupTypeConstants.password &&
        _passwordController.text.trim().isEmpty) {
      setState(() => _isEmpty = true);
      return;
    }

    setState(() {
      _isLoading = true;
      _isEmpty = false;
      _isError = false;
    });

    final guid = 'group_${DateTime.now().millisecondsSinceEpoch}';
    final group = Group(
      guid: guid,
      name: name,
      type: _groupType,
      hasJoined: true,
      password: _groupType == GroupTypeConstants.password
          ? _passwordController.text.trim()
          : null,
    );

    CometChat.createGroup(
      group: group,
      onSuccess: (Group created) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        CometChatGroupEvents.ccGroupCreated(created);
        // Dismiss the bottom sheet first
        Navigator.of(context).pop();
        // Use the UI event to open the conversation — this lets the
        // ResponsiveHomeScreen (desktop) show the group in its middle panel
        // while also working on mobile (HomeScreen listens too).
        CometChatUIEvents.openChat(null, created);
      },
      onError: (CometChatException e) {
        if (!mounted) return;
        debugPrint('Create group failed: ${e.message}');
        setState(() {
          _isLoading = false;
          _isError = true;
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
                    Padding(
                      padding: EdgeInsets.only(bottom: _spacing.padding1 ?? 0),
                      child: _titleText(cc.Translations.of(context).type),
                    ),
                    _buildTabs(),
                    _buildInputs(),
                    _buildErrorBanner(),
                    _buildCreateButton(),
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
        padding: EdgeInsets.only(bottom: _spacing.padding6 ?? 0),
        child: Column(
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: _colorPalette.background2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group_outlined,
                color: _colorPalette.iconHighlight,
                size: 48,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: _spacing.padding2 ?? 0),
              child: Text(
                cc.Translations.of(context).newGroup,
                style: TextStyle(
                  fontFamily: _typography.heading2?.medium?.fontFamily,
                  fontSize: _typography.heading2?.medium?.fontSize,
                  color: _colorPalette.textPrimary,
                  fontWeight: _typography.heading2?.medium?.fontWeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: EdgeInsets.only(bottom: _spacing.padding5 ?? 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_spacing.radius2 ?? 8),
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_spacing.radius2 ?? 8),
            color: _colorPalette.background3,
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerHeight: 1,
            dividerColor: Colors.transparent,
            padding: EdgeInsets.zero,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(_spacing.radius2 ?? 8),
              color: _colorPalette.background1,
              border: Border.all(
                color: _colorPalette.borderLight ?? Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_colorPalette.black ?? Colors.black)
                      .withValues(alpha: 0.04),
                  blurRadius: 3.0,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: (_colorPalette.black ?? Colors.black)
                      .withValues(alpha: 0.12),
                  blurRadius: 8.0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            labelColor: _colorPalette.textHighlight,
            unselectedLabelColor: _colorPalette.textSecondary,
            tabs: [
              Tab(child: Text(cc.Translations.of(context).public)),
              Tab(child: Text(cc.Translations.of(context).private)),
              Tab(child: Text(cc.Translations.of(context).password)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleText(cc.Translations.of(context).name),
        Padding(
          padding: EdgeInsets.only(bottom: _spacing.padding5 ?? 0),
          child: _textField(
            controller: _nameController,
            hint: cc.Translations.of(context).enterTheGroupName,
            capitalize: true,
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _groupType == GroupTypeConstants.password ? 80 : 0,
          curve: Curves.easeInOut,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titleText(cc.Translations.of(context).password),
                Padding(
                  padding: EdgeInsets.only(bottom: _spacing.padding5 ?? 0),
                  child: _textField(
                    controller: _passwordController,
                    hint: cc.Translations.of(context).enterTheGroupPassword,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
                    ? cc.Translations.of(context).createGroupEmptyString
                    : cc.Translations.of(context).somethingWrong,
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

  Widget _buildCreateButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _createGroup,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(_colorPalette.primary),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_spacing.radius2 ?? 8),
          ),
        ),
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(
            vertical: _spacing.padding2 ?? 8,
            horizontal: _spacing.padding5 ?? 20,
          ),
        ),
      ),
      child: Center(
        child: _isLoading
            ? CircularProgressIndicator(color: _colorPalette.white)
            : Text(
                cc.Translations.of(context).createGroup,
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

  Widget _titleText(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: _spacing.padding1 ?? 0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: _typography.caption1?.medium?.fontSize,
          fontWeight: _typography.caption1?.medium?.fontWeight,
          fontFamily: _typography.caption1?.medium?.fontFamily,
          color: _colorPalette.textPrimary,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    bool capitalize = false,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization:
          capitalize ? TextCapitalization.sentences : TextCapitalization.none,
      keyboardAppearance: CometChatThemeHelper.getBrightness(context),
      onTapOutside: (_) {
        if (FocusManager.instance.primaryFocus?.context != null) {
          FocusScope.of(FocusManager.instance.primaryFocus!.context!).unfocus();
        }
      },
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
        hintText: hint,
        hintStyle: TextStyle(
          color: _colorPalette.textTertiary,
          fontSize: _typography.body?.regular?.fontSize,
          fontFamily: _typography.body?.regular?.fontFamily,
          fontWeight: _typography.body?.regular?.fontWeight,
        ),
        filled: true,
        fillColor: _colorPalette.background2,
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

/// Show the Create Group bottom sheet (mobile + web).
Future<void> showCreateGroup({
  required BuildContext context,
  required CometChatColorPalette colorPalette,
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
      height: isWide ? screenSize.height * 0.75 : screenSize.height * 0.5,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const CreateGroupScreen(),
      ),
    ),
  );
}
