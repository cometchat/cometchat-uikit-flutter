import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/l10n/translations.dart';
import 'package:intl/intl.dart';

enum DateTimePattern { timeFormat, dayDateFormat, dayDateTimeFormat }

/// Creates a widget that that gives default date UI.
class CometChatDate extends StatelessWidget {
  const CometChatDate(
      {Key? key,
      required this.date,
      this.textStyle,
      this.backgroundColor,
      this.cornerRadius,
      this.borderWidth,
      this.borderColor,
      this.isTransparentBackground,
      this.contentPadding,
      this.pattern,
      this.timeFormat,
      this.dateFormat})
      : super(key: key);

  ///[date] is the date to be shown with [format] format if null then "YYYY-MM-DD"
  final DateTime date;

  ///[textStyle] Style of date to be displayed.
  final TextStyle? textStyle;

  ///[backgroundColor] background color of the container.
  final Color? backgroundColor;

  ///[cornerRadius] radius of corners of container.
  final double? cornerRadius;

  ///[borderWidth] width of border.
  final double? borderWidth;

  final Color? borderColor;

  ///set the container to be transparent.
  final bool? isTransparentBackground;

  ///[contentPadding] set the content padding.
  final EdgeInsetsGeometry? contentPadding;

  final DateTimePattern? pattern;

  final String? timeFormat;

  final String? dateFormat;
  bool _isSameDate(DateTime dt1, DateTime dt2) {
    return dt1.year == dt2.year && dt1.month == dt2.month && dt1.day == dt2.day;
  }

  bool _isSameWeek(DateTime dt1, DateTime dt2) {
    return dt1.difference(dt2) <= const Duration(days: 7) &&
        (dt1.add(Duration(days: -dt1.weekday)).day ==
            dt2.add(Duration(days: -dt2.weekday)).day);
  }

  String _getDateLogic1(DateTime _date, {required String timeFormatter}) {
    return DateFormat(timeFormatter).format(_date);
  }

  String _getDateLogic2(DateTime _date, BuildContext context,
      {required String dateFormatter, required String weekFormatter}) {
    DateTime _todayDate = DateTime.now();
    if (_isSameDate(_todayDate, _date)) {
      return Translations.of(context).today;
    } else if (_isSameDate(_todayDate, _date.add(const Duration(days: 1)))) {
      return Translations.of(context).yesterday;
    } else if (_isSameWeek(_todayDate, _date)) {
      return DateFormat(weekFormatter).format(_date);
    } else {
      return DateFormat(dateFormatter).format(_date);
    }
  }

  String _getDateLogic3(DateTime _date, BuildContext context,
      {required String timeFormatter,
      required String dateFormatter2,
      required String weekFormatter}) {
    DateTime _todayDate = DateTime.now();
    if (_isSameDate(_todayDate, _date)) {
      return DateFormat(timeFormatter).format(_date);
    } else if (_isSameDate(_todayDate, _date.add(const Duration(days: 1)))) {
      return Translations.of(context).yesterday;
    } else if (_isSameWeek(_todayDate, _date)) {
      return DateFormat(weekFormatter).format(_date);
    } else {
      return DateFormat(dateFormatter2).format(_date);
    }
  }

  String _getDate(
    DateTimePattern? datePattern,
    DateTime _date,
    BuildContext context, {
    String timeFormatter = "hh:mm a",
    String weekFormatter = "EEE",
    String dateFormatter = "d MMM, yyyy",
    String dateFormatter2 = "dd MM yyyy",
  }) {
    switch (datePattern) {
      case DateTimePattern.timeFormat:
        return _getDateLogic1(_date, timeFormatter: timeFormatter);
      case DateTimePattern.dayDateFormat:
        return _getDateLogic2(_date, context,
            dateFormatter: dateFormatter, weekFormatter: weekFormatter);
      case DateTimePattern.dayDateTimeFormat:
        return _getDateLogic3(_date, context,
            weekFormatter: weekFormatter,
            timeFormatter: timeFormatter,
            dateFormatter2: dateFormatter2);
      default:
        return _getDateLogic1(_date, timeFormatter: timeFormatter);
    }
  }

  @override
  Widget build(BuildContext context) {
    String _timeFormatter = "hh:mm a";
    String _weekFormatter = "EEE";
    String _dateFormatter = "d MMM, yyyy";
    String _dateFormatter2 = "dd-MM-yyyy";

    if (timeFormat != null && timeFormat != '') {
      _timeFormatter = timeFormat!;
    }

    if (dateFormat != null && dateFormat != '') {
      _dateFormatter = dateFormat!;
      _dateFormatter2 = dateFormat!;
    }

    String _date = _getDate(pattern, date, context,
        timeFormatter: _timeFormatter,
        weekFormatter: _weekFormatter,
        dateFormatter: _dateFormatter,
        dateFormatter2: _dateFormatter2);

    return Container(
      padding: contentPadding ?? const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(Radius.circular(cornerRadius ?? 4.0)),
        border: Border.all(
            width: borderWidth ?? 1.0,
            color: borderColor ?? const Color(0xff141414).withOpacity(0.14)),
        color: backgroundColor != null
            ? backgroundColor
                ?.withOpacity(isTransparentBackground == true ? 0 : 0.5)
            : (isTransparentBackground == true
                ? const Color(0xff141414).withOpacity(0.84)
                : const Color(0xff141414).withOpacity(0.04)),
      ),
      child: Text(
        _date,
        style: textStyle ??
            TextStyle(
                fontSize: 12.0,
                color: const Color(0xff141414).withOpacity(0.84)),
      ),
    );
  }
}
