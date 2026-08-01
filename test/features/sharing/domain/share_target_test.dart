import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/sharing/domain/share_target.dart';

/// Pure unit coverage for `ShareTarget`/dimmed-state logic (architecture v5
/// §4/§8/§9). `kFbAppId` is a compile-time `String.fromEnvironment` const —
/// this test suite never overrides it (no `--dart-define=FB_APP_ID=...` is
/// passed for `flutter test`), so it is always the empty string here,
/// exactly like a dev build without the define (architecture §9's "degrade
/// gracefully" case).
void main() {
  group('ShareTarget order and labels', () {
    test('fixed order: Instagram, WhatsApp, Facebook (architecture §4)', () {
      expect(ShareTarget.values, [
        ShareTarget.instagramStory,
        ShareTarget.whatsappStatus,
        ShareTarget.facebookStory,
      ]);
    });

    test('brand name + surface label per tile (design §4)', () {
      expect(ShareTarget.instagramStory.brandName, 'Instagram');
      expect(ShareTarget.instagramStory.surfaceLabel, 'Story');
      expect(ShareTarget.whatsappStatus.brandName, 'WhatsApp');
      expect(ShareTarget.whatsappStatus.surfaceLabel, 'Status');
      expect(ShareTarget.facebookStory.brandName, 'Facebook');
      expect(ShareTarget.facebookStory.surfaceLabel, 'Story');
    });
  });

  group('shareTargetFromWireName', () {
    test('round-trips every ShareTarget.name', () {
      for (final target in ShareTarget.values) {
        expect(shareTargetFromWireName(target.name), target);
      }
    });

    test('returns null for an unrecognised wire name', () {
      expect(shareTargetFromWireName('twitterStory'), isNull);
      expect(shareTargetFromWireName(''), isNull);
    });
  });

  group('isShareTargetDimmed', () {
    test('kFbAppId is empty by default (no --dart-define in test runs)', () {
      expect(kFbAppId, isEmpty);
    });

    test('WhatsApp is dimmed purely on install state, never on FB_APP_ID', () {
      expect(
        isShareTargetDimmed(ShareTarget.whatsappStatus, const []),
        isTrue,
        reason: 'not in installedTargets -> dimmed',
      );
      expect(
        isShareTargetDimmed(ShareTarget.whatsappStatus, const [ShareTarget.whatsappStatus]),
        isFalse,
        reason: 'installed and needs no App ID -> never dimmed regardless of kFbAppId',
      );
    });

    test(
      'Instagram/Facebook are dimmed when FB_APP_ID is empty, even if '
      'reported installed (architecture §9: empty App ID == "not installed")',
      () {
        expect(
          isShareTargetDimmed(ShareTarget.instagramStory, const [ShareTarget.instagramStory]),
          isTrue,
        );
        expect(
          isShareTargetDimmed(ShareTarget.facebookStory, const [ShareTarget.facebookStory]),
          isTrue,
        );
      },
    );

    test('Instagram/Facebook also dimmed when simply not installed', () {
      expect(isShareTargetDimmed(ShareTarget.instagramStory, const []), isTrue);
      expect(isShareTargetDimmed(ShareTarget.facebookStory, const []), isTrue);
    });

    test(
      'Instagram/Facebook are NOT dimmed when a non-empty fbAppId is passed '
      'and the target is installed (architecture §9 Phase 5b path, exercised '
      'via the optional fbAppId param since kFbAppId itself is a compile-time '
      'constant that cannot be overridden at test-run time)',
      () {
        expect(
          isShareTargetDimmed(
            ShareTarget.instagramStory,
            const [ShareTarget.instagramStory],
            fbAppId: '1234567890',
          ),
          isFalse,
        );
        expect(
          isShareTargetDimmed(
            ShareTarget.facebookStory,
            const [ShareTarget.facebookStory],
            fbAppId: '1234567890',
          ),
          isFalse,
        );
      },
    );

    test(
      'a non-empty fbAppId does not override a genuine not-installed state '
      'for Instagram/Facebook',
      () {
        expect(
          isShareTargetDimmed(ShareTarget.instagramStory, const [], fbAppId: '1234567890'),
          isTrue,
        );
        // Facebook's own symmetric case (tester-stage gap: only Instagram was
        // exercised here previously) — this is exactly QA scenario (a): App
        // ID configured but the target itself isn't actually resolvable
        // (canOpenURL false / not in installedTargets), so the sheet must
        // still dim it rather than treating a configured App ID as "always
        // light it up".
        expect(
          isShareTargetDimmed(ShareTarget.facebookStory, const [], fbAppId: '1234567890'),
          isTrue,
          reason: 'App ID alone must not override a genuine not-installed state for Facebook either',
        );
      },
    );
  });
}
