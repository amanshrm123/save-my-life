/// Seed blocklist + `isAllowed()` hook for [NameValidator]'s disallowed-word
/// rule (architecture v1 §5 rule 4).
///
/// **Scope note:** this ships only a trivial seed list so the rejection
/// state (mockup 8.1 "Pick another name") is reachable and testable. A
/// comprehensive/localised blocklist is explicitly deferred to a later
/// hardening pass — do not extend this list as part of this feature.
class ProfanityFilter {
  const ProfanityFilter({List<String>? blocklist})
    : _blocklist = blocklist ?? _seedBlocklist;

  final List<String> _blocklist;

  static const List<String> _seedBlocklist = <String>[
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'cunt',
  ];

  /// Returns `true` if [name] does NOT contain any blocked word
  /// (case-insensitive, substring match against the sanitized name).
  bool isAllowed(String name) {
    final lower = name.toLowerCase();
    for (final word in _blocklist) {
      if (lower.contains(word)) return false;
    }
    return true;
  }
}
