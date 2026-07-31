import 'dart:convert';

import 'story_beat.dart';
import 'story_pool.dart';

/// Parse-domain constants (as opposed to provider-layer timing constants,
/// which live in `outcome_providers.dart`).
const int kStorySchemaVersion = 1;

/// Per-tier cap. Memory-safety M5: bounds attacker/founder-controlled
/// resident pool size regardless of path (remote or bundled).
const int kStoryMaxBeatsPerTier = 500;

/// Per-tier cap, inclusive lower bound of 1 (a tier must have at least one
/// icon to ever render a card). Memory-safety M5.
const int kStoryMaxIconsPerTier = 64;

/// Hard cap on a raw payload's byte length, checked by
/// `StoryPoolRepository.refreshIfStale` on `response.bodyBytes.length`
/// *before* any UTF-8 decode (memory-safety M4). Declared here, alongside
/// the codec's other size caps, even though the repository is the only
/// caller.
///
/// 128 KB (~8.7x today's real payload of ~15 KB) — generous headroom for
/// legitimate content growth, while still meaningfully bounding the
/// worst-case size of the string `shared_preferences` holds resident for
/// the app's lifetime (see M2's note in the implementation spec: this cap
/// bounds the SIZE of that resident copy, not the fact that it's resident
/// — that residency is an accepted tradeoff of the shared_preferences
/// storage choice, not something this cap eliminates).
const int kStoryPoolMaxBytes = 128 * 1024;

/// Thrown by [StoryPoolCodec.decode] on any structural or safety-invariant
/// violation. Never thrown for a content-quality issue (see R3 in
/// `story_pool_codec.dart`'s class doc below) — only for the things that
/// would otherwise corrupt or destabilize the app.
class StoryPoolFormatException implements Exception {
  StoryPoolFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'StoryPoolFormatException: $reason';
}

/// The one and only parse path for story-pool JSON (R1). Both the remote
/// payload and the bundled fallback asset go through [decode] — there is no
/// second, laxer parser for the asset.
///
/// **R3 — placeholder rules are publish-time, not client-side.** `{name}`
/// appearing in `headline`/`anonymous`, or missing from `named`, is
/// deliberately **not enforced here**. Those are content-quality rules
/// checked by the publish-time GitHub Action validator, not safety rules.
/// Enforcing them client-side would mean one badly-worded beat rejects the
/// entire payload and silently reverts every player to the bundled pool — a
/// total content outage caused by a cosmetic typo. A mis-placed `{name}`
/// renders as a literal `{name}` on one card; that is a strictly better
/// failure than a global rollback.
///
/// **Emoji-safety rationale** (which emoji are safe to add to an `icons`
/// array, and why) now lives permanently in `tools/story-content/README.md`
/// — that's where a content editor about to add a new icon will actually be
/// looking.
class StoryPoolCodec {
  const StoryPoolCodec._();

  /// Decodes [raw] into a [StoryPool], throwing [StoryPoolFormatException]
  /// on any violation of the validation-rule table (see class doc / spec
  /// §2.2). **Never retains [raw]** — it is a local, decoded into `dynamic`
  /// JSON, then discarded; no field on the returned [StoryPool] (or
  /// anything it references) holds the original string (memory-safety M2).
  static StoryPool decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw StoryPoolFormatException('raw string is not valid JSON');
    }
    if (decoded is! Map) {
      throw StoryPoolFormatException('root is not a JSON object');
    }
    final root = decoded;

    final schemaVersion = root['schemaVersion'];
    if (schemaVersion is! int || schemaVersion != kStorySchemaVersion) {
      throw StoryPoolFormatException(
        'unsupported schemaVersion $schemaVersion',
      );
    }

    final rawContentVersion = root['contentVersion'];
    final contentVersion = rawContentVersion is int ? rawContentVersion : 0;

    // `updatedAt` is ignored entirely by the client; it exists for humans
    // reading the file.

    final tiers = root['tiers'];
    if (tiers is! Map) {
      throw StoryPoolFormatException('missing or invalid "tiers"');
    }
    for (final key in const ['death', 'survived', 'eternal']) {
      if (!tiers.containsKey(key)) {
        throw StoryPoolFormatException('missing tier "$key"');
      }
    }

    final seenIds = <String>{};
    StoryTierPool decodeTier(String tierName) {
      final tierJson = tiers[tierName];
      if (tierJson is! Map) {
        throw StoryPoolFormatException('tier "$tierName" is not an object');
      }
      final beatsJson = tierJson['beats'];
      final iconsJson = tierJson['icons'];
      if (beatsJson is! List) {
        throw StoryPoolFormatException('tier "$tierName" has no "beats" list');
      }
      if (iconsJson is! List) {
        throw StoryPoolFormatException('tier "$tierName" has no "icons" list');
      }
      if (beatsJson.length > kStoryMaxBeatsPerTier) {
        throw StoryPoolFormatException(
          'tier "$tierName" exceeds $kStoryMaxBeatsPerTier beats',
        );
      }
      if (iconsJson.isEmpty || iconsJson.length > kStoryMaxIconsPerTier) {
        throw StoryPoolFormatException(
          'tier "$tierName" icon count must be 1..$kStoryMaxIconsPerTier',
        );
      }
      final icons = <String>[];
      for (final iconJson in iconsJson) {
        if (iconJson is! String || iconJson.isEmpty) {
          throw StoryPoolFormatException(
            'tier "$tierName" has a blank/non-string icon',
          );
        }
        icons.add(iconJson);
      }
      final beats = <StoryBeat>[];
      for (final beatJson in beatsJson) {
        if (beatJson is! Map) {
          throw StoryPoolFormatException(
            'tier "$tierName" has a non-object beat entry',
          );
        }
        beats.add(StoryBeat.fromJson(Map<String, dynamic>.from(beatJson)));
      }
      for (final beat in beats) {
        if (!seenIds.add(beat.id)) {
          throw StoryPoolFormatException('duplicate beat id "${beat.id}"');
        }
      }
      return StoryTierPool(
        beats: List.unmodifiable(beats),
        icons: List.unmodifiable(icons),
      );
    }

    final death = decodeTier('death');
    final survived = decodeTier('survived');
    final eternal = decodeTier('eternal');

    return StoryPool(
      contentVersion: contentVersion,
      death: death,
      survived: survived,
      eternal: eternal,
    );
  }

  /// Test/tooling only — not used by any production code path. The cheapest
  /// guard against `fromJson`/schema drift is `decode(encode(pool)) == pool`
  /// (field-for-field), pinned by the round-trip test.
  static String encode(StoryPool pool) {
    Map<String, dynamic> tierJson(StoryTierPool tier) => {
      'beats': tier.beats.map((b) => b.toJson()).toList(),
      'icons': tier.icons,
    };

    return jsonEncode({
      'schemaVersion': kStorySchemaVersion,
      'contentVersion': pool.contentVersion,
      'updatedAt': '1970-01-01T00:00:00Z',
      'tiers': {
        'death': tierJson(pool.death),
        'survived': tierJson(pool.survived),
        'eternal': tierJson(pool.eternal),
      },
    });
  }
}
