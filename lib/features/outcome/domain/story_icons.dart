/// Top-right icon pools (architecture v4 §1) — independently drawn from the
/// pooled `StoryBeat` above it; not paired 1:1 with any specific beat. Plain
/// `String`s, not codepoints (architecture §5): display-only, never
/// measured/indexed/truncated, so a bare `Text` is correct and the
/// `characters` package isn't needed here.
library;

/// ⏰️ is U+23F0 + U+FE0F (multi-codepoint, not ZWJ) — renders fine as long
/// as it's never `substring`'d, which it isn't.
const List<String> deathIcons = ['⏰️', '😵', '💀', '🪦', '⚰️', '💥'];

/// 🆘, never 🛟 (founder-resolved — the ring-buoy is Unicode 14.0/2021 and
/// risks tofu-rendering on older Android system emoji fonts, which would
/// also ship straight into the rasterized shared PNG). 🆘 is Unicode
/// 6.0/2010 and safe on any device this app targets.
const List<String> survivedIcons = ['😮‍💨', '🆘', '🫀', '🙏', '😅'];

/// Added per design v1 §8's resolution of a genuine mockup gap: the literal
/// mockup omits an icon slot for Eternal, but this pool needs somewhere to
/// render — the top-right slot is shown for all three tiers for visual
/// consistency (and so this pool isn't dead content data).
const List<String> eternalIcons = ['✨', '👑', '🏆', '🌟'];
