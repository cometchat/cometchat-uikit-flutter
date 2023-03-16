//All about CometChat themes
import 'package:flutter/material.dart';

///By default two modes
enum PaletteThemeModes { dark, light }

///Modal class for modes
class PaletteModel {
  final Color light;
  final Color dark;
  const PaletteModel({required this.light, required this.dark});
}

///Model class for Themes
///can also make custom objects to pass on to various theme variable to any CometChat UI element
class Palette {
  ///light or dark two modes , by default light.
  final PaletteThemeModes mode;

  ///List of gradient for background colour.
  final PaletteModel backGroundColor;

  ///Primary color component with light and dark theme.
  final PaletteModel primary;

  ///Secondary color component with light and dark theme.
  final PaletteModel secondary;

  ///error color component with light and dark theme.
  final PaletteModel error;

  ///success color component with light and dark theme.
  final PaletteModel success;

  ///accent color component used.
  final PaletteModel accent;

  ///Primary color component with light and dark theme.
  final PaletteModel option;

  ///Optional parameters with different accents ranging from 50 to 800.
  final PaletteModel? accent50;

  final PaletteModel? accent100;

  final PaletteModel? accent200;

  final PaletteModel? accent300;

  final PaletteModel? accent400;

  final PaletteModel? accent500;

  final PaletteModel? accent600;

  final PaletteModel? accent700;

  final PaletteModel? accent800;

  final PaletteModel? primary200;

  final PaletteModel? secondary900;

  ///methods to get accent opacity according to mode

  Color getBackground() {
    return mode == PaletteThemeModes.dark
        ? backGroundColor.dark
        : backGroundColor.light;
  }

  ///Return primary colour's light or dark theme colour according to mode.
  Color getPrimary() {
    return mode == PaletteThemeModes.dark ? primary.dark : primary.light;
  }

  ///Return primary colour's light or dark theme colour according to mode.
  Color getError() {
    return mode == PaletteThemeModes.dark ? error.dark : error.light;
  }

  Color getSuccess() {
    return mode == PaletteThemeModes.dark ? success.dark : success.light;
  }

  Color getAccent() {
    return mode == PaletteThemeModes.dark ? accent.dark : accent.light;
  }

  Color getOption() {
    return mode == PaletteThemeModes.dark ? option.dark : option.light;
  }

  Color getAccent50() {
    if (accent50 != null) {
      return mode == PaletteThemeModes.dark ? accent50!.dark : accent50!.light;
    } else {
      return mode == PaletteThemeModes.dark
          ? accent.dark.withOpacity(0.04)
          : accent.light.withOpacity(0.04);
    }
  }

  Color getAccent100() {
    if (accent100 != null) {
      return mode == PaletteThemeModes.dark
          ? accent100!.dark
          : accent100!.light;
    } else {
      return mode == PaletteThemeModes.dark
          ? accent.dark.withOpacity(0.08)
          : accent.light.withOpacity(0.08);
    }
  }

  Color getAccent200() {
    if (accent200 != null) {
      return mode == PaletteThemeModes.dark
          ? accent200!.dark
          : accent200!.light;
    } else {
      return mode == PaletteThemeModes.dark
          ? accent.dark.withOpacity(0.15)
          : accent.light.withOpacity(0.14);
    }
  }

  Color getAccent300() {
    if (accent300 != null) {
      return mode == PaletteThemeModes.dark
          ? accent300!.dark
          : accent300!.light;
    } else {
      return mode == PaletteThemeModes.dark
          ? accent.dark.withOpacity(0.24)
          : accent.light.withOpacity(0.23);
    }
  }

  Color getAccent400() {
    if (accent400 != null) {
      return mode == PaletteThemeModes.dark
          ? accent400!.dark
          : accent400!.light;
    } else {
      return mode == PaletteThemeModes.dark
          ? accent.dark.withOpacity(0.33)
          : accent.light.withOpacity(0.34);
    }
  }

  Color getAccent500() {
    if (accent500 != null) {
      return mode == PaletteThemeModes.dark
          ? accent500!.dark
          : accent500!.light;
    } else {
      return mode == PaletteThemeModes.dark
          ? accent.dark.withOpacity(0.46)
          : accent.light.withOpacity(0.46);
    }
  }

  Color getAccent600() {
    if (accent600 != null) {
      return mode == PaletteThemeModes.dark
          ? accent600!.dark
          : accent600!.light;
    } else {
      return mode == PaletteThemeModes.dark
          ? accent.dark.withOpacity(0.58)
          : accent.light.withOpacity(0.58);
    }
  }

  Color getAccent700() {
    if (accent700 != null) {
      return mode == PaletteThemeModes.dark
          ? accent700!.dark
          : accent700!.light;
    } else {
      return mode == PaletteThemeModes.dark
          ? accent.dark.withOpacity(0.69)
          : accent.light.withOpacity(0.71);
    }
  }

  Color getAccent800() {
    if (accent800 != null) {
      return mode == PaletteThemeModes.dark
          ? accent800!.dark
          : accent800!.light;
    } else {
      return mode == PaletteThemeModes.dark
          ? accent.dark.withOpacity(0.82)
          : accent.light.withOpacity(0.84);
    }
  }

  Color getSecondary900() {
    if (secondary900 != null) {
      return mode == PaletteThemeModes.dark
          ? secondary900!.dark
          : secondary900!.light;
    } else {
      return mode == PaletteThemeModes.dark
          ? secondary.dark.withOpacity(0.92)
          : secondary.light.withOpacity(0.92);
    }
  }

  Color getSecondary() {
    return mode == PaletteThemeModes.dark ? secondary.dark : secondary.light;
  }

  Color getPrimary200() {
    if (primary200 != null) {
      return mode == PaletteThemeModes.dark
          ? primary200!.dark
          : primary200!.light;
    } else {
      return mode == PaletteThemeModes.dark
          ? primary.dark.withOpacity(0.20)
          : primary.light.withOpacity(0.20);
    }
  }

  ///Constructor
  const Palette(
      {this.mode = PaletteThemeModes.light,
      this.backGroundColor =
          const PaletteModel(light: Color(0xffFFFFFF), dark: Color(0xff141414)),
      this.primary =
          const PaletteModel(light: Color(0xff3399FF), dark: Color(0xff3399FF)),
      this.secondary =
          const PaletteModel(light: Color(0xffF8F8F8), dark: Color(0xff333333)),
      this.error =
          const PaletteModel(light: Color(0xffFF3B30), dark: Color(0xffFF3B30)),
      this.success =
          const PaletteModel(light: Color(0xff00C86F), dark: Color(0xff00C86F)),
      this.accent =
          const PaletteModel(light: Color(0xff141414), dark: Color(0xffFFFFFF)),
      this.option =
          const PaletteModel(light: Color(0xffFFC900), dark: Color(0xffFFC900)),
      this.accent50,
      this.accent100,
      this.accent200,
      this.accent300,
      this.accent400,
      this.accent500,
      this.accent600,
      this.accent700,
      this.accent800,
      this.primary200,
      this.secondary900});
}

///Default exposed theme with light mode
const Palette defaultPaletteTheme = Palette();
