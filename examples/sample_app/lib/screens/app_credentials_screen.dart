import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sample_app/app_credentials.dart';
import 'package:sample_app/screens/guard_screen.dart';

/// Screen shown when App ID / Auth Key / Region are not configured.
/// Saves credentials to SharedPreferences and re-initialises CometChat.
///
/// This file imports nothing from the app beyond app_credentials.dart and
/// guard_screen.dart: the release pipeline copies it on its own into the
/// generated public sample apps.
class AppCredentialsScreen extends StatefulWidget {
  const AppCredentialsScreen({super.key, this.buildSettings});

  /// Builds the settings the UI Kit is re-initialised with once the new
  /// credentials are saved. Pass the app's own builder (main.dart's), so the
  /// re-init keeps calls, the calling configuration and the hosts: this init
  /// replaces the launch one. Without it, a plain chat-only set-up from the
  /// saved credentials is used.
  final UIKitSettings Function()? buildSettings;

  @override
  State<AppCredentialsScreen> createState() => _AppCredentialsScreenState();
}

class _AppCredentialsScreenState extends State<AppCredentialsScreen> {
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;

  final _appIdController = TextEditingController();
  final _authKeyController = TextEditingController();
  final _appIdFocus = FocusNode();
  final _authKeyFocus = FocusNode();

  String? _selectedRegion;
  bool _isLoading = false;
  String? _errorMessage;

