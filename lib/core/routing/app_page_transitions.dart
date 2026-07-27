import 'package:flutter/material.dart';

/// The fade + slight-upward-slide transition design spec v1 §4.2 calls for
/// on the splash's one-time handoff (splash is never back-navigable, so no
/// shared-element continuity is needed — just a clean brand-to-content cut).
Route<T> fadeSlideRoute<T>({
  required RouteSettings settings,
  required WidgetBuilder builder,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
