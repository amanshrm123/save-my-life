import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/sharing/application/social_share_service.dart';
import 'package:timing_tap/features/sharing/domain/share_target.dart';
import 'package:timing_tap/features/sharing/presentation/share_target_sheet.dart';
import 'package:timing_tap/features/sharing/state/share_providers.dart';

/// Widget coverage for `ShareTargetSheet` (design share-target-sheet-v1,
/// architecture v5 §4/§7/§8) — real Android intents can't fire under
/// `flutter test`, so `SocialShareService` is stubbed with a fixed
/// `SocialShareResult` per test, matching the tester-stage scope this
/// feature is limited to.
class _StubSocialShareService implements SocialShareService {
  _StubSocialShareService(this._result);

  final SocialShareResult _result;
  int callCount = 0;
  ShareTarget? lastTarget;

  @override
  Future<List<ShareTarget>> installedTargets() async => const <ShareTarget>[];

  @override
  Future<SocialShareResult> shareToStory({
    required ShareTarget target,
    required String stickerPath,
    required Color topColor,
    required Color bottomColor,
    String fbAppId = kFbAppId,
  }) async {
    callCount++;
    lastTarget = target;
    return _result;
  }
}

/// Lets a test control exactly when `shareToStory` resolves, to simulate the
/// P1 race condition (code-reviewer flag): a tile tap followed by a scrim
/// dismiss BEFORE the native call resolves.
class _CompleterSocialShareService implements SocialShareService {
  _CompleterSocialShareService(this._completer);

  final Completer<SocialShareResult> _completer;

  @override
  Future<List<ShareTarget>> installedTargets() async => const <ShareTarget>[];

  @override
  Future<SocialShareResult> shareToStory({
    required ShareTarget target,
    required String stickerPath,
    required Color topColor,
    required Color bottomColor,
    String fbAppId = kFbAppId,
  }) => _completer.future;
}