  static const _regions = ['US', 'EU', 'IN'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    _typography = CometChatThemeHelper.getTypography(context);
    _spacing = CometChatThemeHelper.getSpacing(context);
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _authKeyController.dispose();
    _appIdFocus.dispose();
    _authKeyFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _appIdFocus.unfocus();
    _authKeyFocus.unfocus();

    if (_selectedRegion == null ||
        _appIdController.text.trim().isEmpty ||
        _authKeyController.text.trim().isEmpty) {
      setState(() =>
          _errorMessage = 'Please fill in all fields and select a region.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Persist to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cc_app_id', _appIdController.text.trim());
    await prefs.setString('cc_auth_key', _authKeyController.text.trim());
    await prefs.setString('cc_region', _selectedRegion!.toLowerCase());

    // Reload credentials into AppCredentials
    await AppCredentials.loadSavedCredentials();

    if (!mounted) return;

    // Initialize CometChat with the new credentials before navigating, with
    // the same settings as main.dart when it passed its builder. This init
    // replaces the launch one, so leaving enableCalls out here turned call
    // handling off until the next launch.
    final uiKitSettings = widget.buildSettings?.call() ??
        (UIKitSettingsBuilder()
              ..subscriptionType = CometChatSubscriptionType.allUsers
              ..region = AppCredentials.region
              ..autoEstablishSocketConnection = true
              ..appId = AppCredentials.appId
              ..authKey = AppCredentials.authKey)
            .build();

    CometChatUIKit.init(
      uiKitSettings: uiKitSettings,
      onSuccess: (_) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const GuardScreen()),
          (route) => false,
        );
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Init failed: ${error.message}. Check your credentials.';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorPalette.background2,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          _appIdFocus.unfocus();
          _authKeyFocus.unfocus();
        },
        child: Stack(
          children: [
            // Dotted pattern background
            Positioned.fill(
              child: CustomPaint(
                painter: _DottedPatternPainter(
                  dotColor: _colorPalette.borderLight ??
                      Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: _spacing.padding5 ?? 20,
                    vertical: _spacing.padding5 ?? 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // CometChat logo
                      Padding(
                        padding:
                            EdgeInsets.only(bottom: _spacing.padding8 ?? 32),
                        child: Image.asset(
                          'assets/cometchat_logo_with_text.png',
                          color: _colorPalette.textPrimary,
                          height: 40,
                        ),
                      ),
                      // Card container
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Container(
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: ShapeDecoration(
                            color: _colorPalette.background1,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                width: 1,
                                color: _colorPalette.borderDefault ??
                                    const Color(0xFFE8E8E8),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Text(
                                  'App Credentials',
                                  style: TextStyle(
                                    color: _colorPalette.textPrimary,
                                    fontSize:
                                        _typography.heading2?.bold?.fontSize,
                                    fontFamily:
                                        _typography.heading2?.bold?.fontFamily,
                                    fontWeight:
                                        _typography.heading2?.bold?.fontWeight,
                                  ),
                                ),
                              ),
                              SizedBox(height: _spacing.padding5 ?? 20),

                              // Region selector
                              Text(
                                'Region',
                                style: TextStyle(
                                  color: _colorPalette.textPrimary,
                                  fontSize: _typography.body?.medium?.fontSize,
                                  fontFamily:
                                      _typography.body?.medium?.fontFamily,
                                  fontWeight:
                                      _typography.body?.medium?.fontWeight,
                                ),
                              ),
                              SizedBox(height: _spacing.padding2 ?? 8),
                              Row(
                                children: _regions.map((r) {
                                  final selected = _selectedRegion == r;
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: r != _regions.last
                                            ? (_spacing.padding2 ?? 8)
                                            : 0,
                                      ),
                                      child: GestureDetector(
                                        onTap: () =>
                                            setState(() => _selectedRegion = r),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: _spacing.padding2 ?? 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? _colorPalette
                                                    .extendedPrimary50
                                                : _colorPalette.background1,
                                            borderRadius: BorderRadius.circular(
                                                _spacing.radius2 ?? 8),
                                            border: Border.all(
                                              color: selected
                                                  ? (_colorPalette
                                                          .borderHighlight ??
                                                      Colors.transparent)
                                                  : (_colorPalette
                                                          .borderLight ??
                                                      Colors.transparent),
                                              width: 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              r,
                                              style: TextStyle(
                                                color: selected
                                                    ? _colorPalette.primary
                                                    : _colorPalette
                                                        .textSecondary,
                                                fontSize: _typography
                                                    .button?.medium?.fontSize,
                                                fontFamily: _typography
                                                    .button?.medium?.fontFamily,
                                                fontWeight: _typography
                                                    .button?.medium?.fontWeight,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                              SizedBox(height: _spacing.padding5 ?? 20),

                              // App ID field
                              Text(
                                'APP ID',
                                style: TextStyle(
                                  color: _colorPalette.textPrimary,
                                  fontSize:
                                      _typography.caption1?.medium?.fontSize,
                                  fontFamily:
                                      _typography.caption1?.medium?.fontFamily,
                                  fontWeight:
                                      _typography.caption1?.medium?.fontWeight,
                                ),
                              ),
                              SizedBox(height: _spacing.padding1 ?? 4),
                              _buildTextField(
                                controller: _appIdController,
                                focusNode: _appIdFocus,
                                hint: 'Enter the app ID',
                              ),

                              SizedBox(height: _spacing.padding5 ?? 20),

                              // Auth Key field
                              Text(
                                'Auth Keys',
                                style: TextStyle(
                                  color: _colorPalette.textPrimary,
                                  fontSize:
                                      _typography.caption1?.medium?.fontSize,
                                  fontFamily:
                                      _typography.caption1?.medium?.fontFamily,
                                  fontWeight:
                                      _typography.caption1?.medium?.fontWeight,
                                ),
                              ),
                              SizedBox(height: _spacing.padding1 ?? 4),
                              _buildTextField(
                                controller: _authKeyController,
                                focusNode: _authKeyFocus,
                                hint: 'Enter the auth key',
                              ),

                              if (_errorMessage != null) ...[
                                SizedBox(height: _spacing.padding2 ?? 8),
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: _colorPalette.error,
                                    fontSize:
                                        _typography.caption1?.regular?.fontSize,
                                  ),
                                ),
                              ],

                              SizedBox(height: _spacing.padding5 ?? 20),

                              // Continue button
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _save,
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                        _colorPalette.primary),
                                    shape: WidgetStateProperty.all(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            _spacing.radius2 ?? 8),
                                      ),
                                    ),
                                    elevation: WidgetStateProperty.all(0),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    _colorPalette.white ??
                                                        Colors.white),
                                          ),
                                        )
                                      : Text(
                                          'Continue',
                                          style: TextStyle(
                                            color:
                                                _colorPalette.buttonIconColor,
                                            fontSize: _typography
                                                .button?.medium?.fontSize,
                                            fontFamily: _typography
                                                .button?.medium?.fontFamily,
                                            fontWeight: _typography
                                                .button?.medium?.fontWeight,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardAppearance: CometChatThemeHelper.getBrightness(context),
      style: TextStyle(
        color: _colorPalette.textPrimary,
        fontSize: _typography.body?.regular?.fontSize,
        fontFamily: _typography.body?.regular?.fontFamily,
        fontWeight: _typography.body?.regular?.fontWeight,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.all(10),
        hintText: hint,
        hintStyle: TextStyle(
          color: _colorPalette.textTertiary,
          fontSize: _typography.body?.regular?.fontSize,
          fontFamily: _typography.body?.regular?.fontFamily,
          fontWeight: _typography.body?.regular?.fontWeight,
        ),
        filled: true,
        fillColor: _colorPalette.background1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_spacing.radius2 ?? 8),
          borderSide: BorderSide(
            color: _colorPalette.borderLight ?? Colors.transparent,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_spacing.radius2 ?? 8),
          borderSide: BorderSide(
            color: _colorPalette.borderLight ?? Colors.transparent,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_spacing.radius2 ?? 8),
          borderSide: BorderSide(
            color: _colorPalette.primary ?? Colors.purple,
            width: 1.5,
          ),
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
