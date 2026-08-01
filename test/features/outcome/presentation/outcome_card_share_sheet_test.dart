import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/widgets/sticker_button.dart';
import 'package:timing_tap/features/outcome/presentation/outcome_card_screen.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/run_summary.dart';
import 'package:timing_tap/features/sharing/application/card_renderer.dart';
import 'package:timing_tap/features/sharing/application/share_service.dart';
import 'package:timing_tap/features/sharing/application/social_share_service.dart';
import 'package:timing_tap/features/sharing/domain/share_target.dart';
import 'package:timing_tap/features/sharing/presentation/share_target_sheet.dart';
import 'package:timing_tap/features/sharing/state/share_providers.dart';

/// Coverage scoped specifically to this request's change: wiring
/// `OutcomeCardScreen._onShare` to `ShareTargetSheet` (architecture v5 §4/
/// §12 flag 4), not the whole outcome flow (already covered by
/// `outcome_card_screen_test.dart`/`integration/rapid_interaction_guards_test.dart`).
///
/// `CardRenderer.renderToFile` normally can't succeed under `flutter test`
/// (no `path_provider` platform channel — the pre-existing rapid-tap
/// integration test relies on this, asserting only "no crash"). Here
/// `cardRendererProvider` is overridden with a fake that writes to a real
/// `Directory.systemTemp` path (plain `dart:io`, no platform channel needed)
/// so the flow can actually reach `ShareTargetSheet` and this specific
/// guard can be exercised.
class _FakeCardRenderer implements CardRenderer {
  int renderCount = 0;

  @override
  Future<File?> renderToFile(GlobalKey boundaryKey, {double pixelRatio = 3}) async {
    renderCount++;
    final dir = await Directory.systemTemp.createTemp('share_sheet_test');
    final file = File('${dir.path}/share_card.png');
    await file.writeAsBytes(const <int>[0]);
    return file;
  }
}

/// Stubs a successful direct-intent tile share so the sheet dismisses via
/// the "launched OK" path rather than needing a real Android intent.
class _StubSocialShareService implements SocialShareService {
  @override
  Future<List<ShareTarget>> installedTargets() async => const <ShareTarget>[];

  @override
  Future<SocialShareResult> shareToStory({
    required ShareTarget target,
    required String stickerPath,
    required Color topColor,
    required Color bottomColor,
    String fbAppId = kFbAppId,
  }) async => const SocialShareResult(SocialShareOutcome.success);
}

/// Stubs a successful "More…" share so the existing "✓ Shared" toast path
/// can be exercised without a real `share_plus` platform channel.
class _StubShareService extends ShareService {
  const _StubShareService();

  @override
  Future<bool> shareFile(File file, {required String text}) async => true;
}

/// Same stub as above but counts invocations — needed to prove the
/// `_sharing` guard also blocks a rapid double-tap on the iOS/no-FB_APP_ID
/// direct-fallback branch (`_shareViaMoreSheet` called straight from
/// `_onShare`, never through `ShareTargetSheet`), not just the
/// sheet-stays-open branch the other rapid-double-tap test above exercises.
class _CountingShareService extends ShareService {
  int callCount = 0;

  @override
  Future<bool> shareFile(File file, {required String text}) async {
    callCount++;
    return true;
  }
}

