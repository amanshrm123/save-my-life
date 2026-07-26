/// Shared shape for every pooled flavor-line entry (architecture v3 §3): each
/// entry authors both a named template (containing a literal `{name}`
/// placeholder) and an explicit anonymous fallback, so the no-name card
/// variant (design v1 §2.2/3.4) never needs to string-hack the named form.
abstract class NamedFlavor {
  String get named;
  String get anonymous;
}

/// One death-pool entry (architecture v3 §3) — `catalogNo` is 1-based within
/// the seeded 50-entry pool, displayed as "Death #{catalogNo} of 1000" (the
/// aspirational catalog size, honestly labelled per architecture §1 item 4).
class DeathFlavor implements NamedFlavor {
  const DeathFlavor({required this.catalogNo, required this.named, required this.anonymous});

  final int catalogNo;

  @override
  final String named;

  @override
  final String anonymous;
}

/// One survived-pool entry. The catalog line for Survived is fixed
/// ("Last-second save," design v1 §2.2) rather than per-entry, so unlike
/// [DeathFlavor] there's no `catalogNo` here.
class SurvivedFlavor implements NamedFlavor {
  const SurvivedFlavor({required this.named, required this.anonymous});

  @override
  final String named;

  @override
  final String anonymous;
}

/// One eternal-pool entry. Design v1 §2.3 resolves a real inconsistency in
/// the architecture doc: Eternal's "sub" line has no numbers to report (the
/// only stat, perfect count, is already in the catalog line), so `sub` is
/// paired qualitative flex copy living in the *same* pool entry as `named`/
/// `anonymous`, swapped together on each pick — not derived from
/// `RunSummary` the way Death/Survived's sub-lines are.
class EternalFlavor implements NamedFlavor {
  const EternalFlavor({required this.named, required this.anonymous, required this.sub});

  @override
  final String named;

  @override
  final String anonymous;

  /// The qualitative flex sub-line ("Almost nobody does this.") — no name
  /// span, no numbers (design v1 §2.4's dropped-percentile resolution).
  final String sub;
}
