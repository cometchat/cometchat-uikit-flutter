import 'package:flutter/material.dart';

/// Route observer that tracks when we're on the messages screen
/// and notifies listeners to freeze/unfreeze other screens.
class FreezeableRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  /// Singleton instance
  static final FreezeableRouteObserver instance = FreezeableRouteObserver._();

  FreezeableRouteObserver._();

  /// Notifies when screens should be frozen (true = freeze, false = unfreeze)
  final ValueNotifier<bool> shouldFreeze = ValueNotifier<bool>(false);

  /// Track the route names that should trigger freezing
  final Set<String> _freezeTriggerRoutes = {'messages'};

  /// Current route stack depth for freeze triggers
  int _freezeRouteCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _checkFreeze(route, isPush: true);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _checkFreeze(route, isPush: false);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) _checkFreeze(oldRoute, isPush: false);
    if (newRoute != null) _checkFreeze(newRoute, isPush: true);
  }

  void _checkFreeze(Route<dynamic> route, {required bool isPush}) {
    final routeName = route.settings.name;
    final isFreezeRoute =
        routeName != null && _freezeTriggerRoutes.contains(routeName);

    if (isFreezeRoute) {
      if (isPush) {
        _freezeRouteCount++;
      } else {
        _freezeRouteCount = (_freezeRouteCount - 1).clamp(0, 999);
      }
      shouldFreeze.value = _freezeRouteCount > 0;
    }
  }

  /// Register a route name that should trigger freezing when pushed
  void addFreezeTriggerRoute(String routeName) {
    _freezeTriggerRoutes.add(routeName);
  }
}
