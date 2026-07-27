import 'package:flutter/material.dart';

import '../../../play_loop/domain/run_state.dart';
import '../../domain/outcome_story_content.dart';
import 'card_footer.dart';
import 'outcome_card_shell.dart';
import 'outcome_chip.dart';

/// The resolved outcome-card body (design v1 §3 anatomy) — the exact
/// composition captured by the sharing `RepaintBoundary` (architecture v4
/// §6). Chip + icon top row, vertically-centered headline + story in the
/// middle, tagline + wordmark + store badges pinned at the bottom.
class OutcomeCard extends StatelessWidget {
  const OutcomeCard({
    super.key,
    required this.outcome,
    required this.playerName,
    required this.content,
  });

  final RunOutcome outcome;
  final String playerName;
  final OutcomeStoryContent content;

  @override
  Widget build(BuildContext context) {
    final palette = OutcomeTierPalette.of(outcome);
    return OutcomeCardShell(
      palette: palette,
      builder: (context, k) {
        return Padding(
          padding: EdgeInsets.fromLTRB(22 * k, 26 * k, 22 * k, 22 * k),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // `Flexible`, not a bare child: the longer chip copies
                  // (Eternal's "✨ Eternal · Top 0.3%", Survived's "🆘
                  // Survived") overflow this `Row` at k close to 1 the same
                  // way the wordmark row did (near-zero horizontal headroom
                  // by design) — `Flexible` bounds the chip's width so
                  // `OutcomeChip`'s own internal `FittedBox` can actually
                  // shrink it to fit, rather than the chip demanding its
                  // unbounded intrinsic width and overflowing past the
                  // 28dp icon on the right.
                  Flexible(
                    child: OutcomeChip(
                      label: palette.chipLabel,
                      fill: palette.chipFill,
                      textColor: palette.chipText,
                      k: k,
                    ),
                  ),
                  Text(content.icon, style: TextStyle(fontSize: 28 * k, height: 1)),
                ],
              ),
              Expanded(
                child: Center(
                  // Design v1 §10.7 accepts that unbounded authored copy
                  // could overflow this fixed 9:16 middle region and
                  // resolves it as a content-authoring constraint (keep
                  // headlines ~2 lines, stories ~4 lines) rather than a
                  // layout one — but with 66 pooled beats and random
                  // per-run selection, an occasional longer combination
                  // still needs to fail safely rather than throw a
                  // `RenderFlex` overflow straight into the shared PNG.
                  // `FittedBox(scaleDown)` is a no-op for every beat that
                  // already fits (the common case, preserving the doc's
                  // proportional-scale composition untouched) and only
                  // engages as a last-resort safety net for the rare
                  // outlier — the same established pattern already used
                  // for the wordmark/store-badge/chip overflows above.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _StoryBlock(
                      playerName: playerName,
                      content: content,
                      palette: palette,
                      k: k,
                    ),
                  ),
                ),
              ),
              CardFooter(palette: palette, k: k),
            ],
          ),
        );
      },
    );
  }
}

/// Headline + story — this whole block re-centers per-run as its content's
/// length varies (design v1 §3: expected, not a bug).
class _StoryBlock extends StatelessWidget {
  const _StoryBlock({
    required this.playerName,
    required this.content,
    required this.palette,
    required this.k,
  });

  final String playerName;
  final OutcomeStoryContent content;
  final OutcomeTierPalette palette;
  final double k;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content.headline,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 27 * k,
            fontWeight: FontWeight.w700,
            height: 1.12,
            color: palette.baseText,
          ),
        ),
        SizedBox(height: 12 * k),
        _storyText(),
      ],
    );
  }

  /// Design v1 §4.4 / architecture v4 §1: when `playerName` is empty, render
  /// the anonymous rewrite plainly (no colored name span at all); otherwise
  /// split the named template on its literal `{name}` placeholder(s) and
  /// color just the name span(s). The `.tale`'s own 0.85 opacity (design v1
  /// §5) applies to the whole block including the name span (CSS `opacity`
  /// composites the entire subtree, it doesn't reset per-child) — so the
  /// name span's color also carries that alpha, not full opacity.
  ///
  /// Also covers the `'N/A'` fallback template (no `{name}` placeholder at
  /// all — reachable via `LocalOutcomeStoryService.forceFailure` today, and
  /// any future remote-fetch failure later): a template with zero
  /// occurrences renders as a single un-split string with no name span,
  /// rather than unconditionally appending `playerName` onto it (which used
  /// to produce garbled text like "N/AAman"). A template with two-or-more
  /// occurrences also renders correctly — every segment is built from a
  /// full split, not just `parts[0]`/`parts[1]`.
  Widget _storyText() {
    final baseColor = palette.baseText.withValues(alpha: 0.85);
    final nameColor = palette.nameSpan.withValues(alpha: 0.85);
    final baseStyle = TextStyle(
      fontFamily: 'Fredoka',
      fontSize: 14 * k,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: baseColor,
    );

    if (playerName.isEmpty) {
      return Text(content.storyAnonymous, style: baseStyle);
    }

    final template = content.storyNamed;
    if (!template.contains('{name}')) {
      return Text(template, style: baseStyle);
    }

    final parts = template.split('{name}');
    final nameStyle = TextStyle(fontWeight: FontWeight.w700, color: nameColor);
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(TextSpan(text: playerName, style: nameStyle));
      }
    }
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}
