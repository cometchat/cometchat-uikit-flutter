import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import '../models/user_model.dart';
import '../services/api_services.dart';
import '../utils/app_uikit_settings.dart';
import '../utils/ui_utils.dart';
import 'home_screen.dart';
import 'app_credentials_screen.dart';
import 'responsive_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late CometChatColorPalette colorPalette;
  late CometChatTypography typography;
  late CometChatSpacing spacing;

  Future<List<SampleUserModel>>? _futureUsers;
  final TextEditingController _uidController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<SampleUserModel?> _selectedUserNotifier =
      ValueNotifier<SampleUserModel?>(null);

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _futureUsers = ApiServices.fetchUsers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    colorPalette = CometChatThemeHelper.getColorPalette(context);
    typography = CometChatThemeHelper.getTypography(context);
    spacing = CometChatThemeHelper.getSpacing(context);
  }

  @override
  void dispose() {
    _selectedUserNotifier.dispose();
    _uidController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loginUser(String userId) async {
    setState(() => _isLoading = true);

    try {
      User? existingUser = await CometChatUIKit.getLoggedInUser();
      if (existingUser != null && existingUser.uid != userId) {
        // Through the UI Kit, not CometChat.logout: its logout also stops
        // call handling for the previous user and logs the Calls SDK out.
        await CometChatUIKit.logout(
          onSuccess: (_) => debugPrint("Logout Successful"),
          onError: (_) => debugPrint("Logout failed"),
        );
      } else if (existingUser != null && existingUser.uid == userId) {
        _navigateToHome();
        return;
      }

      // With enableCalls, onSuccess comes once the UI Kit has set up the
      // Calls SDK for this user, within its own time limit.
      await CometChatUIKit.login(userId, onSuccess: (User loggedInUser) {
        // Never log the User object itself: its toString() carries the
        // live authToken and a signed jwt, and CI copies the raw test log
        // into a published gallery. uid and name are enough to debug a
        // login.
        debugPrint("Login Successful: ${loggedInUser.uid} (${loggedInUser.name})");
        if (mounted) _navigateToHome();
      }, onError: (CometChatException e) {
        debugPrint("Login failed: ${e.message}");
        if (mounted) {
          setState(() => _isLoading = false);
          showErrorSnackBar(
              context, "Unable to login.", typography, colorPalette);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackBar(
            context, "Unable to login.", typography, colorPalette);
      }
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            kIsWeb ? const ResponsiveHomeScreen() : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorPalette.background2,
      body: GestureDetector(
        onTap: () => removeFocus(context, _focusNode),
        child: Stack(
          children: [
            // Dotted pattern background
            Positioned.fill(child: _buildDottedBackground()),
            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.padding5 ?? 20,
                    vertical: spacing.padding5 ?? 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // CometChat logo
                      Padding(
                        padding:
                            EdgeInsets.only(bottom: spacing.padding8 ?? 32),
                        child: Image.asset(
                          'assets/cometchat_logo_with_text.png',
                          color: colorPalette.textPrimary,
                        ),
                      ),
                      // Card container
                      _buildLoginCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dotted pattern background
  Widget _buildDottedBackground() {
    return CustomPaint(
      painter: _DottedPatternPainter(
        dotColor:
            colorPalette.borderLight ?? Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  /// Main login card with border, shadow, and rounded corners
  Widget _buildLoginCard() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: colorPalette.background1,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 1,
              color: colorPalette.borderDefault ?? const Color(0xFFE8E8E8),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x07101828),
              blurRadius: 6,
              offset: Offset(0, 4),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Color(0x14101828),
              blurRadius: 16,
              offset: Offset(0, 12),
              spreadRadius: -4,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 20,
          children: [
            // Title
            Center(
              child: Text(
                "Sign in to cometchat",
                style: TextStyle(
                  color: colorPalette.textPrimary,
                  fontSize: typography.heading2?.bold?.fontSize,
                  fontFamily: typography.heading2?.bold?.fontFamily,
                  fontWeight: typography.heading2?.bold?.fontWeight,
                ),
              ),
            ),
            // Subtitle + User grid
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text(
                  "Using our sample users",
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: colorPalette.textSecondary,
                    fontSize: typography.body?.medium?.fontSize,
                    fontFamily: typography.body?.medium?.fontFamily,
                    fontWeight: typography.body?.medium?.fontWeight,
                  ),
                ),
                _buildUserGrid(),
              ],
            ),
            // Or divider
            _buildOrDivider(),
            // UID field + Button + Bottom text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 20,
              children: [
                _buildUidField(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 20,
                  children: [
                    _buildContinueButton(),
                    _buildBottomText(),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserGrid() {
    return FutureBuilder<List<SampleUserModel>>(
      future: _futureUsers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CometChatShimmerEffect(
            colorPalette: colorPalette,
            child: GridView.builder(
              itemCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                return Container(
                  padding: EdgeInsets.all(spacing.padding2 ?? 8),
                  decoration: BoxDecoration(
                    color: colorPalette.background1,
                    borderRadius: BorderRadius.circular(spacing.radius2 ?? 8),
                  ),
                );
              },
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: spacing.padding2 ?? 8,
                mainAxisSpacing: spacing.padding2 ?? 8,
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}, login using UID',
              style: TextStyle(
                color: colorPalette.textPrimary,
                fontSize: typography.body?.bold?.fontSize,
                fontFamily: typography.body?.bold?.fontFamily,
                fontWeight: typography.body?.bold?.fontWeight,
              ),
            ),
          );
        }

        final users = snapshot.data ?? [];
        return ValueListenableBuilder<SampleUserModel?>(
          valueListenable: _selectedUserNotifier,
          builder: (context, selectedUser, _) {
            return GridView.builder(
              itemCount: users.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final user = users[index];
                final isSelected = selectedUser == user;
                return GestureDetector(
                  onTap: () {
                    removeFocus(context, _focusNode);
                    _selectedUserNotifier.value = user;
                  },
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorPalette.extendedPrimary50
                              : colorPalette.background1,
                          borderRadius:
                              BorderRadius.circular(spacing.radius2 ?? 8),
                          border: Border.all(
                            color: isSelected
                                ? (colorPalette.borderHighlight ??
                                    Colors.transparent)
                                : (colorPalette.borderLight ??
                                    Colors.transparent),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(spacing.padding1 ?? 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                    bottom: spacing.padding2 ?? 8),
                                child: CometChatAvatar(
                                  name: user.username,
                                  image: user.imageURL,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  user.username,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorPalette.textPrimary,
                                    fontSize: typography.body?.medium?.fontSize,
                                    fontFamily:
                                        typography.body?.medium?.fontFamily,
                                    fontWeight:
                                        typography.body?.medium?.fontWeight,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      top: spacing.padding1 ?? 4),
                                  child: Text(
                                    user.userId,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colorPalette.textSecondary,
                                      fontSize: typography
                                          .caption1?.regular?.fontSize,
                                      fontFamily: typography
                                          .caption1?.regular?.fontFamily,
                                      fontWeight: typography
                                          .caption1?.regular?.fontWeight,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.all(spacing.padding ?? 4),
                            decoration: BoxDecoration(
                              color: colorPalette.iconHighlight,
                              borderRadius: BorderRadius.only(
                                bottomLeft:
                                    Radius.circular(spacing.radius2 ?? 8),
                                topRight: Radius.circular(spacing.radius2 ?? 8),
                              ),
                            ),
                            child: Center(
                              child: Icon(Icons.check,
                                  color: colorPalette.white, size: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: spacing.padding2 ?? 8,
                mainAxisSpacing: spacing.padding2 ?? 8,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Divider(
            color: colorPalette.borderDefault ?? const Color(0xFFE8E8E8),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            "Or",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorPalette.textTertiary ?? const Color(0xFFA1A1A1),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.20,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: colorPalette.borderDefault ?? const Color(0xFFE8E8E8),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildUidField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            "UID",
            textAlign: TextAlign.start,
            style: TextStyle(
              color: colorPalette.textPrimary ?? const Color(0xFF141414),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.20,
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: TextFormField(
            controller: _uidController,
            focusNode: _focusNode,
            keyboardAppearance: CometChatThemeHelper.getBrightness(context),
            onChanged: (value) {
              if (value.isNotEmpty) _selectedUserNotifier.value = null;
            },
            style: TextStyle(
              color: colorPalette.textPrimary,
              fontSize: 14,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w400,
              height: 1.20,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  width: 1,
                  color: colorPalette.borderLight ?? const Color(0xFFF5F5F5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  width: 1,
                  color: colorPalette.borderLight ?? const Color(0xFFF5F5F5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  width: 1.5,
                  color: colorPalette.primary ?? const Color(0xFF6852D6),
                ),
              ),
              hintText: "Enter the UID",
              hintStyle: TextStyle(
                color: colorPalette.textTertiary ?? const Color(0xFFA1A1A1),
                fontSize: 14,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w400,
                height: 1.20,
              ),
              filled: true,
              fillColor: colorPalette.background2 ?? const Color(0xFFFAFAFA),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () {
                removeFocus(context, _focusNode);
                if (_selectedUserNotifier.value == null &&
                    _uidController.text.isEmpty) {
                  showErrorSnackBar(context, "Please enter a valid UID",
                      typography, colorPalette);
                  return;
                }
                if (_selectedUserNotifier.value != null &&
                    _selectedUserNotifier.value!.userId.isNotEmpty) {
                  _loginUser(_selectedUserNotifier.value!.userId);
                } else if (_uidController.text.isNotEmpty) {
                  _loginUser(_uidController.text);
                }
              },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(colorPalette.primary),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(spacing.radius2 ?? 8),
            ),
          ),
          elevation: WidgetStateProperty.all(0),
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      colorPalette.white ?? Colors.white),
                ),
              )
            : Text(
                "Continue",
                style: TextStyle(
                  color: colorPalette.buttonIconColor,
                  fontSize: typography.button?.medium?.fontSize,
                  fontFamily: typography.button?.medium?.fontFamily,
                  fontWeight: typography.button?.medium?.fontWeight,
                ),
              ),
      ),
    );
  }

  /// "Don't have an UID? App Credentials" bottom text
  Widget _buildBottomText() {
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AppCredentialsScreen(
                buildSettings: buildAppUIKitSettings,
              ),
            ),
          );
        },
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "Change ",
                style: TextStyle(
                  color: colorPalette.textSecondary,
                  fontSize: typography.body?.regular?.fontSize,
                  fontFamily: typography.body?.regular?.fontFamily,
                  fontWeight: typography.body?.regular?.fontWeight,
                ),
              ),
              TextSpan(
                text: "App Credentials",
                style: TextStyle(
                  color: colorPalette.primary,
                  fontSize: typography.body?.medium?.fontSize,
                  fontFamily: typography.body?.medium?.fontFamily,
                  fontWeight: typography.body?.medium?.fontWeight,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Custom painter for dotted background pattern
class _DottedPatternPainter extends CustomPainter {
  final Color dotColor;

  _DottedPatternPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const double spacing = 24.0;
    const double radius = 1.2;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedPatternPainter oldDelegate) {
    return oldDelegate.dotColor != dotColor;
  }
}
