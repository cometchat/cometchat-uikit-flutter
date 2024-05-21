import 'dart:math';

import 'package:flutter/material.dart';

import '../../cometchat_chat_uikit.dart';

class LiveReactionAnimation extends StatefulWidget {
  final VoidCallback? endAnimation;
  final String reaction;

  const LiveReactionAnimation(
      {super.key, this.endAnimation, required this.reaction});

  @override
  State<LiveReactionAnimation> createState() => _LiveReactionAnimationState();
}

class _LiveReactionAnimationState extends State<LiveReactionAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animationFloatUp;
  late Animation<double> _animationGrowSize;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        duration: const Duration(milliseconds: LiveReactionConstants.timeout),
        vsync: this);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.endAnimation != null) {
          widget.endAnimation!();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _animationFloatUp = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1, curve: Curves.easeIn),
      ),
    );

    _animationGrowSize = Tween(begin: 40.0, end: 200.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1, curve: SineCurve()),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationFloatUp,
      builder: (context, child) {
        return Opacity(
          opacity: (1 - _animationFloatUp.value),
          child: Container(
            margin: EdgeInsets.only(
              bottom: _animationFloatUp.value * 200,
              right: _animationGrowSize.value * 0.25,
            ),
            child: child,
            //width: _animationGrowSize.value,
          ),
        );
      },
      child: Image.asset(
        getImagePath(widget.reaction),
        package: UIConstants.packageName,
        color: Colors.red,
      ),
    );
  }

  String getImagePath(String icon) {
    switch (icon) {
      case "heart":
        return AssetConstants.heart;

      case "like":
        return AssetConstants.heart;

      case "dislike":
        return AssetConstants.heart;

      case "happy":
        return AssetConstants.heart;

      case "sad":
        return AssetConstants.heart;

      default:
        return AssetConstants.heart;
    }
  }
}

class LinerCurve extends Curve {
  final double count;

  const LinerCurve({this.count = 1});

  @override
  double transformInternal(double t) {
    var val = t;
    return val;
  }
}

class SineCurve extends Curve {
  final double count;

  const SineCurve({this.count = 2});

  @override
  double transformInternal(double t) {
    var val = sin(count * 2 * pi * t) * 0.5 + 0.5;
    return val;
  }
}