void main() {
  ShareSheetAction? lastResult;
  bool sheetSettled = false;

  Future<void> openSheet(
    WidgetTester tester, {
    required List<ShareTarget> installedTargets,
    List<Override> overrides = const [],
  }) async {
    lastResult = null;
    sheetSettled = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                lastResult = await showShareTargetSheet(
                  context,
                  cardFile: File('/tmp/share/share_card.png'),
                  outcome: RunOutcome.death,
                  installedTargets: installedTargets,
                );
                sheetSettled = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders exactly 3 tiles, in order, with the correct two-line labels',
    (tester) async {
      await openSheet(tester, installedTargets: const []);

      expect(find.text('Share your card'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Story'), findsNWidgets(2));
      expect(find.text('More…'), findsOneWidget);

      // Order: Instagram -> WhatsApp -> Facebook (architecture §4).
      final igCenter = tester.getCenter(find.text('Instagram'));
      final waCenter = tester.getCenter(find.text('WhatsApp'));
      final fbCenter = tester.getCenter(find.text('Facebook'));
      expect(igCenter.dx, lessThan(waCenter.dx));
      expect(waCenter.dx, lessThan(fbCenter.dx));
    },
  );

  testWidgets(
    'a dimmed tile (Instagram, always dimmed with no FB_APP_ID in test runs) '
    'is still tappable, shows the "isn\'t installed" toast, and does NOT '
    'dismiss the sheet',
    (tester) async {
      await openSheet(tester, installedTargets: const []);

      await tester.tap(find.text('Instagram'));
      await tester.pump();

      expect(find.text("Instagram isn't installed"), findsOneWidget);
      expect(
        find.byType(ShareTargetSheet),
        findsOneWidget,
        reason: 'sheet must stay open',
      );
      expect(sheetSettled, isFalse);
    },
  );

  testWidgets(
    'a successful direct-intent tap (WhatsApp, installed, no App ID needed) '
    'dismisses the sheet immediately with no toast',
    (tester) async {
      final stub = _StubSocialShareService(
        const SocialShareResult(SocialShareOutcome.success),
      );
      await openSheet(
        tester,
        installedTargets: const [ShareTarget.whatsappStatus],
        overrides: [socialShareServiceProvider.overrideWithValue(stub)],
      );

      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();

      expect(stub.callCount, 1);
      expect(stub.lastTarget, ShareTarget.whatsappStatus);
      expect(
        find.byType(ShareTargetSheet),
        findsNothing,
        reason: 'sheet must be dismissed',
      );
      expect(
        find.textContaining('Shared'),
        findsNothing,
        reason: 'no "✓ Shared" on a direct-intent path',
      );
      expect(sheetSettled, isTrue);
      expect(
        lastResult,
        isNull,
        reason: 'a tile dismiss carries no ShareSheetAction, unlike More…',
      );
    },
  );

  testWidgets(
    'a failed direct-intent tap (activityNotFound) shows "Couldn\'t open X" '
    'and keeps the sheet open so the player can try another tile',
    (tester) async {
      final stub = _StubSocialShareService(
        const SocialShareResult(SocialShareOutcome.activityNotFound),
      );
      await openSheet(
        tester,
        installedTargets: const [ShareTarget.whatsappStatus],
        overrides: [socialShareServiceProvider.overrideWithValue(stub)],
      );

      await tester.tap(find.text('WhatsApp'));
      await tester.pump();

      expect(find.text("Couldn't open WhatsApp"), findsOneWidget);
      expect(find.byType(ShareTargetSheet), findsOneWidget);
      expect(sheetSettled, isFalse);
    },
  );

  testWidgets(
    '"More…" dismisses the sheet and resolves with ShareSheetAction.more',
    (tester) async {
      await openSheet(tester, installedTargets: const []);

      await tester.tap(find.text('More…'));
      await tester.pumpAndSettle();

      expect(find.byType(ShareTargetSheet), findsNothing);
      expect(sheetSettled, isTrue);
      expect(lastResult, ShareSheetAction.more);
    },
  );

  testWidgets(
    'sheet root is bottom-anchored via Align(bottomCenter), never a Center '
    '(regression for the "used to render mid-screen" bug, design §2/§3)',
    (tester) async {
      await openSheet(tester, installedTargets: const []);

      // Several unrelated internal `Align`s exist below the sheet root (e.g.
      // from `CustomPaint`'s own layout machinery for the brand glyphs) —
      // the load-bearing one is specifically the `bottomCenter` one; assert
      // there is exactly one of those, not that there's only one Align at
      // all.
      final bottomCenterAlignFinder = find.descendant(
        of: find.byType(ShareTargetSheet),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Align && widget.alignment == Alignment.bottomCenter,
        ),
      );
      expect(
        bottomCenterAlignFinder,
        findsOneWidget,
        reason: 'exactly one Align(bottomCenter), the sheet root',
      );

      expect(
        find.descendant(
          of: find.byType(ShareTargetSheet),
          matching: find.byType(Center),
        ),
        findsNothing,
        reason:
            'a bare Center would expand to fill the unbounded isScrollControlled height '
            'and float the panel mid-screen instead of flush against the bottom',
      );

      // `ShareTargetSheet`'s own root is now a full-screen `Stack` (the
      // scrim-dismiss fix) — its `RenderBox` always spans the whole screen
      // regardless of where the visible panel sits, so measuring against
      // `find.byType(ShareTargetSheet)` would be trivially satisfied even if
      // the panel itself regressed to floating mid-screen. Measure the
      // actual visible panel `Container` (identified by
      // `_ShareTargetSheetState.panelKey`) instead.
      final sheetBottom = tester
          .getBottomLeft(find.byKey(ShareTargetSheet.panelKey))
          .dy;
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(sheetBottom, closeTo(screenHeight, 0.5));
    },
  );

  testWidgets(
    'REGRESSION: tapping the scrim (well outside the panel bounds) pops the '
    "sheet's own route via maybePop, even though its render box spans the "
    'full screen',
    (tester) async {
      await openSheet(tester, installedTargets: const []);
      expect(find.byType(ShareTargetSheet), findsOneWidget);

      // The panel sits at the bottom of the screen; tapping near the top
      // (well above the panel's own bounds) must land on the scrim
      // GestureDetector, not the panel content, and dismiss the sheet.
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      expect(
        find.byType(ShareTargetSheet),
        findsNothing,
        reason: 'scrim tap must dismiss the sheet',
      );
      expect(sheetSettled, isTrue);
      expect(
        lastResult,
        isNull,
        reason: 'a scrim dismiss carries no ShareSheetAction',
      );
    },
  );

  testWidgets(
    'an error toast overlays the sheet without shifting the tile row / '
    '"More…" link (Positioned overlay, not a Column child — regression for '
    'the "toast used to resize the panel" bug, design §8.2)',
    (tester) async {
      await openSheet(tester, installedTargets: const []);

      final moreBefore = tester.getTopLeft(find.text('More…'));
      final rowBefore = tester.getTopLeft(find.text('Instagram'));

      await tester.tap(find.text('Instagram'));
      await tester.pump();
      expect(find.text("Instagram isn't installed"), findsOneWidget);

      final moreAfter = tester.getTopLeft(find.text('More…'));
      final rowAfter = tester.getTopLeft(find.text('Instagram'));
      expect(
        moreAfter,
        moreBefore,
        reason: 'the toast appearing must not move the "More…" link',
      );
      expect(
        rowAfter,
        rowBefore,
        reason: 'the toast appearing must not move the tile row',
      );

      // And it clears again with no lingering shift once it auto-dismisses.
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text("Instagram isn't installed"), findsNothing);
      expect(tester.getTopLeft(find.text('More…')), moreBefore);
    },
  );

  testWidgets(
    'tapping a tile again while the sheet is already open (post-settle) '
    'never stacks a second sheet',
    (tester) async {
      final stub = _StubSocialShareService(
        const SocialShareResult(SocialShareOutcome.success),
      );
      await openSheet(
        tester,
        installedTargets: const [ShareTarget.whatsappStatus],
        overrides: [socialShareServiceProvider.overrideWithValue(stub)],
      );
      expect(find.byType(ShareTargetSheet), findsOneWidget);

      // Simulate a rapid double-tap landing on the same tile before the
      // first `shareToStory` call resolves — `_dispatching` in
      // `_ShareTargetSheetState` must block the second call from firing a
      // second overlapping native invocation, and there is still only ever
      // one sheet instance regardless. Sequential (not concurrent) `tap()`
      // calls, matching the idiom the existing rapid-double-tap-on-Share
      // test uses — `_dispatching` is set synchronously before the first
      // tap's `await`, so the second tap's hit-test still lands on the
      // (not-yet-dismissed) tile underneath.
      await tester.tap(find.text('WhatsApp'));
      await tester.tap(find.text('WhatsApp'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        stub.callCount,
        1,
        reason: 'the in-flight guard must prevent a second native call',
      );
      expect(
        find.byType(ShareTargetSheet),
        findsNothing,
        reason: 'exactly one sheet resolved once',
      );
    },
  );

  testWidgets(
    'P1 REGRESSION: a tile share that resolves successfully AFTER the sheet '
    'has already started exiting (scrim tap fired first) must NOT pop the '
    "underlying route — guarded on this sheet's own route still being "
    'current, not just on `mounted`',
    (tester) async {
      final completer = Completer<SocialShareResult>();
      final stub = _CompleterSocialShareService(completer);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [socialShareServiceProvider.overrideWithValue(stub)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (innerContext) => Scaffold(
                          body: Center(
                            child: ElevatedButton(
                              onPressed: () => showShareTargetSheet(
                                innerContext,
                                cardFile: File('/tmp/share/share_card.png'),
                                outcome: RunOutcome.death,
                                installedTargets: const [
                                  ShareTarget.whatsappStatus,
                                ],
                              ),
                              child: const Text('open sheet'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('push page2'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('push page2'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      expect(find.byType(ShareTargetSheet), findsOneWidget);

      // Tap a tile — `_onTileTap` starts and awaits the (deliberately
      // never-completing-yet) `shareToStory` call.
      await tester.tap(find.text('WhatsApp'));
      await tester.pump();

      // Before that resolves, the player taps the scrim: the sheet's route
      // starts popping (exit animation in flight), but its State is not
      // disposed yet — `mounted` alone would still read `true` here.
      await tester.tapAt(const Offset(200, 20));
      await tester.pump(const Duration(milliseconds: 50));

      // Now the in-flight tile share resolves as successful, while the
      // sheet is mid-exit and no longer the current route.
      completer.complete(const SocialShareResult(SocialShareOutcome.success));
      await tester.pump();
      await tester.pumpAndSettle();

      // The unguarded bug would call `Navigator.of(context).pop()`
      // unconditionally here, popping page2 (the current route at that
      // point) and kicking the player back to page1 unexpectedly. The fix
      // must leave page2 exactly where it was.
      expect(
        find.text('open sheet'),
        findsOneWidget,
        reason:
            'page2 must still be on screen — the guarded pop must not fire for a non-current route',
      );
      expect(
        find.text('push page2'),
        findsNothing,
        reason: 'must not have been kicked back to page1',
      );
    },
  );
}
