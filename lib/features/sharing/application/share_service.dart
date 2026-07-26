import 'dart:io';

import 'package:share_plus/share_plus.dart';

/// Thin wrapper over `share_plus` (architecture v3 §4) — the native OS share
/// sheet supplies the target list (Stories/WhatsApp/Copy/More); this app
/// never builds its own sheet UI (design v3 §3.1).
class ShareService {
  const ShareService();

  /// Shares [file] with [text]. Returns true only when the native sheet
  /// reports a completed share action — callers use this to decide whether
  /// to show the "Shared" confirm toast (design v3 §3.2).
  Future<bool> shareFile(File file, {required String text}) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: text),
      );
      return result.status == ShareResultStatus.success;
    } catch (_) {
      return false;
    }
  }
}
