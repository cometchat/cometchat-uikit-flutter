import 'package:flutter/material.dart';
import '../../../../../../cometchat_uikit_shared.dart';
import 'package:intl/intl.dart';

enum DateTimePattern { timeFormat, dayDateFormat, dayDateTimeFormat }

///[CometChatDate] is a widget that provides a customizable container to display date and time
/// ```dart
///   CometChatDate(
///    date: DateTime.now(),
///    customDateString: "some custom text to show in place of date",
///    pattern: DateTimePattern.dayDateTimeFormat,
///  );
/// ```
class CometChatDate extends StatelessWidget {
  const CometChatDate({
    super.key,
    this.date,
    this.pattern,
    this.style = const CometChatDateStyle(),
    this.customDateString,
    this.height,
    this.padding,
    this.width,
    this.isTransparentBackground,
    this.dateTimeFormatterCallback,
  });

  ///[date] is the date to be shown
  final DateTime? date;

  ///[pattern] formats the DateTime object
  final DateTimePattern? pattern;

  ///[style] contains properties that affects the appearance of this widget
  final CometChatDateStyle style;

  ///[customDateString] if not null is shown instead of date from DateTime object
  final String? customDateString;

  ///[width] provides width to the widget
  final double? width;

  ///[height] provides height to the widget
  final double? height;

  /// [padding] provides padding to the widget
  final EdgeInsetsGeometry? padding;

  /// [isTransparentBackground] if true, the background will be transparent
  final bool? isTransparentBackground;

  /// [dateTimeFormatterCallback] is a callback that can be used to format the date and time
  final DateTimeFormatterCallback? dateTimeFormatterCallback;

  bool _isSameDate(DateTime dt1, DateTime dt2) {
    return dt1.year == dt2.year && dt1.month == dt2.month && dt1.day == dt2.day;
  }

  bool _isSameWeek(DateTime dt1, DateTime dt2) {
    return dt1.difference(dt2) <= const Duration(days: 7) &&
        (dt1.add(Duration(days: -dt1.weekday)).day ==
            dt2.add(Duration(days: -dt2.weekday)).day);
  }

  String _getTime(DateTime date, String timeFormatter) {
    String formattedTime;
    if (dateTimeFormatterCallback?.time(date.millisecondsSinceEpoch) != null) {
      formattedTime =
          dateTimeFormatterCallback?.time(date.millisecondsSinceEpoch) ??
          DateFormat(timeFormatter).format(date);
    } else {
      formattedTime =
          CometChatUIKit.authenticationSettings?.dateTimeFormatterCallback
              ?.time(date.millisecondsSinceEpoch) ??
          DateFormat(timeFormatter).format(date);
    }
    // Convert AM/PM to lowercase
    return formattedTime.replaceAll('AM', 'am').replaceAll('PM', 'pm');
  }

  String _getToday(DateTime date, BuildContext context) {
    if (dateTimeFormatterCallback?.today(date.millisecondsSinceEpoch) != null) {
      return dateTimeFormatterCallback?.today(date.millisecondsSinceEpoch) ??
          Translations.of(context).today;
    } else {
      return CometChatUIKit.authenticationSettings?.dateTimeFormatterCallback
              ?.today(date.millisecondsSinceEpoch) ??
          Translations.of(context).today;
    }
  }

  String _getYesterday(DateTime date, BuildContext context) {
    if (dateTimeFormatterCallback?.yesterday(date.millisecondsSinceEpoch) !=
        null) {
      return dateTimeFormatterCallback?.yesterday(
            date.millisecondsSinceEpoch,
          ) ??
          Translations.of(context).yesterday;
    } else {
      return CometChatUIKit.authenticationSettings?.dateTimeFormatterCallback
              ?.yesterday(date.millisecondsSinceEpoch) ??
          Translations.of(context).yesterday;
    }
  }

  String _getLastWeek(
    DateTime date,
    String weekFormatter,
    String dateFormatter,
  ) {
    if (dateTimeFormatterCallback?.lastWeek(date.millisecondsSinceEpoch) !=
        null) {
      return dateTimeFormatterCallback?.lastWeek(date.millisecondsSinceEpoch) ??
          DateFormat(weekFormatter).format(date);
    } else {
      return CometChatUIKit.authenticationSettings?.dateTimeFormatterCallback
              ?.lastWeek(date.millisecondsSinceEpoch) ??
          DateFormat(dateFormatter).format(date);
    }
  }

  String _getOtherDays(DateTime date, String dateFormatter) {
    if (dateTimeFormatterCallback?.otherDays(date.millisecondsSinceEpoch) !=
        null) {
      return dateTimeFormatterCallback?.otherDays(
            date.millisecondsSinceEpoch,
          ) ??
          DateFormat(dateFormatter).format(date);
    } else {
      return CometChatUIKit.authenticationSettings?.dateTimeFormatterCallback
              ?.otherDays(date.millisecondsSinceEpoch) ??
          DateFormat(dateFormatter).format(date);
    }
  }

