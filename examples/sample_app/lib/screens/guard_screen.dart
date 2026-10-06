import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'responsive_home_screen.dart';

/// Guard screen — checks for a cached user session and auto-navigates
/// to HomeScreen or LoginScreen accordingly.
class GuardScreen extends StatefulWidget {
  const GuardScreen({super.key});

  @override
  State<GuardScreen> createState() => _GuardScreenState();
}

class _GuardScreenState extends State<GuardScreen> {
  final ValueNotifier<bool?> _shouldGoHome = ValueNotifier<bool?>(null);
  late CometChatColorPalette _colorPalette;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    if (_initialized) return;
    _initialized = true;
    _checkSession();
  }

  Future<void> _checkSession() async {
    final cachedUser = await CometChatUIKit.getLoggedInUser();
    if (cachedUser != null) {
      // Re-login to refresh the connection
      await CometChatUIKit.login(
        cachedUser.uid,
        // The UI Kit starts call handling itself and calls onSuccess once
        // it is ready (bounded), so there is nothing to start here.
        onSuccess: (_) {
          _shouldGoHome.value = true;
        },
        onError: (e) {
          if (kDebugMode) {
            debugPrint('Guard: re-login failed: ${e.message}');
          }
          _shouldGoHome.value = false;
        },
      );
    } else {
      _shouldGoHome.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: _shouldGoHome,
      builder: (context, value, _) {
        if (value == null) {
          // Still checking — show splash
          return Material(
            color: _colorPalette.background1,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/cometchat_logo_with_text.png',
                    color: _colorPalette.textPrimary,
                    width: 200,
                  ),
                  const SizedBox(height: 32),
                  CircularProgressIndicator(color: _colorPalette.primary),
                ],
              ),
            ),
          );
        }

        // Navigate after frame to avoid build-during-build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final Widget home = kIsWeb
              ? const ResponsiveHomeScreen()
              : const HomeScreen();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => value ? home : const LoginScreen(),
            ),
            (route) => false,
          );
        });
        return const SizedBox();
      },
    );
  }
}
