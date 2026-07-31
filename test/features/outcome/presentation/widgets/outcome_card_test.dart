import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/domain/outcome_story_content.dart';
import 'package:timing_tap/features/outcome/domain/story_beat.dart';
import 'package:timing_tap/features/outcome/domain/story_pool.dart';
import 'package:timing_tap/features/outcome/domain/story_pool_codec.dart';
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
///
/// (remote-story-config-implementation-spec §9.6): the "longest content per
/// tier" fixtures below now source from the parsed bundled asset
/// (`StoryPoolCodec.decode` against `assets/stories_bundled.json`) instead
/// of the deleted `death_beats.dart`/`survived_beats.dart`/`eternal_beats.dart`
/// Dart lists — `main()` is `async` so the asset can be awaited once, before
/// any `group`/`testWidgets` registration below runs.
void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw = await rootBundle.loadString('assets/stories_bundled.json');
  final StoryPool pool = StoryPoolCodec.decode(raw);
  final deathBeats = pool.death.beats;
  final survivedBeats = pool.survived.beats;
  final eternalBeats = pool.eternal.beats;
  final deathIcons = pool.death.icons;
  final survivedIcons = pool.survived.icons;
  final eternalIcons = pool.eternal.icons;

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
    // The exact longest entries in each tier (by combined headline+named
    // length), found by direct inspection of the pooled content (now
    // `assets/stories_bundled.json`, parsed above) — the fix pass found this
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
