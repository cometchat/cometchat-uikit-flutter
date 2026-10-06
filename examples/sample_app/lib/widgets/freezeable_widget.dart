import 'package:flutter/material.dart';
import '../utils/freezeable_route_observer.dart';

/// A widget that can be "frozen" when navigating to certain routes.
/// When frozen, the child is wrapped in IgnorePointer and optionally dimmed.
class FreezeableWidget extends StatelessWidget {
  final Widget child;
  final bool dimWhenFrozen;
  final double dimOpacity;

  const FreezeableWidget({
    super.key,
    required this.child,
    this.dimWhenFrozen = false,
    this.dimOpacity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: FreezeableRouteObserver.instance.shouldFreeze,
      builder: (context, isFrozen, _) {
        Widget result = child;

        if (isFrozen) {
          result = IgnorePointer(
            ignoring: true,
            child: dimWhenFrozen
                ? Opacity(opacity: dimOpacity, child: child)
                : child,
          );
        }

        return result;
      },
    );
  }
}

/// Mixin for StatefulWidgets that need to pause/resume based on freeze state.
mixin FreezeableMixin<T extends StatefulWidget> on State<T> {
  bool _isFrozen = false;

  bool get isFrozen => _isFrozen;

  @override
  void initState() {
    super.initState();
    FreezeableRouteObserver.instance.shouldFreeze.addListener(_onFreezeChanged);
    _isFrozen = FreezeableRouteObserver.instance.shouldFreeze.value;
  }

  @override
  void dispose() {
    FreezeableRouteObserver.instance.shouldFreeze
        .removeListener(_onFreezeChanged);
    super.dispose();
  }

  void _onFreezeChanged() {
    final newValue = FreezeableRouteObserver.instance.shouldFreeze.value;
    if (_isFrozen != newValue) {
      _isFrozen = newValue;
      if (_isFrozen) {
        onFreeze();
      } else {
        onUnfreeze();
      }
    }
  }

  /// Called when the widget should be frozen
  void onFreeze() {}

  /// Called when the widget should be unfrozen
  void onUnfreeze() {}
}
