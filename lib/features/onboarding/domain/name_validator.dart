// The analyzer's static regex checker doesn't recognize the Unicode binary
// property escapes (`\p{Emoji}`, `\p{Extended_Pictographic}`) used below to
// detect emoji graphemes, even though Dart's RegExp engine supports them at
// runtime (verified: they correctly match composite/ZWJ emoji sequences).
// ignore_for_file: valid_regexps

import 'package:characters/characters.dart';

import 'profanity_filter.dart';

/// Why a raw name string was rejected by [NameValidator.validate].
enum NameRejectReason { tooLong, empty, illegalChars, disallowedWord }

/// Result of validating a raw name string.
class NameValidationResult {
  const NameValidationResult({
    required this.isValid,
    required this.sanitized,
    this.reason,
  });

  final bool isValid;
  final String sanitized;
  final NameRejectReason? reason;
}

/// Pure Dart, screen-independent name validation (architecture v1 §5).
///
/// No Flutter imports — unit-testable in isolation and reusable by the
/// future Settings "edit name" flow. The 12-character cap is enforced in
/// *grapheme clusters* (via the `characters` package), not UTF-16 code
/// units, so a single multi-codepoint emoji doesn't silently consume 2-4 of
/// the 12 slots.
class NameValidator {
  const NameValidator({this.profanityFilter = const ProfanityFilter()});

  final ProfanityFilter profanityFilter;

  static const int maxLength = 12;

  /// Zero-width joiner, variation selectors, combining enclosing keycap, and
  /// skin-tone modifiers: the codepoints that stitch multiple emoji
  /// codepoints into a single rendered glyph (composite emoji / ZWJ
  /// sequences / keycaps) but don't themselves carry a Unicode `Emoji`
  /// property in every implementation. Regional indicators are handled
  /// separately below since, unlike these, a pair of them *is* the emoji
  /// (a flag) rather than glue holding one together.
  static bool _isEmojiGlueRune(int rune) {
    if (rune == 0x200D) return true; // ZWJ
    if (rune == 0xFE0E || rune == 0xFE0F) return true; // variation selectors
    if (rune == 0x20E3) return true; // combining enclosing keycap
    if (rune >= 0x1F3FB && rune <= 0x1F3FF) return true; // skin tone modifiers
    return false;
  }

  static bool _isRegionalIndicator(int rune) => rune >= 0x1F1E6 && rune <= 0x1F1FF;

  static final RegExp _emojiRuneRegex = RegExp(
    r'[\p{Emoji}\p{Extended_Pictographic}]',
    unicode: true,
  );

  /// Letters (any script, incl. combining marks for accented/composed
  /// letters), digits, spaces, and the small allowed punctuation set.
  static final RegExp _simpleClusterRegex = RegExp(
    r"^[\p{L}\p{M}\p{N} '\-_]+$",
    unicode: true,
  );

  bool _isAllowedCluster(String cluster) {
    if (_simpleClusterRegex.hasMatch(cluster)) return true;
    var sawEmoji = false;
    for (final rune in cluster.runes) {
      if (_isRegionalIndicator(rune)) {
        // A pair of these *is* a flag emoji (e.g. 🇮🇳), not glue around one.
        sawEmoji = true;
        continue;
      }
      if (_isEmojiGlueRune(rune)) continue;
      if (_emojiRuneRegex.hasMatch(String.fromCharCode(rune))) {
        sawEmoji = true;
        continue;
      }
      return false;
    }
    return sawEmoji;
  }

  /// Trims leading/trailing whitespace and collapses internal runs of
  /// whitespace to a single space.
  String _sanitize(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  NameValidationResult validate(String raw) {
    final sanitized = _sanitize(raw);

    if (sanitized.isEmpty) {
      return const NameValidationResult(
        isValid: false,
        sanitized: '',
        reason: NameRejectReason.empty,
      );
    }

    final clusters = sanitized.characters;
    if (clusters.length > maxLength) {
      return NameValidationResult(
        isValid: false,
        sanitized: sanitized,
        reason: NameRejectReason.tooLong,
      );
    }

    for (final cluster in clusters) {
      if (!_isAllowedCluster(cluster)) {
        return NameValidationResult(
          isValid: false,
          sanitized: sanitized,
          reason: NameRejectReason.illegalChars,
        );
      }
    }

    if (!profanityFilter.isAllowed(sanitized)) {
      return NameValidationResult(
        isValid: false,
        sanitized: sanitized,
        reason: NameRejectReason.disallowedWord,
      );
    }

    return NameValidationResult(isValid: true, sanitized: sanitized);
  }
}
