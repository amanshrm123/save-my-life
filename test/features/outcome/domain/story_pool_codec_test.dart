import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/domain/story_beat.dart';
import 'package:timing_tap/features/outcome/domain/story_pool.dart';
import 'package:timing_tap/features/outcome/domain/story_pool_codec.dart';

/// Coverage for `StoryPoolCodec` (remote-story-config-implementation-spec
/// §2.2/§9.3) — the single parse path shared by the remote payload and the
/// bundled fallback asset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> beatJson(
    String id, {
    String? headline,
    String? named,
    String? anonymous,
  }) {
    return {
      'id': id,
      'headline': headline ?? 'Headline $id',
      'named': named ?? '{name} did a thing for $id.',
      'anonymous': anonymous ?? 'Did a thing for $id.',
    };
  }

  /// A minimal, fully-valid payload: one beat + one icon per tier.
  Map<String, dynamic> validJson({
    int? schemaVersion,
    Object? contentVersionOverride = const _Unset(),
    Map<String, dynamic>? tiersOverride,
  }) {
    final tiers =
        tiersOverride ??
        {
          'death': {
            'beats': [beatJson('death_001')],
            'icons': ['💀'],
          },
          'survived': {
            'beats': [beatJson('survived_001')],
            'icons': ['🆘'],
          },
          'eternal': {
            'beats': [beatJson('eternal_001')],
            'icons': ['✨'],
          },
        };

    return {
      'schemaVersion': schemaVersion ?? kStorySchemaVersion,
      if (contentVersionOverride is! _Unset)
        'contentVersion': contentVersionOverride,
      'updatedAt': '2026-07-31T00:00:00Z',
      'tiers': tiers,
    };
  }

  group('bundled asset', () {
    test('is valid: parses cleanly with expected shape', () async {
      final raw = await rootBundle.loadString('assets/stories_bundled.json');
      final pool = StoryPoolCodec.decode(raw);

      expect(pool.death.beats.length, 50);
      expect(pool.survived.beats.length, 10);
      expect(pool.eternal.beats.length, 6);
      expect(pool.death.icons.length, 6);
      expect(pool.survived.icons.length, 5);
      expect(pool.eternal.icons.length, 4);
      expect(pool.contentVersion, 1);

      final allIds = [
        ...pool.death.beats.map((b) => b.id),
        ...pool.survived.beats.map((b) => b.id),
        ...pool.eternal.beats.map((b) => b.id),
      ];
      expect(allIds.length, 66);
      expect(allIds.toSet().length, 66, reason: 'all 66 IDs must be unique');

      final idPattern = RegExp(r'^(death|survived|eternal)_\d{3}$');
      for (final id in allIds) {
        expect(
          idPattern.hasMatch(id),
          isTrue,
          reason: '"$id" does not match the expected ID shape',
        );
      }
    });
  });

  group('corrupt payload', () {
    test('truncated JSON throws StoryPoolFormatException', () {
      expect(
        () => StoryPoolCodec.decode('{"schemaVersion": 1, "tiers": {'),
        throwsA(isA<StoryPoolFormatException>()),
      );
    });

    test('[] root throws StoryPoolFormatException', () {
      expect(
        () => StoryPoolCodec.decode('[]'),
        throwsA(isA<StoryPoolFormatException>()),
      );
    });

    test('{} root throws StoryPoolFormatException', () {
      expect(
        () => StoryPoolCodec.decode('{}'),
        throwsA(isA<StoryPoolFormatException>()),
      );
    });
  });

  group('schema-version mismatch', () {
    test('schemaVersion: 2 throws', () {
      expect(
        () => StoryPoolCodec.decode(jsonEncode(validJson(schemaVersion: 2))),
        throwsA(isA<StoryPoolFormatException>()),
      );
    });

    test('schemaVersion: "1" (string, not int) throws', () {
      final json = validJson();
      json['schemaVersion'] = '1';
      expect(
        () => StoryPoolCodec.decode(jsonEncode(json)),
        throwsA(isA<StoryPoolFormatException>()),
      );
    });
  });

  test('missing tier throws', () {
    final json = validJson(
      tiersOverride: {
        'death': {
          'beats': [beatJson('death_001')],
          'icons': ['💀'],
        },
      },
    );
    expect(
      () => StoryPoolCodec.decode(jsonEncode(json)),
      throwsA(isA<StoryPoolFormatException>()),
    );
  });

  test('duplicate ID across tiers throws', () {
    final json = validJson(
      tiersOverride: {
        'death': {
          'beats': [beatJson('dup_001')],
          'icons': ['💀'],
        },
        'survived': {
          'beats': [beatJson('dup_001')],
          'icons': ['🆘'],
        },
        'eternal': {
          'beats': [beatJson('eternal_001')],
          'icons': ['✨'],
        },
      },
    );
    expect(
      () => StoryPoolCodec.decode(jsonEncode(json)),
      throwsA(isA<StoryPoolFormatException>()),
    );
  });

  group('beat cap', () {
    test('501 beats in one tier throws', () {
      final beats = List.generate(
        501,
        (i) => beatJson('death_${i.toString().padLeft(3, '0')}'),
      );
      final json = validJson(
        tiersOverride: {
          'death': {
            'beats': beats,
            'icons': ['💀'],
          },
          'survived': {
            'beats': [beatJson('survived_001')],
            'icons': ['🆘'],
          },
          'eternal': {
            'beats': [beatJson('eternal_001')],
            'icons': ['✨'],
          },
        },
      );
      expect(
        () => StoryPoolCodec.decode(jsonEncode(json)),
        throwsA(isA<StoryPoolFormatException>()),
      );
    });

    test('exactly 500 beats in one tier does not throw', () {
      final beats = List.generate(
        500,
        (i) => beatJson('death_${i.toString().padLeft(3, '0')}'),
      );
      final json = validJson(
        tiersOverride: {
          'death': {
            'beats': beats,
            'icons': ['💀'],
          },
          'survived': {
            'beats': [beatJson('survived_001')],
            'icons': ['🆘'],
          },
          'eternal': {
            'beats': [beatJson('eternal_001')],
            'icons': ['✨'],
          },
        },
      );
      expect(StoryPoolCodec.decode(jsonEncode(json)).death.beats.length, 500);
    });
  });

  group('icon cap', () {
    test('0 icons throws', () {
      final json = validJson(
        tiersOverride: {
          'death': {
            'beats': [beatJson('death_001')],
            'icons': <String>[],
          },
          'survived': {
            'beats': [beatJson('survived_001')],
            'icons': ['🆘'],
          },
          'eternal': {
            'beats': [beatJson('eternal_001')],
            'icons': ['✨'],
          },
        },
      );
      expect(
        () => StoryPoolCodec.decode(jsonEncode(json)),
        throwsA(isA<StoryPoolFormatException>()),
      );
    });

    test('65 icons throws', () {
      final icons = List.generate(65, (i) => '💀$i');
      final json = validJson(
        tiersOverride: {
          'death': {
            'beats': [beatJson('death_001')],
            'icons': icons,
          },
          'survived': {
            'beats': [beatJson('survived_001')],
            'icons': ['🆘'],
          },
          'eternal': {
            'beats': [beatJson('eternal_001')],
            'icons': ['✨'],
          },
        },
      );
      expect(
        () => StoryPoolCodec.decode(jsonEncode(json)),
        throwsA(isA<StoryPoolFormatException>()),
      );
    });

    test('exactly 64 icons does not throw', () {
      final icons = List.generate(64, (i) => '💀$i');
      final json = validJson(
        tiersOverride: {
          'death': {
            'beats': [beatJson('death_001')],
            'icons': icons,
          },
          'survived': {
            'beats': [beatJson('survived_001')],
            'icons': ['🆘'],
          },
          'eternal': {
            'beats': [beatJson('eternal_001')],
            'icons': ['✨'],
          },
        },
      );
      expect(StoryPoolCodec.decode(jsonEncode(json)).death.icons.length, 64);
    });
  });

  group('blank field', () {
    test('blank id throws', () {
      final json = validJson(
        tiersOverride: {
          'death': {
            'beats': [beatJson('')],
            'icons': ['💀'],
          },
          'survived': {
            'beats': [beatJson('survived_001')],
            'icons': ['🆘'],
          },
          'eternal': {
            'beats': [beatJson('eternal_001')],
            'icons': ['✨'],
          },
        },
      );
      expect(
        () => StoryPoolCodec.decode(jsonEncode(json)),
        throwsA(isA<StoryPoolFormatException>()),
      );
    });

    test('missing headline throws', () {
      final beat = {
        'id': 'death_001',
        'named': '{name} did.',
        'anonymous': 'Did.',
      };
      final json = validJson(
        tiersOverride: {
          'death': {
            'beats': [beat],
            'icons': ['💀'],
          },
          'survived': {
            'beats': [beatJson('survived_001')],
            'icons': ['🆘'],
          },
          'eternal': {
            'beats': [beatJson('eternal_001')],
            'icons': ['✨'],
          },
        },
      );
      expect(
        () => StoryPoolCodec.decode(jsonEncode(json)),
        throwsA(isA<StoryPoolFormatException>()),
      );
    });
  });

  group('forward-compat', () {
    test('unknown top-level key parses fine', () {
      final json = validJson();
      json['somethingFromTheFuture'] = 'ignore me';
      expect(() => StoryPoolCodec.decode(jsonEncode(json)), returnsNormally);
    });

    test('unknown per-beat key parses fine', () {
      final beat = beatJson('death_001');
      beat['futureField'] = 'ignore me too';
      final json = validJson(
        tiersOverride: {
          'death': {
            'beats': [beat],
            'icons': ['💀'],
          },
          'survived': {
            'beats': [beatJson('survived_001')],
            'icons': ['🆘'],
          },
          'eternal': {
            'beats': [beatJson('eternal_001')],
            'icons': ['✨'],
          },
        },
      );
      expect(() => StoryPoolCodec.decode(jsonEncode(json)), returnsNormally);
    });
  });

  test('empty beats array for a tier parses; that tier reports isEmpty', () {
    final json = validJson(
      tiersOverride: {
        'death': {
          'beats': <Map<String, dynamic>>[],
          'icons': ['💀'],
        },
        'survived': {
          'beats': [beatJson('survived_001')],
          'icons': ['🆘'],
        },
        'eternal': {
          'beats': [beatJson('eternal_001')],
          'icons': ['✨'],
        },
      },
    );
    final pool = StoryPoolCodec.decode(jsonEncode(json));
    expect(pool.death.beats, isEmpty);
    expect(pool.death.isEmpty, isTrue);
    expect(pool.survived.isEmpty, isFalse);
    expect(pool.eternal.isEmpty, isFalse);
  });

  test('contentVersion defaults to 0 when absent', () {
    final json = validJson(contentVersionOverride: const _Unset());
    final pool = StoryPoolCodec.decode(jsonEncode(json));
    expect(pool.contentVersion, 0);
  });

  test('round trip: decode(encode(pool)) equals original, field for field', () {
    final original = StoryPool(
      contentVersion: 7,
      death: const StoryTierPool(
        beats: [
          StoryBeat(
            id: 'death_001',
            headline: 'H',
            named: '{name} n',
            anonymous: 'a',
          ),
        ],
        icons: ['💀', '⏰️'],
      ),
      survived: const StoryTierPool(
        beats: [
          StoryBeat(
            id: 'survived_001',
            headline: 'H2',
            named: '{name} n2',
            anonymous: 'a2',
          ),
        ],
        icons: ['🆘'],
      ),
      eternal: const StoryTierPool(
        beats: [
          StoryBeat(
            id: 'eternal_001',
            headline: 'H3',
            named: '{name} n3',
            anonymous: 'a3',
          ),
        ],
        icons: ['✨'],
      ),
    );

    final roundTripped = StoryPoolCodec.decode(StoryPoolCodec.encode(original));

    expect(roundTripped.contentVersion, original.contentVersion);
    for (final tierOf in [
      (StoryPool p) => p.death,
      (StoryPool p) => p.survived,
      (StoryPool p) => p.eternal,
    ]) {
      final originalTier = tierOf(original);
      final roundTrippedTier = tierOf(roundTripped);
      expect(roundTrippedTier.icons, originalTier.icons);
      expect(roundTrippedTier.beats.length, originalTier.beats.length);
      for (var i = 0; i < originalTier.beats.length; i++) {
        expect(roundTrippedTier.beats[i].id, originalTier.beats[i].id);
        expect(
          roundTrippedTier.beats[i].headline,
          originalTier.beats[i].headline,
        );
        expect(roundTrippedTier.beats[i].named, originalTier.beats[i].named);
        expect(
          roundTrippedTier.beats[i].anonymous,
          originalTier.beats[i].anonymous,
        );
      }
    }
  });
}

/// Sentinel distinguishing "explicitly omit `contentVersion`" from "set it
/// to null" in `validJson`'s optional-parameter defaulting.
class _Unset {
  const _Unset();
}
