import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/ads/domain/ad_config.dart';
import 'package:timing_tap/features/ads/presentation/banner_ad_slot.dart';

/// `BannerAdSlot` (real-ad-serving pass, game-ux-designer spec): a fixed
/// 54dp footer strip that must ALWAYS be reserved — never
/// `SizedBox.shrink()` — regardless of ad-network state. This suite runs
/// with no `--dart-define`, so `kAppLovinBannerUnitId` is empty and the
/// slot always renders its permanent empty placeholder (the realistic
/// default-build path); the unconfigured placeholder is exactly what's
/// testable without a mocked ad SDK platform channel.
///
/// Wrapped in a `ProviderScope`: `BannerAdSlot` is now a `ConsumerWidget`
/// (it reads `adSdkReadyProvider` in the configured branch — real-ad-
/// serving pass review, fix 6), so it needs a `ProviderScope` ancestor even
/// though this suite's unconfigured path never actually reaches that read.
void main() {
  Future<void> pumpSlot(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: BannerAdSlot())),
        ),
      ),
    );
  }

  testWidgets(
    'renders the fixed-height placeholder (never zero-height) when unconfigured',
    (tester) async {
      expect(kAppLovinBannerUnitId, isEmpty, reason: 'no --dart-define in this test run');

      await pumpSlot(tester);

      final size = tester.getSize(find.byType(BannerAdSlot));
      expect(size.height, BannerAdSlot.kHeight);
      expect(size.height, isNot(0));
    },
  );

  testWidgets(
    'the unconfigured placeholder is wrapped in ExcludeSemantics (mirrors '
    'AdFailedView\'s convention — nothing for a screen reader to announce)',
    (tester) async {
      await pumpSlot(tester);

      expect(
        find.descendant(of: find.byType(BannerAdSlot), matching: find.byType(ExcludeSemantics)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'REGRESSION: no MaxAdView is ever mounted when unconfigured — not just '
    '"BannerAdSlot itself builds without crashing"',
    (tester) async {
      await pumpSlot(tester);

      expect(find.byType(MaxAdView), findsNothing);
    },
  );

  testWidgets(
    'the placeholder is flat chrome — a plain paper2-filled DecoratedBox '
    'with only the top hairline BorderSide, no decorative border on any '
    'other edge (matches the "flat, no border" spec, unlike this app\'s '
    'sticker-book button/card chrome elsewhere)',
    (tester) async {
      await pumpSlot(tester);

      final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.border, isA<Border>());
      final border = decoration.border! as Border;
      expect(border.top.width, 1, reason: 'the one hairline divider the spec calls for');
      expect(border.left, BorderSide.none);
      expect(border.right, BorderSide.none);
      expect(border.bottom, BorderSide.none);
      expect(
        decoration.boxShadow,
        anyOf(isNull, isEmpty),
        reason: 'no sticker-book drop-shadow chrome on this flat footer slot',
      );
    },
  );

  testWidgets(
    'REGRESSION: rapidly toggling isVisible when unconfigured is purely a '
    'Dart-side flag flip — never mounts a MaxAdView and never crashes, '
    'since `configured` (gating whether any native banner exists at all) '
    'is independent of `isVisible`',
    (tester) async {
      Future<void> pumpWithVisibility(bool visible) => tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: BannerAdSlot(isVisible: visible),
              ),
            ),
          ),
        ),
      );

      await pumpWithVisibility(true);
      // Simulate quick navigation in/out of Home several times in a row.
      for (var i = 0; i < 5; i++) {
        await pumpWithVisibility(false);
        await pumpWithVisibility(true);
      }

      expect(find.byType(MaxAdView), findsNothing);
      final size = tester.getSize(find.byType(BannerAdSlot));
      expect(size.height, BannerAdSlot.kHeight, reason: 'the reserved slot size never changes with isVisible');
    },
  );
}