void main() {
  RunSummary summary() {
    return RunSummary(
      outcome: RunOutcome.death,
      runNumber: 1,
      lifetimeDeaths: 1,
      peakLifePercent: 90,
      minLifePercent: 2,
      perfectCount: 0,
      playerName: 'Aman',
    );
  }

  Future<void> pumpResolvedCard(WidgetTester tester, _FakeCardRenderer fakeRenderer) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardRendererProvider.overrideWithValue(fakeRenderer),
          installedTargetsProvider.overrideWith((ref) async => const <ShareTarget>[]),
        ],
        child: MaterialApp(home: OutcomeCardScreen(summary: summary())),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// `CardRenderer.renderToFile` does genuine `dart:io` async work (even in
  /// the fake above) — under `flutter test`'s default zone that only pumps
  /// Flutter's own fake clock, a real async gap like `Directory.createTemp`/
  /// `File.writeAsBytes` never resolves unless the tap is wrapped in
  /// `tester.runAsync` (the standard `flutter_test` idiom for exercising
  /// genuine async IO from inside a widget test).
  Future<void> tapAndSettle(WidgetTester tester, Finder finder, {bool warnIfMissed = true}) async {
    await tester.runAsync(() async {
      await tester.tap(finder, warnIfMissed: warnIfMissed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('tapping Share renders exactly once and opens ShareTargetSheet', (tester) async {
    final fakeRenderer = _FakeCardRenderer();
    await pumpResolvedCard(tester, fakeRenderer);

    await tapAndSettle(tester, find.widgetWithText(StickerButton, 'Share'));

    expect(fakeRenderer.renderCount, 1);
    expect(find.byType(ShareTargetSheet), findsOneWidget);
  });

  testWidgets(
    'a rapid double-tap on Share opens exactly one ShareTargetSheet, not '
    'two, and renders the card exactly once — the single-render invariant '
    '(architecture §11) and the sheet-open guard (architecture §12 flag 4)',
    (tester) async {
      final fakeRenderer = _FakeCardRenderer();
      await pumpResolvedCard(tester, fakeRenderer);

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(StickerButton, 'Share'));
        await tester.tap(find.widgetWithText(StickerButton, 'Share'), warnIfMissed: false);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fakeRenderer.renderCount, 1, reason: 'single-render-per-Share-tap invariant');
      expect(find.byType(ShareTargetSheet), findsOneWidget, reason: 'must not stack a second sheet');
    },
  );

  testWidgets('trying multiple tiles from one open sheet does not re-render the card', (
    tester,
  ) async {
    final fakeRenderer = _FakeCardRenderer();
    await pumpResolvedCard(tester, fakeRenderer);

    await tapAndSettle(tester, find.widgetWithText(StickerButton, 'Share'));
    expect(fakeRenderer.renderCount, 1);

    // Every tile is dimmed here (installedTargetsProvider overridden to
    // empty, and Instagram/Facebook are always dimmed with no FB_APP_ID in
    // test runs) — tapping several just shows toasts, never re-renders.
    await tester.tap(find.text('Instagram'));
    await tester.pump();
    await tester.tap(find.text('WhatsApp'));
    await tester.pump();
    await tester.tap(find.text('Facebook'));
    await tester.pump();

    expect(fakeRenderer.renderCount, 1, reason: 'still exactly one render for the whole sheet session');
    expect(find.byType(ShareTargetSheet), findsOneWidget);
  });

  testWidgets(
    'a successful direct-tile share dismisses the sheet and NEVER shows the '
    '"✓ Shared" toast (code-reviewer flag — that toast is reserved '
    'exclusively for the "More…" path)',
    (tester) async {
      final fakeRenderer = _FakeCardRenderer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardRendererProvider.overrideWithValue(fakeRenderer),
            installedTargetsProvider.overrideWith(
              (ref) async => const <ShareTarget>[ShareTarget.whatsappStatus],
            ),
            socialShareServiceProvider.overrideWithValue(_StubSocialShareService()),
          ],
          child: MaterialApp(home: OutcomeCardScreen(summary: summary())),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      await tapAndSettle(tester, find.widgetWithText(StickerButton, 'Share'));
      expect(find.byType(ShareTargetSheet), findsOneWidget);

      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();

      expect(find.byType(ShareTargetSheet), findsNothing, reason: 'sheet must be dismissed');
      expect(find.text('✓ Shared'), findsNothing, reason: 'direct-tile share never shows this toast');
    },
  );

  testWidgets(
    'tapping "More…" still reaches the existing "✓ Shared" toast, unchanged',
    (tester) async {
      final fakeRenderer = _FakeCardRenderer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardRendererProvider.overrideWithValue(fakeRenderer),
            installedTargetsProvider.overrideWith((ref) async => const <ShareTarget>[]),
            shareServiceProvider.overrideWithValue(const _StubShareService()),
          ],
          child: MaterialApp(home: OutcomeCardScreen(summary: summary())),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      await tapAndSettle(tester, find.widgetWithText(StickerButton, 'Share'));
      expect(find.byType(ShareTargetSheet), findsOneWidget);

      // The outer `_onShare` continuation (the one that reacts to
      // `ShareSheetAction.more` and eventually calls `_showToast()`) is
      // still bound to `tapAndSettle`'s real `runAsync` zone from the
      // initial Share tap above — a plain fake-clock `pump()` here can
      // drive the sheet's own pop *animation*, but resuming that
      // real-zone continuation needs a genuine event-loop turn, hence
      // `runAsync` again here (same idiom as `tapAndSettle`).
      await tester.runAsync(() async {
        await tester.tap(find.text('More…'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ShareTargetSheet), findsNothing);
      expect(find.text('✓ Shared'), findsOneWidget, reason: 'the only path that shows this toast');
    },
  );

  testWidgets(
    'on iOS with no FB_APP_ID configured (the default — kFbAppId is empty '
    'in every `flutter test` run since no --dart-define is passed), Share '
    'skips the sheet entirely and falls straight back to the '
    '"More…"/share_plus path — code-reviewer regression coverage: with no '
    'App ID, Instagram/Facebook are dimmed AND WhatsApp is always dimmed '
    'on iOS, so all 3 tiles would be dead-ends were the sheet shown anyway',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final fakeRenderer = _FakeCardRenderer();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cardRendererProvider.overrideWithValue(fakeRenderer),
              shareServiceProvider.overrideWithValue(const _StubShareService()),
            ],
            child: MaterialApp(home: OutcomeCardScreen(summary: summary())),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 100));

        await tapAndSettle(tester, find.widgetWithText(StickerButton, 'Share'));

        expect(fakeRenderer.renderCount, 1);
        expect(
          find.byType(ShareTargetSheet),
          findsNothing,
          reason: 'no FB_APP_ID means every tile would be dead — must not show a dead-end sheet',
        );
        expect(
          find.text('✓ Shared'),
          findsOneWidget,
          reason: 'falls straight back to the working share_plus path, same as web',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'on iOS with no FB_APP_ID configured, a rapid double-tap on Share still '
    'renders the card exactly once and invokes the fallback share exactly '
    'once — proves the `_sharing` guard also covers the direct-fallback '
    'branch (which never opens ShareTargetSheet), not only the '
    'sheet-stays-open branch the other rapid-double-tap test exercises',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final fakeRenderer = _FakeCardRenderer();
        final countingShareService = _CountingShareService();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cardRendererProvider.overrideWithValue(fakeRenderer),
              shareServiceProvider.overrideWithValue(countingShareService),
            ],
            child: MaterialApp(home: OutcomeCardScreen(summary: summary())),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(StickerButton, 'Share'));
          await tester.tap(
            find.widgetWithText(StickerButton, 'Share'),
            warnIfMissed: false,
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          fakeRenderer.renderCount,
          1,
          reason: 'single-render invariant must hold on the fallback branch too',
        );
        expect(
          countingShareService.callCount,
          1,
          reason: '_sharing guard must block the second tap even though this branch never shows a sheet to gate on',
        );
        expect(find.text('✓ Shared'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'on Android, Share still reaches ShareTargetSheet even with no FB_APP_ID '
    'configured — unlike iOS, WhatsApp works there independent of the '
    'Facebook App ID, so Android is unaffected by this fix',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final fakeRenderer = _FakeCardRenderer();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cardRendererProvider.overrideWithValue(fakeRenderer),
              installedTargetsProvider.overrideWith((ref) async => const <ShareTarget>[]),
            ],
            child: MaterialApp(home: OutcomeCardScreen(summary: summary())),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 100));

        await tapAndSettle(tester, find.widgetWithText(StickerButton, 'Share'));

        expect(fakeRenderer.renderCount, 1);
        expect(find.byType(ShareTargetSheet), findsOneWidget, reason: 'Android always reaches the sheet');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'an unexpected error from installedTargetsProvider is caught, not left '
    'to escape silently — the sheet still opens with everything falling '
    'back to dimmed (architecture §12 flag "unguarded await")',
    (tester) async {
      final fakeRenderer = _FakeCardRenderer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardRendererProvider.overrideWithValue(fakeRenderer),
            installedTargetsProvider.overrideWith(
              (ref) async => throw StateError('simulated unexpected probe failure'),
            ),
          ],
          child: MaterialApp(home: OutcomeCardScreen(summary: summary())),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      await tapAndSettle(tester, find.widgetWithText(StickerButton, 'Share'));

      expect(tester.takeException(), isNull, reason: 'the error must not escape uncaught');
      expect(find.byType(ShareTargetSheet), findsOneWidget, reason: 'sheet still opens');
      // Every tile falls back to dimmed (empty installedTargets) rather than
      // the Share tap silently doing nothing.
      await tester.tap(find.text('WhatsApp'));
      await tester.pump();
      expect(find.text("WhatsApp isn't installed"), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Share button again while the sheet is already open is a '
    'no-op — cannot stack a second sheet (architecture §12 flag 4, exercised '
    'after the sheet has fully settled, not just during the render race)',
    (tester) async {
      final fakeRenderer = _FakeCardRenderer();
      await pumpResolvedCard(tester, fakeRenderer);

      await tapAndSettle(tester, find.widgetWithText(StickerButton, 'Share'));
      expect(find.byType(ShareTargetSheet), findsOneWidget);

      // The Share button sits underneath the modal barrier now; attempting
      // to tap it again must not reach a second `_onShare` invocation
      // (either because the barrier itself blocks the hit-test, or because
      // `_sharing` — which now spans the whole "sheet is open" duration —
      // would block it even if it somehow did).
      await tester.tap(find.widgetWithText(StickerButton, 'Share'), warnIfMissed: false);
      await tester.pump();

      expect(fakeRenderer.renderCount, 1, reason: 'no second render triggered');
      expect(find.byType(ShareTargetSheet), findsOneWidget, reason: 'still exactly one sheet');
    },
  );
}
