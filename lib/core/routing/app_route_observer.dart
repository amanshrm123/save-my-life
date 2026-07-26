import 'package:flutter/material.dart';

/// App-wide `RouteObserver`, registered in `MaterialApp.navigatorObservers`
/// (`app.dart`). Lets screens that stay mounted-but-offscreen underneath a
/// pushed route (e.g. `HomeScreen` under `OutcomeCardScreen`, since v3's
/// play->outcome flow is a `pushReplacement` that never pops Home off the
/// stack) distinguish "I rebuilt because a provider changed" from "I am
/// actually the visible, current route again" — the latter via `RouteAware`'s
/// `didPopNext()`, not `build()`/`mounted` alone.
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();
