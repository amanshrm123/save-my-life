import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/theme/app_theme.dart';
import 'package:timing_tap/features/outcome/domain/death_beats.dart';
import 'package:timing_tap/features/outcome/domain/eternal_beats.dart';
import 'package:timing_tap/features/outcome/domain/outcome_story_content.dart';
import 'package:timing_tap/features/outcome/domain/story_beat.dart';
import 'package:timing_tap/features/outcome/domain/story_icons.dart';
import 'package:timing_tap/features/outcome/domain/survived_beats.dart';
import 'package:timing_tap/features/outcome/presentation/widgets/card_footer.dart';
import 'package:timing_tap/features/outcome/presentation/widgets/outcome_card.dart';
import 'package:timing_tap/features/outcome/presentation/widgets/outcome_card_shell.dart';
import 'package:timing_tap/features/outcome/presentation/widgets/outcome_chip.dart';
import 'package:timing_tap/features/outcome/presentation/widgets/store_badges.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';

/// Widget-level regression coverage for the redesigned outcome-card widgets
/// (design v1 / architecture v4), pinning specifically the bugs a
/// code-review + fix pass found and fixed this session:
///   1. The "N/AAman" name-concatenation bug in `_StoryBlock._storyText`.
///   2. A content-length-dependent `RenderFlex` overflow in the card's
///      middle region / footer / store badges / chip, now guarded by
///      `FittedBox(scaleDown)` + a `TextScaler.noScaling` clamp at the
///      shell level.
///   3. Eternal's `BoxDecoration.gradient` (not `.color`) card fill.
///
/// Generic happy-path rendering is intentionally NOT re-litigated here in
/// detail — these tests target the specific regressions above.
void main() {
  /// Wraps [child] the way `OutcomeCardShell`'s own `builder` callback is
  /// always used in production: inside a bounded box (so `AspectRatio`/
  /// `LayoutBuilder` can resolve `k`), inside a `MaterialApp` for `Directionality`
  /// + text styling. [width] simulates the box `OutcomeCardShell` would give
  /// its content at a given `k` (250dp == k=1, the mockup's own reference
  /// width, per design v1 §2.2).
  Widget harness(
    Widget child, {
    double width = 250,
    double ambientTextScale = 1.0,
  }) {
    return MaterialApp(
      builder: (context, builtChild) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(ambientTextScale)),
          child: builtChild!,
        );
      },
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  /// Collects the plain text of every `Text`/`Text.rich` widget currently in
  /// the tree, for content assertions that need to inspect *all* rendered
  /// strings (not just a single `find.text` match).
  List<String> allRenderedText(WidgetTester tester) {
    final out = <String>[];
    for (final widget in tester.widgetList<Text>(find.byType(Text))) {
      if (widget.data != null) {
        out.add(widget.data!);
      } else if (widget.textSpan != null) {
        out.add(widget.textSpan!.toPlainText());
      }
    }
    return out;
  }

  group(
    'REGRESSION: "N/AAman" name-concatenation bug (_StoryBlock._storyText)',
    () {
      for (final outcome in RunOutcome.values) {
        testWidgets(
          '$outcome: a forced N/A card with a non-empty playerName never '
          'concatenates the name onto the literal fallback text',
          (tester) async {
            await tester.pumpWidget(
              harness(
                OutcomeCard(
                  outcome: outcome,
                  playerName: 'Aman',
                  content: OutcomeStoryContent.naFor,
                ),
              ),
            );
            await tester.pump();

            expect(tester.takeException(), isNull);

            final texts = allRenderedText(tester);
            for (final text in texts) {
              expect(
                text,
                isNot(contains('Aman')),
                reason:
                    'no rendered text should contain the player name when the card is '
                    'the N/A fallback — found: "$text"',
              );
              expect(
                text,
                isNot(equals('N/AAman')),
                reason:
                    'the exact garbled-concatenation regression this test pins',
              );
            }
            // The literal 'N/A' fallback text must still render somewhere
            // (headline and/or story) — not silently disappear.
            expect(texts, contains('N/A'));
          },
        );
      }

      testWidgets(
        'an anonymous (empty playerName) forced N/A card also renders plain '
        '"N/A" with nothing appended',
        (tester) async {
          await tester.pumpWidget(
            harness(
              const OutcomeCard(
                outcome: RunOutcome.death,
                playerName: '',
                content: OutcomeStoryContent.naFor,
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(allRenderedText(tester), contains('N/A'));
        },
      );
    },
  );

  group('REGRESSION: layout overflow — longest pooled content per tier, at '
      'k~1, default AND inflated ambient text scale', () {
    // The exact longest entries in each pool (by combined headline+named
    // length), found by direct inspection of death_beats.dart /
    // survived_beats.dart / eternal_beats.dart — the fix pass found this
    // was a probabilistic/content-length-dependent failure, so generic
    // short test copy would not have caught it.
    final longestDeath = deathBeats.firstWhere(
      (b) => b.headline == 'Confidence wrote a bad check.',
    );
    final longestSurvived = survivedBeats.firstWhere(
      (b) => b.headline == "Didn't blink at sudden death.",
    );
    final longestEternal = eternalBeats.firstWhere(
      (b) => b.headline == 'Beat the clock before it knew.',
    );

    OutcomeStoryContent contentFor(StoryBeat beat, String icon) {
      return OutcomeStoryContent(
        headline: beat.headline,
        storyNamed: beat.named,
        storyAnonymous: beat.anonymous,
        icon: icon,
        isFallback: false,
      );
    }

    final cases = <String, (RunOutcome, StoryBeat, String)>{
      'death': (RunOutcome.death, longestDeath, deathIcons.last),
      'survived': (RunOutcome.survived, longestSurvived, survivedIcons.first),
      'eternal': (RunOutcome.eternal, longestEternal, eternalIcons.first),
    };

    // 12 chars is this app's actual max player-name length
    // (`NameValidator.maxLength`), used here as the worst-case stress name
    // rather than a short placeholder.
    const longName = 'Alexandriaaa';

    for (final entry in cases.entries) {
      final (outcome, beat, icon) = entry.value;

      testWidgets(
        '${entry.key}: longest beat + max-length name renders with no '
        'overflow at default text scale',
        (tester) async {
          await tester.pumpWidget(
            harness(
              OutcomeCard(
                outcome: outcome,
                playerName: longName,
                content: contentFor(beat, icon),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '${entry.key}: longest beat + max-length name renders with no '
        'overflow even when the ambient MediaQuery requests a large text '
        'scale (Android "Larger text", ~1.3x) — confirms TextScaler.noScaling '
        'inside OutcomeCardShell actually holds',
        (tester) async {
          await tester.pumpWidget(
            harness(
              OutcomeCard(
                outcome: outcome,
                playerName: longName,
                content: contentFor(beat, icon),
              ),
              ambientTextScale: 1.3,
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '${entry.key}: still no overflow at an extreme 2.0x ambient text '
        'scale (well beyond any real device accessibility setting, as a '
        'hard stress test of the clamp)',
        (tester) async {
          await tester.pumpWidget(
            harness(
              OutcomeCard(
                outcome: outcome,
                playerName: longName,
                content: contentFor(beat, icon),
              ),
              ambientTextScale: 2.0,
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '${entry.key}: also holds on a narrower device width (k < 1)',
        (tester) async {
          await tester.pumpWidget(
            harness(
              OutcomeCard(
                outcome: outcome,
                playerName: longName,
                content: contentFor(beat, icon),
              ),
              width: 200,
              ambientTextScale: 1.3,
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('REGRESSION: individual footer/badge/chip components never overflow '
      'standalone at the card\'s real k=1 content width (206dp)', () {
    // 250 (reference card width) - 22*2 (horizontal padding) = 206, per
    // design v1 §2.2 / the widgets' own doc comments on their near-zero
    // horizontal headroom at k=1.
    const contentWidth = 206.0;

    for (final palette in [
      ('death', OutcomeTierPalette.death),
      ('survived', OutcomeTierPalette.survived),
      ('eternal', OutcomeTierPalette.eternal),
    ]) {
      final (label, tierPalette) = palette;

      testWidgets('$label: CardFooter does not overflow at k=1 width', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(
            CardFooter(palette: tierPalette, k: 1.0),
            width: contentWidth,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('$label: StoreBadges does not overflow at k=1 width', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(
            StoreBadges(color: tierPalette.baseText, k: 1.0),
            width: contentWidth,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('$label: OutcomeChip does not overflow with the longest '
          'real chip label (Eternal\'s) at k=1, unbounded width', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(
            OutcomeChip(
              label: OutcomeTierPalette.eternal.chipLabel,
              fill: tierPalette.chipFill,
              textColor: tierPalette.chipText,
              k: 1.0,
            ),
            width: contentWidth,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('REGRESSION: OutcomeCardShell uses the redesigned 3:4 silhouette '
      '(design v1 Revision 5 §R5.1 — supersedes Revision 4\'s 6:7, which '
      'superseded Revision 3\'s 4:5, itself supersedes Revision 2\'s 3:4, '
      'itself supersedes the original 9:16)', () {
    testWidgets(
      'the actual rendered AspectRatio widget is 3/4, not 4/5, 6/7, or 9/16',
      (tester) async {
        await tester.pumpWidget(
          harness(
            OutcomeCardShell(
              palette: OutcomeTierPalette.death,
              builder: (context, k) => const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pump();

        final aspectRatio = tester.widget<AspectRatio>(
          find.byType(AspectRatio),
        );
        expect(aspectRatio.aspectRatio, 3 / 4);
        expect(aspectRatio.aspectRatio, isNot(4 / 5));
        expect(aspectRatio.aspectRatio, isNot(6 / 7));
        expect(aspectRatio.aspectRatio, isNot(9 / 16));
      },
    );
  });

  group('REGRESSION: OutcomeCard story block is top-anchored, not centered '
      '(design v1 Revision 3 §R3.2 — fixes the "two dead zones" empty-gap '
      'bug on short-content runs)', () {
    testWidgets(
      'the Expanded middle region wraps an Align(topCenter), not a Center',
      (tester) async {
        await tester.pumpWidget(
          harness(
            const OutcomeCard(
              outcome: RunOutcome.death,
              playerName: 'Aman',
              content: OutcomeStoryContent.naFor,
            ),
          ),
        );
        await tester.pump();

        // `find.byType(Expanded)` only matches the card's own middle region
        // here — the `harness` wrapper uses `Center`/`SizedBox`, not
        // `Expanded`, so there's no ambiguity with an outer widget.
        final expanded = tester.widget<Expanded>(find.byType(Expanded));
        expect(expanded.child, isA<Align>());
        final align = expanded.child as Align;
        expect(align.alignment, Alignment.topCenter);

        // The card's own subtree (everything under `OutcomeCard`) must not
        // contain a `Center` any more — the `harness` wrapper's own `Center`
        // (outside `OutcomeCard`) is intentionally excluded via `descendantOf`.
        expect(
          find.descendant(
            of: find.byType(OutcomeCard),
            matching: find.byType(Center),
          ),
          findsNothing,
        );
      },
    );
  });

  group('REGRESSION: per-tier nameSpan color tokens (design v1 name-span '
      'revision) point at the new dedicated AppColors constants, not a '
      'generic reused color', () {
    test(
      'OutcomeTierPalette.survived.nameSpan == AppColors.surviveNameSpan',
      () {
        expect(OutcomeTierPalette.survived.nameSpan, AppColors.surviveNameSpan);
      },
    );

    test(
      'OutcomeTierPalette.eternal.nameSpan == AppColors.eternalNameSpan',
      () {
        expect(OutcomeTierPalette.eternal.nameSpan, AppColors.eternalNameSpan);
      },
    );
  });

  group('REGRESSION-END-TO-END: the new nameSpan color tokens actually reach '
      'the rendered TextSpan for the named player, not just the palette '
      'mapping in isolation', () {
    /// Finds every [TextSpan] whose literal `.text` equals [text] among all
    /// currently-rendered `Text`/`Text.rich` widgets, returning the styles
    /// actually applied to it (there should be exactly one).
    List<TextStyle?> nameSpanStyles(WidgetTester tester, String text) {
      final styles = <TextStyle?>[];
      for (final widget in tester.widgetList<Text>(find.byType(Text))) {
        final span = widget.textSpan;
        if (span == null) continue;
        span.visitChildren((child) {
          if (child is TextSpan && child.text == text) {
            styles.add(child.style);
          }
          return true;
        });
      }
      return styles;
    }

    testWidgets('Survived: a non-empty playerName renders with '
        'AppColors.surviveNameSpan (at the story block\'s 0.85 opacity), not '
        'the old reused AppColors.greenDark', (tester) async {
      final beat = survivedBeats.first;
      await tester.pumpWidget(
        harness(
          OutcomeCard(
            outcome: RunOutcome.survived,
            playerName: 'Aman',
            content: OutcomeStoryContent(
              headline: beat.headline,
              storyNamed: beat.named,
              storyAnonymous: beat.anonymous,
              icon: survivedIcons.first,
              isFallback: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final styles = nameSpanStyles(tester, 'Aman');
      expect(
        styles,
        hasLength(1),
        reason: 'exactly one name span for the player name',
      );
      expect(
        styles.single?.color,
        AppColors.surviveNameSpan.withValues(alpha: 0.85),
      );
      expect(
        styles.single?.color,
        isNot(AppColors.greenDark.withValues(alpha: 0.85)),
      );
    });

    testWidgets('Eternal: a non-empty playerName renders with '
        'AppColors.eternalNameSpan (at the story block\'s 0.85 opacity), not '
        'the old reused AppColors.eternalNo', (tester) async {
      final beat = eternalBeats.first;
      await tester.pumpWidget(
        harness(
          OutcomeCard(
            outcome: RunOutcome.eternal,
            playerName: 'Aman',
            content: OutcomeStoryContent(
              headline: beat.headline,
              storyNamed: beat.named,
              storyAnonymous: beat.anonymous,
              icon: eternalIcons.first,
              isFallback: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final styles = nameSpanStyles(tester, 'Aman');
      expect(
        styles,
        hasLength(1),
        reason: 'exactly one name span for the player name',
      );
      expect(
        styles.single?.color,
        AppColors.eternalNameSpan.withValues(alpha: 0.85),
      );
      expect(
        styles.single?.color,
        isNot(AppColors.eternalNo.withValues(alpha: 0.85)),
      );
    });

    testWidgets(
      'Death: a non-empty playerName renders with the unchanged '
      "AppColors.deathNameSpan-equivalent color (Death's name-span color "
      'was NOT part of this revision) — sanity check nothing regressed here',
      (tester) async {
        final beat = deathBeats.first;
        await tester.pumpWidget(
          harness(
            OutcomeCard(
              outcome: RunOutcome.death,
              playerName: 'Aman',
              content: OutcomeStoryContent(
                headline: beat.headline,
                storyNamed: beat.named,
                storyAnonymous: beat.anonymous,
                icon: deathIcons.first,
                isFallback: false,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final styles = nameSpanStyles(tester, 'Aman');
        expect(
          styles,
          hasLength(1),
          reason: 'exactly one name span for the player name',
        );
        expect(
          styles.single?.color,
          OutcomeTierPalette.death.nameSpan.withValues(alpha: 0.85),
        );
      },
    );

    for (final entry in [
      ('death', RunOutcome.death, deathBeats.first, deathIcons.first),
      (
        'survived',
        RunOutcome.survived,
        survivedBeats.first,
        survivedIcons.first,
      ),
      ('eternal', RunOutcome.eternal, eternalBeats.first, eternalIcons.first),
    ]) {
      final (label, outcome, beat, icon) = entry;
      testWidgets(
        '$label: an anonymous (empty playerName) card renders the plain '
        'anonymous copy with NO name-colored span at all',
        (tester) async {
          await tester.pumpWidget(
            harness(
              OutcomeCard(
                outcome: outcome,
                playerName: '',
                content: OutcomeStoryContent(
                  headline: beat.headline,
                  storyNamed: beat.named,
                  storyAnonymous: beat.anonymous,
                  icon: icon,
                  isFallback: false,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          // The story block's own anonymous branch renders a bare
          // `Text(content.storyAnonymous)` (no `Text.rich`/name span at
          // all) — but other widgets in the card (e.g. `CardFooter`'s
          // wordmark) legitimately use their own unrelated `TextSpan`
          // children, so scope this to "nothing carries this tier's
          // name-span color", not "no TextSpan children anywhere".
          final tierNameColor = OutcomeTierPalette.of(
            outcome,
          ).nameSpan.withValues(alpha: 0.85);
          for (final widget in tester.widgetList<Text>(find.byType(Text))) {
            final span = widget.textSpan;
            if (span is! TextSpan) continue;
            for (final child in span.children ?? const <InlineSpan>[]) {
              expect(
                child.style?.color,
                isNot(tierNameColor),
                reason:
                    'no span should carry the name-span color when playerName is empty',
              );
            }
          }
          expect(
            find.text(beat.anonymous),
            findsOneWidget,
            reason: 'the anonymous copy itself must still render plainly',
          );
        },
      );
    }
  });

  group('NEW: story floor rule (design v1 Revision 4 §R4.2) — a quiet, '
      'always-rendered decorative rule directly below the story block, '
      'inside the same FittedBox scale-safety unit', () {
    for (final entry in [
      ('death', RunOutcome.death),
      ('survived', RunOutcome.survived),
      ('eternal', RunOutcome.eternal),
    ]) {
      final (label, outcome) = entry;

      testWidgets(
        '$label: the FittedBox wraps a min-sized, left-aligned Column of '
        '[_StoryBlock, 10dp gap, floor-rule Container] — not _StoryBlock '
        'alone',
        (tester) async {
          await tester.pumpWidget(
            harness(
              OutcomeCard(
                outcome: outcome,
                playerName: 'Aman',
                content: OutcomeStoryContent.naFor,
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);

          final align = tester.widget<Align>(find.byType(Align));
          expect(align.alignment, Alignment.topCenter);

          final fittedBox = align.child as FittedBox;
          // The `FittedBox`'s direct child is now a width-bounded `SizedBox`
          // (P0 fix: bounds the text's width so it actually wraps instead of
          // laying out as one unbounded-width line), wrapping the same
          // min-sized Column as before.
          final sizedBox = fittedBox.child as SizedBox;
          expect(
            sizedBox.width,
            206.0,
            reason: 'k=1 at the harness\'s default 250dp reference width',
          );
          final column = sizedBox.child as Column;
          expect(column.mainAxisSize, MainAxisSize.min);
          expect(column.crossAxisAlignment, CrossAxisAlignment.start);
          expect(
            column.children,
            hasLength(3),
            reason:
                '_StoryBlock, the 10dp gap, and the new floor-rule Container',
          );

          // `_StoryBlock` is private to outcome_card.dart, so this test
          // (a different library) can't reference the type directly —
          // `runtimeType` still exposes the class name at runtime
          // regardless of Dart's compile-time library privacy.
          expect(column.children[0].runtimeType.toString(), '_StoryBlock');

          final gap = column.children[1] as SizedBox;
          expect(
            gap.height,
            10.0,
            reason:
                'R4.2: deliberately 10dp, not R3.2\'s 12dp headline->story '
                'gap, to read as the footer\'s own spacing rhythm creeping up',
          );

          final rule = column.children[2] as Container;
          expect(
            rule.constraints,
            const BoxConstraints.tightFor(width: 36, height: 2),
            reason: 'k=1 at the harness\'s default 250dp reference width',
          );
          final decoration = rule.decoration as BoxDecoration;
          final palette = OutcomeTierPalette.of(outcome);
          expect(decoration.color, palette.baseText.withValues(alpha: 0.15));
          expect(decoration.borderRadius, BorderRadius.circular(1));
        },
      );
    }

    testWidgets(
      'the floor-rule Container\'s size scales by k, same as everything else '
      'on the card (k=0.6 at a 150dp width, 150/250)',
      (tester) async {
        await tester.pumpWidget(
          harness(
            const OutcomeCard(
              outcome: RunOutcome.death,
              playerName: '',
              content: OutcomeStoryContent.naFor,
            ),
            width: 150,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        final align = tester.widget<Align>(find.byType(Align));
        final fittedBox = align.child as FittedBox;
        final sizedBox = fittedBox.child as SizedBox;
        // 206 * (150 / 250) = 123.6, same k applied to the width bound.
        expect(sizedBox.width, closeTo(123.6, 0.0001));
        final column = sizedBox.child as Column;
        final rule = column.children[2] as Container;
        // Not exact `BoxConstraints` equality here — `36 * (150 / 250)`
        // doesn't land on an exact double, so a strict `==` is flaky on
        // floating-point rounding, not a real behavioral difference.
        expect(rule.constraints!.maxWidth, closeTo(21.6, 0.0001));
        expect(rule.constraints!.minWidth, closeTo(21.6, 0.0001));
        expect(rule.constraints!.maxHeight, closeTo(1.2, 0.0001));
        expect(rule.constraints!.minHeight, closeTo(1.2, 0.0001));
      },
    );
  });

  group('REGRESSION: CardFooter\'s two inter-element gaps are 8dp, not '
      '10dp (design v1 Revision 4 §R4.3 — the cheapest lever to claw back '
      'headroom eaten by R4.1\'s shorter shell + R4.2\'s floor rule)', () {
    testWidgets(
      'both SizedBoxes inside CardFooter are 8dp tall at k=1, not 10dp',
      (tester) async {
        await tester.pumpWidget(
          harness(CardFooter(palette: OutcomeTierPalette.death, k: 1.0)),
        );
        await tester.pump();

        final gaps = tester
            .widgetList<SizedBox>(find.byType(SizedBox))
            .where((s) => s.height != null);
        expect(gaps, isNotEmpty);
        for (final gap in gaps) {
          expect(gap.height, 8.0);
          expect(gap.height, isNot(10.0));
        }
      },
    );
  });

  group('Eternal is a gradient, Death/Survived are solid colors', () {
    test('OutcomeTierPalette.eternal has a non-null cardGradient and a '
        'null cardColor', () {
      expect(OutcomeTierPalette.eternal.cardGradient, isNotNull);
      expect(OutcomeTierPalette.eternal.cardColor, isNull);
    });

    test('OutcomeTierPalette.death has a non-null cardColor and a null '
        'cardGradient', () {
      expect(OutcomeTierPalette.death.cardColor, isNotNull);
      expect(OutcomeTierPalette.death.cardGradient, isNull);
    });

    test('OutcomeTierPalette.survived has a non-null cardColor and a null '
        'cardGradient', () {
      expect(OutcomeTierPalette.survived.cardColor, isNotNull);
      expect(OutcomeTierPalette.survived.cardGradient, isNull);
    });

    testWidgets('the actual rendered Container decoration uses '
        'BoxDecoration.gradient (not .color) for eternal', (tester) async {
      await tester.pumpWidget(
        harness(
          OutcomeCardShell(
            palette: OutcomeTierPalette.eternal,
            builder: (context, k) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.color, isNull);
    });

    for (final entry in [
      ('death', OutcomeTierPalette.death),
      ('survived', OutcomeTierPalette.survived),
    ]) {
      final (label, tierPalette) = entry;
      testWidgets(
        'the actual rendered Container decoration uses BoxDecoration.color '
        '(not .gradient) for $label',
        (tester) async {
          await tester.pumpWidget(
            harness(
              OutcomeCardShell(
                palette: tierPalette,
                builder: (context, k) => const SizedBox.shrink(),
              ),
            ),
          );
          await tester.pump();

          final container = tester.widget<Container>(find.byType(Container));
          final decoration = container.decoration as BoxDecoration;
          expect(decoration.color, isNotNull);
          expect(decoration.gradient, isNull);
        },
      );
    }
  });
}
