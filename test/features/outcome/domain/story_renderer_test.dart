import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/domain/story_beat.dart';
import 'package:timing_tap/features/outcome/domain/story_renderer.dart';
import 'package:timing_tap/features/outcome/domain/survived_beats.dart';

/// Pure-Dart coverage for `StoryRenderer.render` (architecture v4 §1) — the
/// `{min}`/`{peak}` substitution layer that replaces the old
/// `FlavorSelector.render()`'s single `{name}` substitution. Deliberately
/// pins the contract that `{name}` survives UNTOUCHED (so the widget layer
/// can color the name span) while `{min}`/`{peak}` get substituted eagerly
/// here, from `RunSummary` stats, in all three `StoryBeat` fields.
void main() {
  const renderer = StoryRenderer();

  group('{name} is deliberately left un-substituted', () {
    test('a {name} placeholder in `named` survives render() untouched', () {
      const beat = StoryBeat(
        headline: 'Blinked. Gone.',
        named: '{name} blinked at the exact wrong moment.',
        anonymous: 'Blinked at the exact wrong moment.',
      );

      final rendered = renderer.render(beat, minLifePercent: 10, peakLifePercent: 90);

      expect(rendered.named, contains('{name}'));
      expect(rendered.named, '{name} blinked at the exact wrong moment.');
    });

    test('a {name} placeholder appearing in `anonymous` (should never happen '
        'in authored content, but the renderer contract is field-agnostic) '
        'is also left untouched, not silently stripped', () {
      const beat = StoryBeat(
        headline: 'Test',
        named: '{name} did a thing.',
        anonymous: 'Even {name} would not do this, but if authored, it survives.',
      );

      final rendered = renderer.render(beat, minLifePercent: 0, peakLifePercent: 0);

      expect(rendered.anonymous, contains('{name}'));
    });
  });

  group('{min}/{peak} ARE substituted correctly from RunSummary stats', () {
    test('{min} substitutes in the headline', () {
      const beat = StoryBeat(
        headline: 'Saved at {min}%.',
        named: '{name} found the exact instant with nothing left to spare.',
        anonymous: 'Found the exact instant with nothing left to spare.',
      );

      final rendered = renderer.render(beat, minLifePercent: 3, peakLifePercent: 71);

      expect(rendered.headline, 'Saved at 3%.');
    });

    test('{peak} substitutes in the headline (currently unused by any '
        'pooled beat, but the renderer must still wire it correctly for '
        'forward-compatibility per architecture v4 §1)', () {
      const beat = StoryBeat(
        headline: 'Peaked at {peak}%, then it all went wrong.',
        named: '{name} peaked at {peak}%.',
        anonymous: 'Peaked at {peak}%.',
      );

      final rendered = renderer.render(beat, minLifePercent: 5, peakLifePercent: 88);

      expect(rendered.headline, 'Peaked at 88%, then it all went wrong.');
      expect(rendered.named, '{name} peaked at 88%.');
      expect(rendered.anonymous, 'Peaked at 88%.');
    });

    test('{min} and {peak} both substitute correctly in the SAME field, '
        'independently', () {
      const beat = StoryBeat(
        headline: 'From {peak}% down to {min}% and still alive.',
        named: '{name} rode it from {peak}% down to {min}%.',
        anonymous: 'Rode it from {peak}% down to {min}%.',
      );

      final rendered = renderer.render(beat, minLifePercent: 2, peakLifePercent: 97);

      expect(rendered.headline, 'From 97% down to 2% and still alive.');
      expect(rendered.named, '{name} rode it from 97% down to 2%.');
      expect(rendered.anonymous, 'Rode it from 97% down to 2%.');
    });

    test('{min} substitutes correctly in `named` alongside a surviving '
        '{name} placeholder — the two substitutions do not interfere', () {
      const beat = StoryBeat(
        headline: 'Calm, at {min}%.',
        named: '{name} found calm in the last possible heartbeat at {min}%.',
        anonymous: 'Found calm in the last possible heartbeat.',
      );

      final rendered = renderer.render(beat, minLifePercent: 1, peakLifePercent: 50);

      expect(rendered.named, '{name} found calm in the last possible heartbeat at 1%.');
      expect(rendered.named, contains('{name}'));
      expect(rendered.named, isNot(contains('{min}')));
    });

    test('a beat with no placeholders at all round-trips unchanged', () {
      const beat = StoryBeat(
        headline: 'Never wobbled once.',
        named: '{name} never even wobbled.',
        anonymous: 'Never even wobbled.',
      );

      final rendered = renderer.render(beat, minLifePercent: 40, peakLifePercent: 100);

      expect(rendered.headline, 'Never wobbled once.');
      expect(rendered.anonymous, 'Never even wobbled.');
    });
  });

  group('name-free (anonymous) story path', () {
    test('the anonymous field never carries a {name} placeholder for any '
        'real pooled survived beat, and still substitutes {min} where '
        'authored', () {
      for (final beat in survivedBeats) {
        final rendered = renderer.render(beat, minLifePercent: 3, peakLifePercent: 80);
        expect(rendered.anonymous, isNot(contains('{name}')));
        expect(rendered.anonymous, isNot(contains('{min}')));
        expect(rendered.anonymous, isNot(contains('{peak}')));
      }
    });

    test('rendering the real "Saved at {min}%." survived beat produces the '
        'exact headline the mockup specifies', () {
      final beat = survivedBeats.firstWhere((b) => b.headline.contains('{min}'));
      final rendered = renderer.render(beat, minLifePercent: 3, peakLifePercent: 55);
      expect(rendered.headline, 'Saved at 3%.');
    });
  });
}
