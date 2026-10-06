import "../../../clean_architecture.dart";
import 'package:flutter/material.dart';

///[CometChatThemeHelper] is a class that gives the styling to the text displayed in the buttons
class CometChatThemeHelper {
  /// Get the color palette from the current theme or return the default color palette
  static CometChatColorPalette getColorPalette(BuildContext context) {
    return CometChatColorPalette(
      //Primary Colour
      primary: _getColorPrimary(context),
      //Extended Primary Color
      extendedPrimary50: _getColorExtendedPrimary(context).shade50,
      extendedPrimary100: _getColorExtendedPrimary(context).shade100,
      extendedPrimary200: _getColorExtendedPrimary(context).shade200,
      extendedPrimary300: _getColorExtendedPrimary(context).shade300,
      extendedPrimary400: _getColorExtendedPrimary(context).shade400,
      extendedPrimary500: _getColorExtendedPrimary(context).shade500,
      extendedPrimary600: _getColorExtendedPrimary(context).shade600,
      extendedPrimary700: _getColorExtendedPrimary(context).shade700,
      extendedPrimary800: _getColorExtendedPrimary(context).shade800,
      extendedPrimary900: _getColorExtendedPrimary(context).shade900,
      //Neutral Colors
      neutral50: _getColorNeutral(context).shade50,
      neutral100: _getColorNeutral(context).shade100,
      neutral200: _getColorNeutral(context).shade200,
      neutral300: _getColorNeutral(context).shade300,
      neutral400: _getColorNeutral(context).shade400,
      neutral500: _getColorNeutral(context).shade500,
      neutral600: _getColorNeutral(context).shade600,
      neutral700: _getColorNeutral(context).shade700,
      neutral800: _getColorNeutral(context).shade800,
      neutral900: _getColorNeutral(context).shade900,
      //Alert Color
      info: _getColorInfo(context),
      warning: _getColorWarning(context),
      error: _getColorError(context),
      success: _getColorSuccess(context),
      error100: _getColorError100(context),
      //Background Color
      background1: _getColorBackground1(context),
      background2: _getColorBackground2(context),
      background3: _getColorBackground3(context),
      background4: _getColorBackground4(context),
      //Text Color
      textPrimary: _getColorTextPrimary(context),
      textSecondary: _getColorTextSecondary(context),
      textTertiary: _getColorTextTertiary(context),
      textDisabled: _getColorTextDisabled(context),
      textWhite: _getColorTextWhite(context),
      textHighlight: _getColorTextHighlight(context),
      //Border Color
      borderLight: _getColorBorderLight(context),
      borderDefault: _getColorBorderDefault(context),
      borderDark: _getColorBorderDark(context),
      borderHighlight: _getColorBorderHighlight(context),
      //ICON Color
      iconPrimary: _getColorIconPrimary(context),
      iconSecondary: _getColorIconSecondary(context),
      iconTertiary: _getColorIconTertiary(context),
      iconWhite: _getColorIconWhite(context),
      iconHighlight: _getColorIconHighlight(context),
      //button Color
      buttonBackground: _getColorButtonBackground(context),
      secondaryButtonBackground: _getColorSecondaryButtonBackground(context),
      buttonIconColor: _getColorButtonIconColor(context),
      buttonText: _getColorButtonText(context),
      secondaryButtonIcon: _getColorSecondaryButtonIcon(context),
      secondaryButtonText: _getColorSecondaryButtonText(context),
      white: _getColor(context, (cp) => cp?.white, Colors.white),
      black: _getColor(context, (cp) => cp?.black, Colors.black),
      messageSeen: _getColor(
        context,
        (cp) => cp?.messageSeen,
        const Color(0XFF56E8A7),
      ),
    );
  }

  /// Primary colors
  static Color _getColorPrimary(BuildContext context) {
    final mBrightness = getBrightness(context);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final colorPalette = theme.extension<CometChatColorPalette>();

    // First preference: Use the color from the CometChatColorPalette extension if available
    if (colorPalette?.primary != null) {
      return colorPalette!.primary!;
    }

    // Second preference: Use the theme's primary color if available
    if (primaryColor != theme.colorScheme.primary ||
        primaryColor != theme.colorScheme.primary) {
      return primaryColor;
    }

    // Fallback to default colors based on brightness (light or dark mode)
    return mBrightness == Brightness.light
        ? const Color(0xFF6852D6) // Default light mode color
        : const Color(0xFF604CC3); // Default dark mode color
  }

