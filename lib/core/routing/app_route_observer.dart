import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// App-wide `RouteObserver`, registered in `MaterialApp.navigatorObservers`
/// (`app.dart`). Adds a simple Sentry breadcrumb on route transitions.
final RouteObserver<ModalRoute<void>> appRouteObserver = _SentryRouteObserver();

class _SentryRouteObserver extends RouteObserver<ModalRoute<void>> {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    Sentry.addBreadcrumb(Breadcrumb(message: 'route.push', data: {'route': route.settings.name}));
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    Sentry.addBreadcrumb(Breadcrumb(message: 'route.pop', data: {'route': route.settings.name}));
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    Sentry.addBreadcrumb(Breadcrumb(message: 'route.replace', data: {'new': newRoute?.settings.name, 'old': oldRoute?.settings.name}));
  }
}
