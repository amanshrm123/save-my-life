import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/app_page_transitions.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sticker_button.dart';
import '../../ads/application/ad_gate.dart';
import '../../ads/application/ad_service.dart';
import '../../ads/presentation/ad_failed_view.dart';
import '../../ads/presentation/interstitial_screen.dart';
import '../../ads/state/ad_providers.dart';
import '../../play_loop/domain/run_state.dart';
import '../../play_loop/domain/run_summary.dart';
import '../../play_loop/presentation/play_loop_screen.dart';
import '../../sharing/state/share_providers.dart';
import '../state/outcome_providers.dart';
import 'widgets/outcome_card.dart';

/// Real outcome-card screen (architecture v3 §3), replacing
/// `PlaceholderOutcomeScreen`. Hosts the shareable `RepaintBoundary` card,
/// the Share/Again actions row, the post-share confirm toast (design v3
/// §3.2), and orchestrates the "Again" -> `AdGate` -> interstitial/ad-failed
/// -> next-run navigation (architecture §9).
class OutcomeCardScreen extends ConsumerStatefulWidget {
  const OutcomeCardScreen({super.key, required this.summary});

  final RunSummary summary;

  @override
  ConsumerState<OutcomeCardScreen> createState() => _OutcomeCardScreenState();
}

class _OutcomeCardScreenState extends ConsumerState<OutcomeCardScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  late final AnimationController _entranceController;
  late final Animation<double> _entrance;

  Timer? _toastTimer;
  bool _toastVisible = false;
  bool _navigating = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    // Every reachable OutcomeCardScreen build corresponds to exactly one
    // completed run — the session-only interstitial cadence counter
    // (architecture §5/§11 risk 3) advances here, once. Deferred to a
    // post-frame callback: `initState` can run mid-build (e.g. while a
    // route-transition's own `SlideTransition` is being built), and Riverpod
    // disallows modifying a provider during the widget tree's build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(adGateProvider.notifier).registerRunCompleted();
    });

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _entrance = CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack);
    _entranceController.forward();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  String get _shareText {
    switch (widget.summary.outcome) {
      case RunOutcome.death:
        return 'I just died in Stay Alive — stayalive.app';
      case RunOutcome.survived:
        return 'I just pulled a last-second save in Stay Alive — stayalive.app';
      case RunOutcome.eternal:
        return 'I just went Eternal in Stay Alive — stayalive.app';
    }
  }

  Future<void> _onShare() async {
    if (_sharing) return;
    _sharing = true;
    try {
      final renderer = ref.read(cardRendererProvider);
      final file = await renderer.renderToFile(_cardKey);
      if (!mounted || file == null) return;

      final shareService = ref.read(shareServiceProvider);
      final success = await shareService.shareFile(file, text: _shareText);
      if (!mounted || !success) return;
      _showToast();
    } finally {
      _sharing = false;
    }
  }

  void _showToast() {
    _toastTimer?.cancel();
    setState(() => _toastVisible = true);
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      setState(() => _toastVisible = false);
    });
  }

  Future<void> _onAgain() async {
    if (_navigating) return;
    _navigating = true;

    if (!ref.read(adGateProvider.notifier).isDue) {
      _goToPlay(context);
      return;
    }

    final result = await ref.read(adServiceProvider).showInterstitial();
    if (!mounted) return;
    if (result == InterstitialResult.shown) {
      _goToInterstitial(context);
    } else {
      _goToAdFailed(context);
    }
  }

  void _onHome() {
    Navigator.of(context).popUntil((route) => route.settings.name == AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final content = ref.watch(outcomeCardContentProvider(summary));
    final style = _shareButtonStyle(summary.outcome);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onHome();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: [
                FadeTransition(
                  opacity: _entrance,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1).animate(_entrance),
                    child: Column(
                      children: [
                        Expanded(
                          child: RepaintBoundary(
                            key: _cardKey,
                            child: OutcomeCard(
                              outcome: summary.outcome,
                              playerName: summary.playerName,
                              content: content,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _ActionsRow(
                          shareLabel: style.label,
                          shareFill: style.fill,
                          shareText: style.textColor,
                          onShare: _onShare,
                          onAgain: _onAgain,
                        ),
                        // Architecture v3 §9's nav graph lists Home as a
                        // sibling action to Share/Again, but the mockup's
                        // actions row only shows two buttons (§2.1) — same
                        // category of mockup gap as the missing Home
                        // gear-icon/back-chevron (design v3 §5.1/§5.3).
                        // Reuses onboarding's established plain-text-link
                        // convention ("Skip for now") rather than bolting on
                        // a third sticker button this tight card screen has
                        // no room for.
                        GestureDetector(
                          onTap: _onHome,
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Home', style: AppTypography.ghostLink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_toastVisible)
                  Positioned(left: 14, right: 14, bottom: 62, child: const _ShareToast()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ShareButtonStyle _shareButtonStyle(RunOutcome outcome) {
    switch (outcome) {
      case RunOutcome.death:
        return const _ShareButtonStyle('Share →', AppColors.red, Colors.white);
      case RunOutcome.survived:
        return const _ShareButtonStyle('Share →', AppColors.green, Colors.white);
      case RunOutcome.eternal:
        return const _ShareButtonStyle('Flex it →', AppColors.gold, AppColors.ink);
    }
  }
}

class _ShareButtonStyle {
  const _ShareButtonStyle(this.label, this.fill, this.textColor);
  final String label;
  final Color fill;
  final Color textColor;
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.shareLabel,
    required this.shareFill,
    required this.shareText,
    required this.onShare,
    required this.onAgain,
  });

  final String shareLabel;
  final Color shareFill;
  final Color shareText;
  final VoidCallback onShare;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StickerButton(
            label: shareLabel,
            fill: shareFill,
            textColor: shareText,
            labelShadow: AppColors.ink,
            showLabelTextShadow: false,
            height: 40,
            borderRadius: 12,
            restShadowOffset: 4,
            fontSize: 13,
            onPressed: onShare,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StickerButton(
            label: 'Again',
            fill: AppColors.paper,
            textColor: AppColors.ink,
            labelShadow: AppColors.ink,
            showLabelTextShadow: false,
            height: 40,
            borderRadius: 12,
            restShadowOffset: 4,
            fontSize: 13,
            onPressed: onAgain,
          ),
        ),
      ],
    );
  }
}

class _ShareToast extends StatelessWidget {
  const _ShareToast();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
      child: const Text(
        '✓ Shared',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

// --- "Again" -> AdGate -> interstitial/ad-failed -> next-run navigation
// (architecture v3 §9). Deliberately top-level, not `State` methods: once
// "Again" hands off to the interstitial/ad-failed route, the *original*
// `OutcomeCardScreenState` has been replaced (and disposed) by
// `pushReplacement`, so every subsequent hop takes its own fresh
// `BuildContext` (and, where Riverpod access is needed, its own `Consumer`)
// rather than reusing a `State` whose `ref`/`context` may already be gone.

void _goToPlay(BuildContext context) {
  Navigator.of(context).pushReplacement(
    fadeSlideRoute(
      settings: const RouteSettings(name: AppRoutes.play),
      builder: (_) => const PlayLoopScreen(),
    ),
  );
}

void _goToInterstitial(BuildContext context) {
  Navigator.of(context).pushReplacement(
    fadeSlideRoute(
      settings: const RouteSettings(name: '/ad/interstitial'),
      builder: (innerContext) => InterstitialScreen(onDone: () => _goToPlay(innerContext)),
    ),
  );
}

void _goToAdFailed(BuildContext context) {
  Navigator.of(context).pushReplacement(
    fadeSlideRoute(
      settings: const RouteSettings(name: '/ad/failed'),
      builder: (innerContext) => Consumer(
        builder: (consumerContext, ref, _) => AdFailedView(
          onRetry: () => _retryInterstitial(innerContext, ref),
          onMaybeLater: () => _goToPlay(innerContext),
        ),
      ),
    ),
  );
}

Future<void> _retryInterstitial(BuildContext context, WidgetRef ref) async {
  final result = await ref.read(adServiceProvider).showInterstitial();
  if (!context.mounted) return;
  if (result == InterstitialResult.shown) {
    _goToInterstitial(context);
  } else {
    _goToAdFailed(context);
  }
}