  /// Extended Primary colors
  static MaterialColor _getColorExtendedPrimary(
    BuildContext context, {
    Color? blendColor,
  }) {
    final mBrightness = getBrightness(context);

    final primaryColor = _getColorPrimary(context);
    final ccColorPalette = Theme.of(context).extension<CometChatColorPalette>();

    final blendColorsPercentage = mBrightness == Brightness.light
        ? [0.96, 0.88, 0.77, 0.66, 0.55, 0.44, 0.33, 0.22, 0.11, 0.11]
        : [0.80, 0.72, 0.64, 0.56, 0.48, 0.40, 0.32, 0.24, 0.16, 0.08];
    blendColor ??= mBrightness == Brightness.light
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);

    MaterialColor extendedPrimaryColorShades =
        MaterialColor(primaryColor.toARGB32(), <int, Color>{
          50:
              ccColorPalette?.extendedPrimary50 ??
              CometChatColorHelper.blendColors(
                primaryColor,
                blendColor,
                blendColorsPercentage[0],
              ),
          100:
              ccColorPalette?.extendedPrimary100 ??
              CometChatColorHelper.blendColors(
                primaryColor,
                blendColor,
                blendColorsPercentage[1],
              ),
          200:
              ccColorPalette?.extendedPrimary200 ??
              CometChatColorHelper.blendColors(
                primaryColor,
                blendColor,
                blendColorsPercentage[2],
              ),
          300:
              ccColorPalette?.extendedPrimary300 ??
              CometChatColorHelper.blendColors(
                primaryColor,
                blendColor,
                blendColorsPercentage[3],
              ),
          400:
              ccColorPalette?.extendedPrimary400 ??
              CometChatColorHelper.blendColors(
                primaryColor,
                blendColor,
                blendColorsPercentage[4],
              ),
          500:
              ccColorPalette?.extendedPrimary500 ??
              CometChatColorHelper.blendColors(
                primaryColor,
                blendColor,
                blendColorsPercentage[5],
              ),
          600:
              ccColorPalette?.extendedPrimary600 ??
              CometChatColorHelper.blendColors(
                primaryColor,
                blendColor,
                blendColorsPercentage[6],
              ),
          700:
              ccColorPalette?.extendedPrimary700 ??
              CometChatColorHelper.blendColors(
                primaryColor,
                blendColor,
                blendColorsPercentage[7],
              ),
          800:
              ccColorPalette?.extendedPrimary800 ??
              CometChatColorHelper.blendColors(
                primaryColor,
                blendColor,
                blendColorsPercentage[8],
              ),
          900:
              ccColorPalette?.extendedPrimary900 ??
              CometChatColorHelper.blendColors(
                primaryColor,
                blendColor,
                blendColorsPercentage[9],
              ),
        });

