import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/sharing/application/social_share_service.dart';
import 'package:timing_tap/features/sharing/domain/share_target.dart';

/// Mocks the native `com.timingtap.timing_tap/social_share` channel
/// (architecture v5 §10) — real Android intents can't fire under
/// `flutter test`, so this asserts the Dart side calls the channel with the
/// right method/arguments per target, and correctly maps the channel's
/// return value/thrown `PlatformException` back to `SocialShareResult`
/// (success / not-installed / activity-not-found).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.timingtap.timing_tap/social_share');
  final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    binding.setMockMethodCallHandler(channel, null);
  });

  group('installedTargets', () {
    test('maps the raw wire-format List<String> back to ShareTarget values', () async {
      binding.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'installedTargets');
        return <String>['whatsappStatus', 'instagramStory'];
      });

      final result = await const SocialShareService().installedTargets();
      expect(result, [ShareTarget.whatsappStatus, ShareTarget.instagramStory]);
    });

    test('ignores unrecognised wire names rather than throwing', () async {
      binding.setMockMethodCallHandler(channel, (call) async {
        return <String>['whatsappStatus', 'someFutureTarget'];
      });

      final result = await const SocialShareService().installedTargets();
      expect(result, [ShareTarget.whatsappStatus]);
    });

    test('fails soft to an empty list on a PlatformException', () async {
      binding.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'BOOM');
      });

      final result = await const SocialShareService().installedTargets();
      expect(result, isEmpty);
    });
  });

  group('shareToStory', () {
    test('invokes the channel with the exact method name and argument shape', () async {
      MethodCall? recorded;
      binding.setMockMethodCallHandler(channel, (call) async {
        recorded = call;
        return true;
      });

      final result = await const SocialShareService().shareToStory(
        target: ShareTarget.whatsappStatus,
        stickerPath: '/tmp/share/share_card.png',
        topColor: const Color(0xFFF0483E),
        bottomColor: const Color(0xFF1F2A2E),
        fbAppId: '',
      );

      expect(recorded, isNotNull);
      expect(recorded!.method, 'shareToStory');
      expect(recorded!.arguments, {
        'target': 'whatsappStatus',
        'stickerPath': '/tmp/share/share_card.png',
        'topColor': '#f0483e',
        'bottomColor': '#1f2a2e',
        'fbAppId': '',
      });
      expect(result.isSuccess, isTrue);
      expect(result.outcome, SocialShareOutcome.success);
    });

    test('a false channel return maps to activityNotFound', () async {
      binding.setMockMethodCallHandler(channel, (call) async => false);

      final result = await const SocialShareService().shareToStory(
        target: ShareTarget.instagramStory,
        stickerPath: '/tmp/share/share_card.png',
        topColor: const Color(0xFFF0483E),
        bottomColor: const Color(0xFF1F2A2E),
      );

      expect(result.isSuccess, isFalse);
      expect(result.outcome, SocialShareOutcome.activityNotFound);
    });

    test('a NOT_INSTALLED PlatformException maps to SocialShareOutcome.notInstalled', () async {
      binding.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'NOT_INSTALLED', message: 'com.whatsapp did not resolve');
      });

      final result = await const SocialShareService().shareToStory(
        target: ShareTarget.whatsappStatus,
        stickerPath: '/tmp/share/share_card.png',
        topColor: const Color(0xFFF0483E),
        bottomColor: const Color(0xFF1F2A2E),
      );

      expect(result.outcome, SocialShareOutcome.notInstalled);
    });

    test(
      'an ACTIVITY_NOT_FOUND (or any other) PlatformException maps to activityNotFound',
      () async {
        binding.setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'ACTIVITY_NOT_FOUND', message: 'boom');
        });

        final result = await const SocialShareService().shareToStory(
          target: ShareTarget.facebookStory,
          stickerPath: '/tmp/share/share_card.png',
          topColor: const Color(0xFFF0483E),
          bottomColor: const Color(0xFF1F2A2E),
        );

        expect(result.outcome, SocialShareOutcome.activityNotFound);
      },
    );
  });
}