  String _getDateLogic1(DateTime date, {required String timeFormatter}) {
    return _getTime(date, timeFormatter);
  }

  String _getDateLogic2(
    DateTime date,
    BuildContext context, {
    required String timeFormatter,
    required String dateFormatter,
    required String dateFormatter2,
    required String weekFormatter,
  }) {
    DateTime todayDate = DateTime.now();
    if (_isSameDate(todayDate, date)) {
      return _getToday(date, context);
    } else if (_isSameDate(todayDate, date.add(const Duration(days: 1)))) {
      return _getYesterday(date, context);
    } else if (_isSameWeek(todayDate, date)) {
      return _getLastWeek(date, weekFormatter, dateFormatter);
    } else {
      return _getOtherDays(date, dateFormatter);
    }
  }

  String _getDateLogic3(
    DateTime date,
    BuildContext context, {
    required String dateFormatter,
    required String timeFormatter,
    required String dateFormatter2,
    required String weekFormatter,
  }) {
    DateTime todayDate = DateTime.now();
    if (_isSameDate(todayDate, date)) {
      return _getTime(date, timeFormatter);
    } else if (_isSameDate(todayDate, date.add(const Duration(days: 1)))) {
      return _getYesterday(date, context);
    } else if (_isSameWeek(todayDate, date)) {
      return _getLastWeek(date, weekFormatter, dateFormatter);
    } else {
      return _getOtherDays(date, dateFormatter);
    }
  }

  String _getDate(
    DateTimePattern? datePattern,
    DateTime date,
    BuildContext context, {
    String timeFormatter = "h:mm a",
    String weekFormatter = "EEE",
    String dateFormatter = "d MMM, yyyy",
    String dateFormatter2 = "dd MM yyyy",
  }) {
    switch (datePattern) {
      case DateTimePattern.timeFormat:
        return _getDateLogic1(date, timeFormatter: timeFormatter);
      case DateTimePattern.dayDateFormat:
        return _getDateLogic2(
          date,
          context,
          timeFormatter: timeFormatter,
          dateFormatter: dateFormatter,
          weekFormatter: weekFormatter,
          dateFormatter2: dateFormatter2,
        );
      case DateTimePattern.dayDateTimeFormat:
        return _getDateLogic3(
          date,
          context,
          dateFormatter: dateFormatter,
          weekFormatter: weekFormatter,
          timeFormatter: timeFormatter,
          dateFormatter2: dateFormatter2,
        );
      default:
        return _getDateLogic1(date, timeFormatter: timeFormatter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStyle = CometChatThemeHelper.getTheme<CometChatDateStyle>(
      context: context,
      defaultTheme: CometChatDateStyle.of,
    ).merge(style);
    final typography = CometChatThemeHelper.getTypography(context);
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final spacing = CometChatThemeHelper.getSpacing(context);

    String date;

    String timeFormatter = "h:mm a";
    String weekFormatter = "EEE";
    String dateFormatter = "d MMM, yyyy";
    String dateFormatter2 = "dd/MM/yy";

    if (customDateString != null) {
      date = customDateString!;
    } else {
      date = _getDate(
        pattern,
        this.date ?? DateTime.now(),
        context,
        timeFormatter: timeFormatter,
        weekFormatter: weekFormatter,
        dateFormatter: dateFormatter,
        dateFormatter2: dateFormatter2,
      );
    }

    return Container(
      padding:
          padding ??
          EdgeInsets.symmetric(
            vertical: spacing.padding1 ?? 0,
            horizontal: spacing.padding2 ?? 0,
          ),
      height: height,
      width: width,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius:
            dateStyle.borderRadius ??
            BorderRadius.all(Radius.circular(spacing.radius1 ?? 0)),
        border:
            dateStyle.border ??
            Border.all(
              width: 1,
              color: colorPalette.borderDark ?? Colors.transparent,
            ),
        color: isTransparentBackground == true
            ? dateStyle.backgroundColor?.withValues(alpha: 0)
            : dateStyle.backgroundColor ?? colorPalette.background2,
      ),
      child: Text(
        date,
        // Callers pass `overflow: TextOverflow.ellipsis` in the *style* with no
        // maxLines, which makes the paragraph ellipsise against whatever height
        // it is given rather than wrap. One line at default text size (no
        // visual change), two when the user has scaled up.
        maxLines: scaledMaxLines(context),
        style: TextStyle(
          color: dateStyle.textColor ?? colorPalette.textSecondary,
          fontSize: typography.caption1?.regular?.fontSize,
          fontWeight: typography.caption1?.regular?.fontWeight,
          fontFamily: typography.caption1?.regular?.fontFamily,
        ).merge(dateStyle.textStyle).copyWith(color: dateStyle.textColor),
      ),
    );
  }
}
