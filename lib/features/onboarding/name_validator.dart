import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Profanity check for the name-capture screen
/// (docs/design/onboarding-flow-v1.md §5.5/§5.6, architecture v2 §3.4).
///
/// The length cap is **not** this class's job — it's enforced directly by
/// `TextField.maxLength` at the input level (§5.5), so there is no "too
/// long" submission for this validator to ever see or reject.
///
/// Matching is whole-word and case-insensitive against a bundled word list
/// (`assets/profanity.txt`) so a banned word embedded inside an otherwise
/// innocuous longer word (e.g. "classic") does not false-positive.
class NameValidator {
  NameValidator(Iterable<String> bannedWords)
      : _bannedWords = bannedWords.map((w) => w.toLowerCase()).toSet();

  final Set<String> _bannedWords;

  /// Loads the bundled word list and builds a [NameValidator] from it. Only
  /// non-empty, non-comment (`#`-prefixed) lines are kept.
  static Future<NameValidator> load({AssetBundle? bundle}) async {
    final AssetBundle effectiveBundle = bundle ?? rootBundle;
    final String raw =
        await effectiveBundle.loadString('assets/profanity.txt');
    return NameValidator(_parseWordList(raw));
  }

  static Iterable<String> _parseWordList(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'));
  }

  /// True if [name] contains a banned word as a whole token (split on
  /// anything that isn't a letter/digit) — the only trigger for the 8.1
  /// name-rejected state (§5.6).
  bool containsProfanity(String name) {
    final Iterable<String> tokens = name
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty);
    return tokens.any(_bannedWords.contains);
  }
}

/// Resolves once the bundled word list has loaded — cached by Riverpod for
/// the life of the `ProviderContainer`, same seam/reasoning as
/// `profileRepositoryProvider` (`hive_profile_repository.dart`). Loaded
/// alongside the profile repository as part of `SplashScreen`'s real init
/// work (docs/design/onboarding-flow-v1.md §3.2).
final nameValidatorProvider = FutureProvider<NameValidator>((ref) {
  return NameValidator.load();
});