    return extendedPrimaryColorShades;
  }

  /// Neutral colors
  static MaterialColor _getColorNeutral(BuildContext context) {
    final mBrightness = getBrightness(context);
    final ccColorPalette = Theme.of(context).extension<CometChatColorPalette>();
    const neutral = Color(0xFF141414);

    MaterialColor neutralColorShades =
        MaterialColor(neutral.toARGB32(), <int, Color>{
          50:
              ccColorPalette?.neutral50 ??
              (mBrightness == Brightness.light
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFF141414)),
          100:
              ccColorPalette?.neutral100 ??
              (mBrightness == Brightness.light
                  ? const Color(0xFFFAFAFA)
                  : const Color(0xFF1A1A1A)),
          200:
              ccColorPalette?.neutral200 ??
              (mBrightness == Brightness.light
                  ? const Color(0xFFF5F5F5)
                  : const Color(0xFF272727)),
          300:
              ccColorPalette?.neutral300 ??
              (mBrightness == Brightness.light
                  ? const Color(0xFFE8E8E8)
                  : const Color(0xFF383838)),
          400:
              ccColorPalette?.neutral400 ??
              (mBrightness == Brightness.light
                  ? const Color(0xFFDCDCDC)
                  : const Color(0xFF4C4C4C)),
          500:
              ccColorPalette?.neutral500 ??
              (mBrightness == Brightness.light
                  ? const Color(0xFFA1A1A1)
                  : const Color(0xFF858585)),
          600:
              ccColorPalette?.neutral600 ??
              (mBrightness == Brightness.light
                  ? const Color(0xFF727272)
                  : const Color(0xFF989898)),
          700:
              ccColorPalette?.neutral700 ??
              (mBrightness == Brightness.light
                  ? const Color(0xFF5B5B5B)
                  : const Color(0xFFA8A8A8)),
          800:
              ccColorPalette?.neutral800 ??
              (mBrightness == Brightness.light
                  ? const Color(0xFF434343)
                  : const Color(0xFFC8C8C8)),
          900:
              ccColorPalette?.neutral900 ??
              (mBrightness == Brightness.light
                  ? const Color(0xFF141414)
                  : const Color(0xFFFFFFFF)),
        });

    return neutralColorShades;
  }

  /// Alert colors
  /// Info, Warning, Error, Success
  static Color _getColorInfo(BuildContext context) => _getColor(
    context,
    (cc) => cc?.info,
    _getAlertColors(context, const Color(0xFF0B7BEA), const Color(0xFF0D66BF)),
  );

  static Color _getColorWarning(BuildContext context) => _getColor(
    context,
    (cc) => cc?.warning,
    _getAlertColors(context, const Color(0xFFFFAB00), const Color(0xFFD08D04)),
  );

  static Color _getColorError(BuildContext context) => _getColor(
    context,
    (cc) => cc?.error,
    _getAlertColors(context, const Color(0xFFF44649), const Color(0xFFC73C3E)),
  );

  static Color _getColorSuccess(BuildContext context) => _getColor(
    context,
    (cc) => cc?.success,
    _getAlertColors(context, const Color(0xFF09C26F), const Color(0xFF0B9F5D)),
  );

  static Color _getColorError100(BuildContext context) => _getColor(
    context,
    (cc) => cc?.error100,
    _getAlertColors(context, const Color(0xFFF9EAEF), const Color(0xFF3A0C05)),
  );

  /// Background colors
  static Color _getColorBackground1(BuildContext context) => _getColor(
    context,
    (cc) => cc?.background1,
    _getColorNeutral(context).shade50,
  );

  static Color _getColorBackground2(BuildContext context) => _getColor(
    context,
    (cc) => cc?.background2,
    _getColorNeutral(context).shade100,
  );

  static Color _getColorBackground3(BuildContext context) => _getColor(
    context,
    (cc) => cc?.background3,
    _getColorNeutral(context).shade200,
  );

  static Color _getColorBackground4(BuildContext context) => _getColor(
    context,
    (cc) => cc?.background4,
    _getColorNeutral(context).shade300,
  );

  /// Border colors
  static Color _getColorBorderLight(BuildContext context) => _getColor(
    context,
    (cc) => cc?.borderLight,
    _getColorNeutral(context).shade200,
  );

  static Color _getColorBorderDefault(BuildContext context) => _getColor(
    context,
    (cc) => cc?.borderDefault,
    _getColorNeutral(context).shade300,
  );

  static Color _getColorBorderDark(BuildContext context) => _getColor(
    context,
    (cc) => cc?.borderDark,
    _getColorNeutral(context).shade400,
  );

  static Color _getColorBorderHighlight(BuildContext context) => _getColor(
    context,
    (cc) => cc?.borderHighlight,
    _getColorPrimary(context),
  );

  /// Text colors
  static Color _getColorTextPrimary(BuildContext context) => _getColor(
    context,
    (cc) => cc?.textPrimary,
    _getColorNeutral(context).shade900,
  );

  static Color _getColorTextSecondary(BuildContext context) => _getColor(
    context,
    (cc) => cc?.textSecondary,
    _getColorNeutral(context).shade600,
  );

  static Color _getColorTextTertiary(BuildContext context) => _getColor(
    context,
    (cc) => cc?.textTertiary,
    _getColorNeutral(context).shade500,
  );

  static Color _getColorTextDisabled(BuildContext context) => _getColor(
    context,
    (cc) => cc?.textDisabled,
    _getColorNeutral(context).shade400,
  );

  static Color _getColorTextWhite(BuildContext context) => _getColor(
    context,
    (cc) => cc?.textWhite,
    _getColorNeutral(context).shade50,
  );

  static Color _getColorTextHighlight(BuildContext context) =>
      _getColor(context, (cc) => cc?.textHighlight, _getColorPrimary(context));

  /// Icon colors
  static Color _getColorIconPrimary(BuildContext context) => _getColor(
    context,
    (cc) => cc?.iconPrimary,
    _getColorNeutral(context).shade900,
  );

  static Color _getColorIconSecondary(BuildContext context) => _getColor(
    context,
    (cc) => cc?.iconSecondary,
    _getColorNeutral(context).shade500,
  );

  static Color _getColorIconTertiary(BuildContext context) => _getColor(
    context,
    (cc) => cc?.iconTertiary,
    _getColorNeutral(context).shade400,
  );

  static Color _getColorIconWhite(BuildContext context) => _getColor(
    context,
    (cc) => cc?.iconWhite,
    _getColorNeutral(context).shade50,
  );

  static Color _getColorIconHighlight(BuildContext context) =>
      _getColor(context, (cc) => cc?.iconHighlight, _getColorPrimary(context));

  /// Button Color
  static Color _getColorButtonBackground(BuildContext context) => _getColor(
    context,
    (cc) => cc?.buttonBackground,
    _getColorPrimary(context),
  );

  static Color _getColorSecondaryButtonBackground(BuildContext context) =>
      _getColor(
        context,
        (cc) => cc?.secondaryButtonBackground,
        _getColorNeutral(context).shade900,
      );

  static Color _getColorButtonIconColor(BuildContext context) =>
      _getColor(context, (cc) => cc?.buttonIconColor, const Color(0XFFFFFFFF));

  static Color _getColorButtonText(BuildContext context) =>
      _getColor(context, (cc) => cc?.buttonText, const Color(0XFFFFFFFF));

  static Color _getColorSecondaryButtonIcon(BuildContext context) => _getColor(
    context,
    (cc) => cc?.secondaryButtonIcon,
    _getColorNeutral(context).shade900,
  );

  static Color _getColorSecondaryButtonText(BuildContext context) => _getColor(
    context,
    (cc) => cc?.secondaryButtonText,
    _getColorNeutral(context).shade900,
  );

  /// Private helper function to get color from CCColorPalette
  static Color _getColor(
    BuildContext context,
    Color? Function(CometChatColorPalette?) colorFunction,
    Color defaultColor,
  ) {
    final ccColorPalette = _getThemeExtensionData<CometChatColorPalette>(
      context,
    );
    return colorFunction(ccColorPalette) ?? defaultColor;
  }

  /// Get the theme extension data from the current theme
  static T? _getThemeExtensionData<T extends ThemeExtension<T>>(
    BuildContext? context,
  ) {
    return context == null ? null : Theme.of(context).extension<T>();
  }

  /// Get the theme extension from the current theme or return the default theme
  static T getTheme<T extends ThemeExtension<T>>({
    required BuildContext context,
    required T Function(BuildContext context) defaultTheme,
  }) {
    try {
      // Retrieve the theme extension from the current theme, or use the `of` method to get a default instance
      final T themeData =
          (Theme.of(context).extension<T>() ?? defaultTheme(context));
      return themeData;
    } catch (e) {
      throw ArgumentError(
        '$T is not a valid ThemeExtension',
        'ThemeExtension not found',
      );
    }
  }

  /// Get the default spacing values used in the UI components
  static CometChatSpacing getSpacing(BuildContext context) {
    CometChatSpacing? themeSpacing = Theme.of(
      context,
    ).extension<CometChatSpacing>();
    CometChatSpacing defaultSpacing = CometChatSpacing();
    return defaultSpacing.merge(themeSpacing);
  }

  static Brightness getBrightness(BuildContext context) {
    if (CometChatThemeMode.mode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness;
    } else {
      if (CometChatThemeMode.mode == ThemeMode.light) {
        return Brightness.light;
      } else {
        return Brightness.dark;
      }
    }
  }

  /// Get the default text styles used in the UI components
  static CometChatTypography getTypography(BuildContext context) {
    // Each `of(context)` already merges its own CometChatTextStyle* extension.
    // A CometChatTypography supplied wholesale was still being ignored, so
    // merge it over the resolved defaults here — `merge` lets the argument win.
    final defaults = CometChatTypography(
      heading1: CometChatTextStyleHeading1.of(context),
      heading2: CometChatTextStyleHeading2.of(context),
      heading3: CometChatTextStyleHeading3.of(context),
      heading4: CometChatTextStyleHeading4.of(context),
      body: CometChatTextStyleBody.of(context),
      caption1: CometChatTextStyleCaption1.of(context),
      caption2: CometChatTextStyleCaption2.of(context),
      button: CometChatTextStyleButton.of(context),
      link: CometChatTextStyleLink.of(context),
      title: CometChatTextStyleTitle.of(context),
    );
    return defaults.merge(_getThemeExtensionData<CometChatTypography>(context));
  }

  static Color _getAlertColors(
    BuildContext context,
    Color lightColor,
    Color darkColor,
  ) {
    final mBrightness = getBrightness(context);
    return mBrightness == Brightness.light ? lightColor : darkColor;
  }
}
