import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// App-wide `RouteObserver`, registered in `MaterialApp.navigatorObservers`
/// (`app.dart`). Lets screens that stay mounted-but-offscreen underneath a
/// pushed route (e.g. `HomeScreen` under `OutcomeCardScreen`, since v3's
/// play->outcome flow is a `pushReplacement` that never pops Home off the
/// stack) distinguish "I rebuilt because a provider changed" from "I am
/// actually the visible, current route again" — the latter via `RouteAware`'s
/// `didPopNext()`, not `build()`/`mounted` alone.
///
/// Also adds a Sentry breadcrumb on every push/pop/replace (route names
/// only, never a screen's live state) — each override calls `super` FIRST,
/// so the `RouteAware` forwarding above still fires exactly as before; the
/// breadcrumb is purely observational, added after.
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
