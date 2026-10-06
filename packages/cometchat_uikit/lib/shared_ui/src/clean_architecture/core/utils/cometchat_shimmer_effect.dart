import 'package:flutter/material.dart';
import '../../presentation/theme/colors/cometchat_color_palette.dart';

class CometChatShimmerEffect extends StatefulWidget {
  const CometChatShimmerEffect({
    super.key,
    required this.child,
    this.linearGradient,
    this.colorPalette,
  });

  final Widget child;
  final LinearGradient? linearGradient;
  final CometChatColorPalette? colorPalette;

  @override
  State<CometChatShimmerEffect> createState() => _CometChatShimmerEffectState();
}

class _CometChatShimmerEffectState extends State<CometChatShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LinearGradient get _defaultGradient {
    final palette = widget.colorPalette;
    return LinearGradient(
      colors: [
        palette?.neutral200 ?? Colors.transparent,
        palette?.neutral300 ?? Colors.transparent,
        palette?.neutral400 ?? Colors.transparent,
      ],
      stops: const [0.1, 0.3, 0.4],
      begin: const Alignment(-1.0, -0.3),
      end: const Alignment(1.0, 0.3),
      tileMode: TileMode.clamp,
    );
  }

  LinearGradient get _computedGradient {
    final baseGradient = widget.linearGradient ?? _defaultGradient;
    return LinearGradient(
      colors: baseGradient.colors,
      stops: baseGradient.stops,
      begin: baseGradient.begin,
      end: baseGradient.end,
      tileMode: baseGradient.tileMode,
      transform: _SlidingGradientTransform(slidePercent: _controller.value),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A loading skeleton carries no information; without this a screen reader
    // walks a list of empty placeholder boxes while content is still loading.
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) {
          return ShaderMask(
            shaderCallback: (bounds) => _computedGradient.createShader(bounds),
            blendMode: BlendMode.srcATop,
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
