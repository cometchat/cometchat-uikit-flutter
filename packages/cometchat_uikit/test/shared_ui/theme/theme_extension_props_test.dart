/// Render-verified prop matrix for the theme extensions — Track 3 PROP1/PROP2
/// (ENG-38949).
///
/// Every extension is constructed *inside* the `pumpWidget` call and supplied
/// through `ThemeData.extensions`, then resolved back through the real
/// `CometChatThemeHelper` path and asserted on a rendered widget. That is the
/// path an integrator actually uses, and it is where the merge bugs live.
///
///   flutter test test/shared_ui/theme/theme_extension_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Distinct, recognisable colour per index so a cross-wired property fails.
Color _c(int i) => Color(0xFF000000 | (i * 0x000509) | 0x00101010);
double _d(int i) => 3.0 + i;

void main() {
  group('CometChatColorPalette', () {
    testWidgets(
      'every property supplied through the theme extension reaches the resolved palette',
      (tester) async {
        late CometChatColorPalette resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                CometChatColorPalette(
                  background1: _c(1),
                  background2: _c(2),
                  background3: _c(3),
                  background4: _c(4),
                  black: _c(5),
                  borderDark: _c(6),
                  borderDefault: _c(7),
                  borderHighlight: _c(8),
                  borderLight: _c(9),
                  buttonBackground: _c(10),
                  buttonIconColor: _c(11),
                  buttonText: _c(12),
                  error: _c(13),
                  error100: _c(14),
                  extendedPrimary100: _c(15),
                  extendedPrimary200: _c(16),
                  extendedPrimary300: _c(17),
                  extendedPrimary400: _c(18),
                  extendedPrimary50: _c(19),
                  extendedPrimary500: _c(20),
                  extendedPrimary600: _c(21),
                  extendedPrimary700: _c(22),
                  extendedPrimary800: _c(23),
                  extendedPrimary900: _c(24),
                  iconHighlight: _c(25),
                  iconPrimary: _c(26),
                  iconSecondary: _c(27),
                  iconTertiary: _c(28),
                  iconWhite: _c(29),
                  info: _c(30),
                  messageSeen: _c(31),
                  neutral100: _c(32),
                  neutral200: _c(33),
                  neutral300: _c(34),
                  neutral400: _c(35),
                  neutral50: _c(36),
                  neutral500: _c(37),
                  neutral600: _c(38),
                  neutral700: _c(39),
                  neutral800: _c(40),
                  neutral900: _c(41),
                  primary: _c(42),
                  secondaryButtonBackground: _c(43),
                  secondaryButtonIcon: _c(44),
                  secondaryButtonText: _c(45),
                  shimmerBackground: _c(46),
                  shimmerGradient: const LinearGradient(
                    colors: [Color(0xFF102030), Color(0xFF405060)],
                  ),
                  success: _c(48),
                  textDisabled: _c(49),
                  textHighlight: _c(50),
                  textPrimary: _c(51),
                  textSecondary: _c(52),
                  textTertiary: _c(53),
                  textWhite: _c(54),
                  transparent: _c(55),
                  warning: _c(56),
                  white: _c(57),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatThemeHelper.getColorPalette(context);
                return ListView(
                  children: [
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.background1!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.background2!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.background3!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.background4!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.black!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.borderDark!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.borderDefault!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.borderHighlight!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.borderLight!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.buttonBackground!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.buttonIconColor!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.buttonText!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.error!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.error100!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.extendedPrimary100!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.extendedPrimary200!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.extendedPrimary300!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.extendedPrimary400!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.extendedPrimary50!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.extendedPrimary500!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.extendedPrimary600!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.extendedPrimary700!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.extendedPrimary800!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.extendedPrimary900!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.iconHighlight!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.iconPrimary!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.iconSecondary!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.iconTertiary!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.iconWhite!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.info!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.messageSeen!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.neutral100!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.neutral200!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.neutral300!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.neutral400!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.neutral50!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.neutral500!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.neutral600!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.neutral700!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.neutral800!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.neutral900!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.primary!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(
                        color: resolved.secondaryButtonBackground!,
                      ),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.secondaryButtonIcon!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.secondaryButtonText!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.success!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.textDisabled!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.textHighlight!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.textPrimary!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.textSecondary!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.textTertiary!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.textWhite!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.warning!),
                    ),
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: resolved.white!),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        // Every assertion below reads `resolved` directly, which is a field
        // read, not a render. Without this set the whole ColoredBox tree above
        // could fail to build and the test would still pass — so each token is
        // checked twice: that it resolved to the expected colour, and that the
        // same colour reached a painted widget.
        final painted = tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .map((b) => b.color)
            .toSet();
        void expectToken(
          Color? actual,
          Color expected, {
          required String reason,
        }) {
          expect(actual, expected, reason: reason);
          expect(painted, contains(expected), reason: '$reason not painted');
        }

        expectToken(resolved.background1, _c(1), reason: 'background1');
        expectToken(resolved.background2, _c(2), reason: 'background2');
        expectToken(resolved.background3, _c(3), reason: 'background3');
        expectToken(resolved.background4, _c(4), reason: 'background4');
        expectToken(resolved.black, _c(5), reason: 'black');
        expectToken(resolved.borderDark, _c(6), reason: 'borderDark');
        expectToken(resolved.borderDefault, _c(7), reason: 'borderDefault');
        expectToken(resolved.borderHighlight, _c(8), reason: 'borderHighlight');
        expectToken(resolved.borderLight, _c(9), reason: 'borderLight');
        expectToken(
          resolved.buttonBackground,
          _c(10),
          reason: 'buttonBackground',
        );
        expectToken(
          resolved.buttonIconColor,
          _c(11),
          reason: 'buttonIconColor',
        );
        expectToken(resolved.buttonText, _c(12), reason: 'buttonText');
        expectToken(resolved.error, _c(13), reason: 'error');
        expectToken(resolved.error100, _c(14), reason: 'error100');
        expectToken(
          resolved.extendedPrimary100,
          _c(15),
          reason: 'extendedPrimary100',
        );
        expectToken(
          resolved.extendedPrimary200,
          _c(16),
          reason: 'extendedPrimary200',
        );
        expectToken(
          resolved.extendedPrimary300,
          _c(17),
          reason: 'extendedPrimary300',
        );
        expectToken(
          resolved.extendedPrimary400,
          _c(18),
          reason: 'extendedPrimary400',
        );
        expectToken(
          resolved.extendedPrimary50,
          _c(19),
          reason: 'extendedPrimary50',
        );
        expectToken(
          resolved.extendedPrimary500,
          _c(20),
          reason: 'extendedPrimary500',
        );
        expectToken(
          resolved.extendedPrimary600,
          _c(21),
          reason: 'extendedPrimary600',
        );
        expectToken(
          resolved.extendedPrimary700,
          _c(22),
          reason: 'extendedPrimary700',
        );
        expectToken(
          resolved.extendedPrimary800,
          _c(23),
          reason: 'extendedPrimary800',
        );
        expectToken(
          resolved.extendedPrimary900,
          _c(24),
          reason: 'extendedPrimary900',
        );
        expectToken(resolved.iconHighlight, _c(25), reason: 'iconHighlight');
        expectToken(resolved.iconPrimary, _c(26), reason: 'iconPrimary');
        expectToken(resolved.iconSecondary, _c(27), reason: 'iconSecondary');
        expectToken(resolved.iconTertiary, _c(28), reason: 'iconTertiary');
        expectToken(resolved.iconWhite, _c(29), reason: 'iconWhite');
        expectToken(resolved.info, _c(30), reason: 'info');
        expectToken(resolved.messageSeen, _c(31), reason: 'messageSeen');
        expectToken(resolved.neutral100, _c(32), reason: 'neutral100');
        expectToken(resolved.neutral200, _c(33), reason: 'neutral200');
        expectToken(resolved.neutral300, _c(34), reason: 'neutral300');
        expectToken(resolved.neutral400, _c(35), reason: 'neutral400');
        expectToken(resolved.neutral50, _c(36), reason: 'neutral50');
        expectToken(resolved.neutral500, _c(37), reason: 'neutral500');
        expectToken(resolved.neutral600, _c(38), reason: 'neutral600');
        expectToken(resolved.neutral700, _c(39), reason: 'neutral700');
        expectToken(resolved.neutral800, _c(40), reason: 'neutral800');
        expectToken(resolved.neutral900, _c(41), reason: 'neutral900');
        expectToken(resolved.primary, _c(42), reason: 'primary');
        expectToken(
          resolved.secondaryButtonBackground,
          _c(43),
          reason: 'secondaryButtonBackground',
        );
        expectToken(
          resolved.secondaryButtonIcon,
          _c(44),
          reason: 'secondaryButtonIcon',
        );
        expectToken(
          resolved.secondaryButtonText,
          _c(45),
          reason: 'secondaryButtonText',
        );
        expectToken(resolved.success, _c(48), reason: 'success');
        expectToken(resolved.textDisabled, _c(49), reason: 'textDisabled');
        expectToken(resolved.textHighlight, _c(50), reason: 'textHighlight');
        expectToken(resolved.textPrimary, _c(51), reason: 'textPrimary');
        expectToken(resolved.textSecondary, _c(52), reason: 'textSecondary');
        expectToken(resolved.textTertiary, _c(53), reason: 'textTertiary');
        expectToken(resolved.textWhite, _c(54), reason: 'textWhite');
        expectToken(resolved.warning, _c(56), reason: 'warning');
        expectToken(resolved.white, _c(57), reason: 'white');
      },
    );

    testWidgets('properties the helper does not resolve still reach a render', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final p = CometChatColorPalette(
                shimmerBackground: _c(90),
                shimmerGradient: const LinearGradient(
                  colors: [Color(0xFF102030), Color(0xFF405060)],
                ),
                transparent: _c(92),
              );
              return ListView(
                children: [
                  SizedBox(
                    height: 1,
                    child: ColoredBox(color: p.shimmerBackground!),
                  ),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(gradient: p.shimmerGradient),
                  ),
                  SizedBox(height: 1, child: ColoredBox(color: p.transparent!)),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();
      final painted = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color)
          .toList();
      expect(painted, contains(_c(90)), reason: 'shimmerBackground');
      expect(painted, contains(_c(92)), reason: 'transparent');
      expect(
        tester.widget<Container>(find.byType(Container)).decoration,
        isNotNull,
      );
    });
  });

  group('CometChatSpacing', () {
    testWidgets(
      'every property supplied through the theme extension survives the merge',
      (tester) async {
        late CometChatSpacing resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                CometChatSpacing(
                  margin: _d(1),
                  margin1: _d(2),
                  margin10: _d(3),
                  margin11: _d(4),
                  margin12: _d(5),
                  margin13: _d(6),
                  margin14: _d(7),
                  margin15: _d(8),
                  margin16: _d(9),
                  margin17: _d(10),
                  margin18: _d(11),
                  margin19: _d(12),
                  margin2: _d(13),
                  margin20: _d(14),
                  margin3: _d(15),
                  margin4: _d(16),
                  margin5: _d(17),
                  margin6: _d(18),
                  margin7: _d(19),
                  margin8: _d(20),
                  margin9: _d(21),
                  padding: _d(22),
                  padding1: _d(23),
                  padding10: _d(24),
                  padding2: _d(25),
                  padding3: _d(26),
                  padding4: _d(27),
                  padding5: _d(28),
                  padding6: _d(29),
                  padding7: _d(30),
                  padding8: _d(31),
                  padding9: _d(32),
                  radius: _d(33),
                  radius1: _d(34),
                  radius2: _d(35),
                  radius3: _d(36),
                  radius4: _d(37),
                  radius5: _d(38),
                  radius6: _d(39),
                  radiusMax: _d(40),
                  spacing: _d(41),
                  spacing1: _d(42),
                  spacing10: _d(43),
                  spacing11: _d(44),
                  spacing12: _d(45),
                  spacing13: _d(46),
                  spacing14: _d(47),
                  spacing15: _d(48),
                  spacing16: _d(49),
                  spacing17: _d(50),
                  spacing18: _d(51),
                  spacing19: _d(52),
                  spacing2: _d(53),
                  spacing20: _d(54),
                  spacing3: _d(55),
                  spacing4: _d(56),
                  spacing5: _d(57),
                  spacing6: _d(58),
                  spacing7: _d(59),
                  spacing8: _d(60),
                  spacing9: _d(61),
                  spacingMax: _d(62),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatThemeHelper.getSpacing(context);
                return ListView(
                  children: [
                    SizedBox(height: resolved.margin, width: 1),
                    SizedBox(height: resolved.margin1, width: 1),
                    SizedBox(height: resolved.margin10, width: 1),
                    SizedBox(height: resolved.margin11, width: 1),
                    SizedBox(height: resolved.margin12, width: 1),
                    SizedBox(height: resolved.margin13, width: 1),
                    SizedBox(height: resolved.margin14, width: 1),
                    SizedBox(height: resolved.margin15, width: 1),
                    SizedBox(height: resolved.margin16, width: 1),
                    SizedBox(height: resolved.margin17, width: 1),
                    SizedBox(height: resolved.margin18, width: 1),
                    SizedBox(height: resolved.margin19, width: 1),
                    SizedBox(height: resolved.margin2, width: 1),
                    SizedBox(height: resolved.margin20, width: 1),
                    SizedBox(height: resolved.margin3, width: 1),
                    SizedBox(height: resolved.margin4, width: 1),
                    SizedBox(height: resolved.margin5, width: 1),
                    SizedBox(height: resolved.margin6, width: 1),
                    SizedBox(height: resolved.margin7, width: 1),
                    SizedBox(height: resolved.margin8, width: 1),
                    SizedBox(height: resolved.margin9, width: 1),
                    SizedBox(height: resolved.padding, width: 1),
                    SizedBox(height: resolved.padding1, width: 1),
                    SizedBox(height: resolved.padding10, width: 1),
                    SizedBox(height: resolved.padding2, width: 1),
                    SizedBox(height: resolved.padding3, width: 1),
                    SizedBox(height: resolved.padding4, width: 1),
                    SizedBox(height: resolved.padding5, width: 1),
                    SizedBox(height: resolved.padding6, width: 1),
                    SizedBox(height: resolved.padding7, width: 1),
                    SizedBox(height: resolved.padding8, width: 1),
                    SizedBox(height: resolved.padding9, width: 1),
                    SizedBox(height: resolved.radius, width: 1),
                    SizedBox(height: resolved.radius1, width: 1),
                    SizedBox(height: resolved.radius2, width: 1),
                    SizedBox(height: resolved.radius3, width: 1),
                    SizedBox(height: resolved.radius4, width: 1),
                    SizedBox(height: resolved.radius5, width: 1),
                    SizedBox(height: resolved.radius6, width: 1),
                    SizedBox(height: resolved.radiusMax, width: 1),
                    SizedBox(height: resolved.spacing, width: 1),
                    SizedBox(height: resolved.spacing1, width: 1),
                    SizedBox(height: resolved.spacing10, width: 1),
                    SizedBox(height: resolved.spacing11, width: 1),
                    SizedBox(height: resolved.spacing12, width: 1),
                    SizedBox(height: resolved.spacing13, width: 1),
                    SizedBox(height: resolved.spacing14, width: 1),
                    SizedBox(height: resolved.spacing15, width: 1),
                    SizedBox(height: resolved.spacing16, width: 1),
                    SizedBox(height: resolved.spacing17, width: 1),
                    SizedBox(height: resolved.spacing18, width: 1),
                    SizedBox(height: resolved.spacing19, width: 1),
                    SizedBox(height: resolved.spacing2, width: 1),
                    SizedBox(height: resolved.spacing20, width: 1),
                    SizedBox(height: resolved.spacing3, width: 1),
                    SizedBox(height: resolved.spacing4, width: 1),
                    SizedBox(height: resolved.spacing5, width: 1),
                    SizedBox(height: resolved.spacing6, width: 1),
                    SizedBox(height: resolved.spacing7, width: 1),
                    SizedBox(height: resolved.spacing8, width: 1),
                    SizedBox(height: resolved.spacing9, width: 1),
                    SizedBox(height: resolved.spacingMax, width: 1),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        final heights = tester
            .widgetList<SizedBox>(find.byType(SizedBox))
            .map((b) => b.height)
            .toList();
        // ListView realises only the visible children, so assert on what was
        // actually laid out rather than a fixed count.
        expect(heights, isNotEmpty);
        for (final h in heights) {
          expect(
            h,
            anyOf(List.generate(62, (i) => _d(i + 1))),
            reason: 'a rendered height that no supplied spacing produced',
          );
        }
        expect(resolved.margin, _d(1), reason: 'margin');
        expect(resolved.margin1, _d(2), reason: 'margin1');
        expect(resolved.margin10, _d(3), reason: 'margin10');
        expect(resolved.margin11, _d(4), reason: 'margin11');
        expect(resolved.margin12, _d(5), reason: 'margin12');
        expect(resolved.margin13, _d(6), reason: 'margin13');
        expect(resolved.margin14, _d(7), reason: 'margin14');
        expect(resolved.margin15, _d(8), reason: 'margin15');
        expect(resolved.margin16, _d(9), reason: 'margin16');
        expect(resolved.margin17, _d(10), reason: 'margin17');
        expect(resolved.margin18, _d(11), reason: 'margin18');
        expect(resolved.margin19, _d(12), reason: 'margin19');
        expect(resolved.margin2, _d(13), reason: 'margin2');
        expect(resolved.margin20, _d(14), reason: 'margin20');
        expect(resolved.margin3, _d(15), reason: 'margin3');
        expect(resolved.margin4, _d(16), reason: 'margin4');
        expect(resolved.margin5, _d(17), reason: 'margin5');
        expect(resolved.margin6, _d(18), reason: 'margin6');
        expect(resolved.margin7, _d(19), reason: 'margin7');
        expect(resolved.margin8, _d(20), reason: 'margin8');
        expect(resolved.margin9, _d(21), reason: 'margin9');
        expect(resolved.padding, _d(22), reason: 'padding');
        expect(resolved.padding1, _d(23), reason: 'padding1');
        expect(resolved.padding10, _d(24), reason: 'padding10');
        expect(resolved.padding2, _d(25), reason: 'padding2');
        expect(resolved.padding3, _d(26), reason: 'padding3');
        expect(resolved.padding4, _d(27), reason: 'padding4');
        expect(resolved.padding5, _d(28), reason: 'padding5');
        expect(resolved.padding6, _d(29), reason: 'padding6');
        expect(resolved.padding7, _d(30), reason: 'padding7');
        expect(resolved.padding8, _d(31), reason: 'padding8');
        expect(resolved.padding9, _d(32), reason: 'padding9');
        expect(resolved.radius, _d(33), reason: 'radius');
        expect(resolved.radius1, _d(34), reason: 'radius1');
        expect(resolved.radius2, _d(35), reason: 'radius2');
        expect(resolved.radius3, _d(36), reason: 'radius3');
        expect(resolved.radius4, _d(37), reason: 'radius4');
        expect(resolved.radius5, _d(38), reason: 'radius5');
        expect(resolved.radius6, _d(39), reason: 'radius6');
        expect(resolved.radiusMax, _d(40), reason: 'radiusMax');
        expect(resolved.spacing, _d(41), reason: 'spacing');
        expect(resolved.spacing1, _d(42), reason: 'spacing1');
        expect(resolved.spacing10, _d(43), reason: 'spacing10');
        expect(resolved.spacing11, _d(44), reason: 'spacing11');
        expect(resolved.spacing12, _d(45), reason: 'spacing12');
        expect(resolved.spacing13, _d(46), reason: 'spacing13');
        expect(resolved.spacing14, _d(47), reason: 'spacing14');
        expect(resolved.spacing15, _d(48), reason: 'spacing15');
        expect(resolved.spacing16, _d(49), reason: 'spacing16');
        expect(resolved.spacing17, _d(50), reason: 'spacing17');
        expect(resolved.spacing18, _d(51), reason: 'spacing18');
        expect(resolved.spacing19, _d(52), reason: 'spacing19');
        expect(resolved.spacing2, _d(53), reason: 'spacing2');
        expect(resolved.spacing20, _d(54), reason: 'spacing20');
        expect(resolved.spacing3, _d(55), reason: 'spacing3');
        expect(resolved.spacing4, _d(56), reason: 'spacing4');
        expect(resolved.spacing5, _d(57), reason: 'spacing5');
        expect(resolved.spacing6, _d(58), reason: 'spacing6');
        expect(resolved.spacing7, _d(59), reason: 'spacing7');
        expect(resolved.spacing8, _d(60), reason: 'spacing8');
        expect(resolved.spacing9, _d(61), reason: 'spacing9');
        expect(resolved.spacingMax, _d(62), reason: 'spacingMax');
      },
    );
  });

  group(
    'CometChatTextStyle* — supplied type wins over the hardcoded default',
    () {
      testWidgets('CometChatTextStyleHeading1', (tester) async {
        late CometChatTextStyleHeading1 resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                const CometChatTextStyleHeading1(
                  bold: TextStyle(fontSize: 40, letterSpacing: 1),
                  medium: TextStyle(fontSize: 41, letterSpacing: 2),
                  regular: TextStyle(fontSize: 42, letterSpacing: 3),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatTextStyleHeading1.of(context);
                return ListView(
                  children: [
                    Text('bold', style: resolved.bold),
                    Text('medium', style: resolved.medium),
                    Text('regular', style: resolved.regular),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(tester.widget<Text>(find.text('bold')).style?.fontSize, 40);
        expect(resolved.bold?.letterSpacing, 1);
        expect(tester.widget<Text>(find.text('medium')).style?.fontSize, 41);
        expect(resolved.medium?.letterSpacing, 2);
        expect(tester.widget<Text>(find.text('regular')).style?.fontSize, 42);
        expect(resolved.regular?.letterSpacing, 3);
      });
      testWidgets('CometChatTextStyleHeading2', (tester) async {
        late CometChatTextStyleHeading2 resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                const CometChatTextStyleHeading2(
                  bold: TextStyle(fontSize: 40, letterSpacing: 1),
                  medium: TextStyle(fontSize: 41, letterSpacing: 2),
                  regular: TextStyle(fontSize: 42, letterSpacing: 3),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatTextStyleHeading2.of(context);
                return ListView(
                  children: [
                    Text('bold', style: resolved.bold),
                    Text('medium', style: resolved.medium),
                    Text('regular', style: resolved.regular),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(tester.widget<Text>(find.text('bold')).style?.fontSize, 40);
        expect(resolved.bold?.letterSpacing, 1);
        expect(tester.widget<Text>(find.text('medium')).style?.fontSize, 41);
        expect(resolved.medium?.letterSpacing, 2);
        expect(tester.widget<Text>(find.text('regular')).style?.fontSize, 42);
        expect(resolved.regular?.letterSpacing, 3);
      });
      testWidgets('CometChatTextStyleHeading3', (tester) async {
        late CometChatTextStyleHeading3 resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                const CometChatTextStyleHeading3(
                  bold: TextStyle(fontSize: 40, letterSpacing: 1),
                  medium: TextStyle(fontSize: 41, letterSpacing: 2),
                  regular: TextStyle(fontSize: 42, letterSpacing: 3),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatTextStyleHeading3.of(context);
                return ListView(
                  children: [
                    Text('bold', style: resolved.bold),
                    Text('medium', style: resolved.medium),
                    Text('regular', style: resolved.regular),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(tester.widget<Text>(find.text('bold')).style?.fontSize, 40);
        expect(resolved.bold?.letterSpacing, 1);
        expect(tester.widget<Text>(find.text('medium')).style?.fontSize, 41);
        expect(resolved.medium?.letterSpacing, 2);
        expect(tester.widget<Text>(find.text('regular')).style?.fontSize, 42);
        expect(resolved.regular?.letterSpacing, 3);
      });
      testWidgets('CometChatTextStyleHeading4', (tester) async {
        late CometChatTextStyleHeading4 resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                const CometChatTextStyleHeading4(
                  bold: TextStyle(fontSize: 40, letterSpacing: 1),
                  medium: TextStyle(fontSize: 41, letterSpacing: 2),
                  regular: TextStyle(fontSize: 42, letterSpacing: 3),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatTextStyleHeading4.of(context);
                return ListView(
                  children: [
                    Text('bold', style: resolved.bold),
                    Text('medium', style: resolved.medium),
                    Text('regular', style: resolved.regular),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(tester.widget<Text>(find.text('bold')).style?.fontSize, 40);
        expect(resolved.bold?.letterSpacing, 1);
        expect(tester.widget<Text>(find.text('medium')).style?.fontSize, 41);
        expect(resolved.medium?.letterSpacing, 2);
        expect(tester.widget<Text>(find.text('regular')).style?.fontSize, 42);
        expect(resolved.regular?.letterSpacing, 3);
      });
      testWidgets('CometChatTextStyleTitle', (tester) async {
        late CometChatTextStyleTitle resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                const CometChatTextStyleTitle(
                  bold: TextStyle(fontSize: 40, letterSpacing: 1),
                  medium: TextStyle(fontSize: 41, letterSpacing: 2),
                  regular: TextStyle(fontSize: 42, letterSpacing: 3),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatTextStyleTitle.of(context);
                return ListView(
                  children: [
                    Text('bold', style: resolved.bold),
                    Text('medium', style: resolved.medium),
                    Text('regular', style: resolved.regular),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(tester.widget<Text>(find.text('bold')).style?.fontSize, 40);
        expect(resolved.bold?.letterSpacing, 1);
        expect(tester.widget<Text>(find.text('medium')).style?.fontSize, 41);
        expect(resolved.medium?.letterSpacing, 2);
        expect(tester.widget<Text>(find.text('regular')).style?.fontSize, 42);
        expect(resolved.regular?.letterSpacing, 3);
      });
      testWidgets('CometChatTextStyleBody', (tester) async {
        late CometChatTextStyleBody resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                const CometChatTextStyleBody(
                  bold: TextStyle(fontSize: 40, letterSpacing: 1),
                  medium: TextStyle(fontSize: 41, letterSpacing: 2),
                  regular: TextStyle(fontSize: 42, letterSpacing: 3),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatTextStyleBody.of(context);
                return ListView(
                  children: [
                    Text('bold', style: resolved.bold),
                    Text('medium', style: resolved.medium),
                    Text('regular', style: resolved.regular),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(tester.widget<Text>(find.text('bold')).style?.fontSize, 40);
        expect(resolved.bold?.letterSpacing, 1);
        expect(tester.widget<Text>(find.text('medium')).style?.fontSize, 41);
        expect(resolved.medium?.letterSpacing, 2);
        expect(tester.widget<Text>(find.text('regular')).style?.fontSize, 42);
        expect(resolved.regular?.letterSpacing, 3);
      });
      testWidgets('CometChatTextStyleButton', (tester) async {
        late CometChatTextStyleButton resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                const CometChatTextStyleButton(
                  bold: TextStyle(fontSize: 40, letterSpacing: 1),
                  medium: TextStyle(fontSize: 41, letterSpacing: 2),
                  regular: TextStyle(fontSize: 42, letterSpacing: 3),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatTextStyleButton.of(context);
                return ListView(
                  children: [
                    Text('bold', style: resolved.bold),
                    Text('medium', style: resolved.medium),
                    Text('regular', style: resolved.regular),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(tester.widget<Text>(find.text('bold')).style?.fontSize, 40);
        expect(resolved.bold?.letterSpacing, 1);
        expect(tester.widget<Text>(find.text('medium')).style?.fontSize, 41);
        expect(resolved.medium?.letterSpacing, 2);
        expect(tester.widget<Text>(find.text('regular')).style?.fontSize, 42);
        expect(resolved.regular?.letterSpacing, 3);
      });
      testWidgets('CometChatTextStyleCaption1', (tester) async {
        late CometChatTextStyleCaption1 resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                const CometChatTextStyleCaption1(
                  bold: TextStyle(fontSize: 40, letterSpacing: 1),
                  medium: TextStyle(fontSize: 41, letterSpacing: 2),
                  regular: TextStyle(fontSize: 42, letterSpacing: 3),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatTextStyleCaption1.of(context);
                return ListView(
                  children: [
                    Text('bold', style: resolved.bold),
                    Text('medium', style: resolved.medium),
                    Text('regular', style: resolved.regular),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(tester.widget<Text>(find.text('bold')).style?.fontSize, 40);
        expect(resolved.bold?.letterSpacing, 1);
        expect(tester.widget<Text>(find.text('medium')).style?.fontSize, 41);
        expect(resolved.medium?.letterSpacing, 2);
        expect(tester.widget<Text>(find.text('regular')).style?.fontSize, 42);
        expect(resolved.regular?.letterSpacing, 3);
      });
      testWidgets('CometChatTextStyleCaption2', (tester) async {
        late CometChatTextStyleCaption2 resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                const CometChatTextStyleCaption2(
                  bold: TextStyle(fontSize: 40, letterSpacing: 1),
                  medium: TextStyle(fontSize: 41, letterSpacing: 2),
                  regular: TextStyle(fontSize: 42, letterSpacing: 3),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatTextStyleCaption2.of(context);
                return ListView(
                  children: [
                    Text('bold', style: resolved.bold),
                    Text('medium', style: resolved.medium),
                    Text('regular', style: resolved.regular),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(tester.widget<Text>(find.text('bold')).style?.fontSize, 40);
        expect(resolved.bold?.letterSpacing, 1);
        expect(tester.widget<Text>(find.text('medium')).style?.fontSize, 41);
        expect(resolved.medium?.letterSpacing, 2);
        expect(tester.widget<Text>(find.text('regular')).style?.fontSize, 42);
        expect(resolved.regular?.letterSpacing, 3);
      });
      testWidgets('CometChatTextStyleLink', (tester) async {
        late CometChatTextStyleLink resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                const CometChatTextStyleLink(
                  regular: TextStyle(fontSize: 40, letterSpacing: 1),
                ),
              ],
            ),
            home: Builder(
              builder: (context) {
                resolved = CometChatTextStyleLink.of(context);
                return ListView(
                  children: [Text('regular', style: resolved.regular)],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(tester.widget<Text>(find.text('regular')).style?.fontSize, 40);
        expect(resolved.regular?.letterSpacing, 1);
      });
    },
  );

  group('CometChatTypography', () {
    testWidgets('a wholesale typography extension overrides every role', (
      tester,
    ) async {
      late CometChatTypography resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: <ThemeExtension<dynamic>>[
              const CometChatTypography(
                heading1: CometChatTextStyleHeading1(
                  bold: TextStyle(fontSize: 60),
                ),
                heading2: CometChatTextStyleHeading2(
                  bold: TextStyle(fontSize: 61),
                ),
                heading3: CometChatTextStyleHeading3(
                  bold: TextStyle(fontSize: 62),
                ),
                heading4: CometChatTextStyleHeading4(
                  bold: TextStyle(fontSize: 63),
                ),
                title: CometChatTextStyleTitle(bold: TextStyle(fontSize: 64)),
                body: CometChatTextStyleBody(bold: TextStyle(fontSize: 65)),
                button: CometChatTextStyleButton(bold: TextStyle(fontSize: 66)),
                caption1: CometChatTextStyleCaption1(
                  bold: TextStyle(fontSize: 67),
                ),
                caption2: CometChatTextStyleCaption2(
                  bold: TextStyle(fontSize: 68),
                ),
                link: CometChatTextStyleLink(regular: TextStyle(fontSize: 69)),
              ),
            ],
          ),
          home: Builder(
            builder: (context) {
              resolved = CometChatThemeHelper.getTypography(context);
              return ListView(
                children: [
                  Text('heading1', style: resolved.heading1?.bold),
                  Text('heading2', style: resolved.heading2?.bold),
                  Text('heading3', style: resolved.heading3?.bold),
                  Text('heading4', style: resolved.heading4?.bold),
                  Text('title', style: resolved.title?.bold),
                  Text('body', style: resolved.body?.bold),
                  Text('button', style: resolved.button?.bold),
                  Text('caption1', style: resolved.caption1?.bold),
                  Text('caption2', style: resolved.caption2?.bold),
                  Text('link', style: resolved.link?.regular),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('heading1')).style?.fontSize,
        60,
        reason: 'heading1',
      );
      expect(
        tester.widget<Text>(find.text('heading2')).style?.fontSize,
        61,
        reason: 'heading2',
      );
      expect(
        tester.widget<Text>(find.text('heading3')).style?.fontSize,
        62,
        reason: 'heading3',
      );
      expect(
        tester.widget<Text>(find.text('heading4')).style?.fontSize,
        63,
        reason: 'heading4',
      );
      expect(
        tester.widget<Text>(find.text('title')).style?.fontSize,
        64,
        reason: 'title',
      );
      expect(
        tester.widget<Text>(find.text('body')).style?.fontSize,
        65,
        reason: 'body',
      );
      expect(
        tester.widget<Text>(find.text('button')).style?.fontSize,
        66,
        reason: 'button',
      );
      expect(
        tester.widget<Text>(find.text('caption1')).style?.fontSize,
        67,
        reason: 'caption1',
      );
      expect(
        tester.widget<Text>(find.text('caption2')).style?.fontSize,
        68,
        reason: 'caption2',
      );
      expect(
        tester.widget<Text>(find.text('link')).style?.fontSize,
        69,
        reason: 'link',
      );
    });
  });
}
