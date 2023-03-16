import 'dart:ui';
import 'package:flutter/material.dart';

class DottedBorder extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double strokeWidth;
  final Color color;
  final Radius radius;

  const DottedBorder({
    Key? key,
    required this.child,
    this.color = Colors.black,
    this.strokeWidth = 1,
    this.padding = const EdgeInsets.all(0),
    this.radius = const Radius.circular(0),
  }):super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _DashPainter(
              strokeWidth: strokeWidth,
              radius: radius,
              color: color,
              dashPattern: [4],
            ),
          ),
        ),
        Padding(
          padding: padding,
          child: child,
        ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  final double strokeWidth;
  final List<double> dashPattern;
  final Color color;
  final Radius radius;

  _DashPainter({
    this.strokeWidth = 2,
    this.dashPattern = const <double>[3, 1],
    this.color = Colors.black,
    this.radius = const Radius.circular(0),
  });

  Path _getPath(Size size) {
    Path path = _getRRectPath(size, radius);
    return dashPath(path, dashArray: CircularIntervalList(dashPattern));
  }

  Path dashPath(
    Path source, {
    required CircularIntervalList<double> dashArray,
    DashOffset? dashOffset,
  }) {
    dashOffset = dashOffset ?? const DashOffset.absolute(0.0);

    final Path dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = dashOffset._calculate(metric.length);
      bool draw = true;
      while (distance < metric.length) {
        final double len = dashArray.next;
        if (draw) {
          dest.addPath(
              metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }

    return dest;
  }

  Path _getRRectPath(Size size, Radius radius) {
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            0,
            0,
            size.width,
            size.height,
          ),
          radius,
        ),
      );
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color ||
        oldDelegate.dashPattern != dashPattern;
  }

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..strokeWidth = strokeWidth
      ..color = color
      ..style = PaintingStyle.stroke;

    Path _path = _getPath(size);

    canvas.drawPath(_path, paint);
  }
}

enum _DashOffsetType { absolute, percentage }

class DashOffset {
  DashOffset.percentage(double percentage)
      : _rawVal = percentage.clamp(0.0, 1.0),
        _dashOffsetType = _DashOffsetType.percentage;

  const DashOffset.absolute(double start)
      : _rawVal = start,
        _dashOffsetType = _DashOffsetType.absolute;

  final double _rawVal;
  final _DashOffsetType _dashOffsetType;

  double _calculate(double length) {
    return _dashOffsetType == _DashOffsetType.absolute
        ? _rawVal
        : length * _rawVal;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DashOffset &&
        other._rawVal == _rawVal &&
        other._dashOffsetType == _dashOffsetType;
  }

  @override
  int get hashCode => hashValues(_rawVal, _dashOffsetType);
}

class CircularIntervalList<T> {
  CircularIntervalList(this._vals);
  final List<T> _vals;
  int _idx = 0;

  T get next {
    if (_idx >= _vals.length) {
      _idx = 0;
    }
    return _vals[_idx++];
  }
}
