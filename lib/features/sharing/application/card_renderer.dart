import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Captures the outcome card's `RepaintBoundary` to a reused temp PNG file
/// (architecture v3 §4/§11 risk 2).
///
/// Memory-safety discipline: the `ui.Image` returned by `toImage` is
/// disposed as soon as its PNG bytes are extracted (native image memory
/// doesn't linger); the same filename is overwritten on every call so cache
/// files never accumulate. If the boundary's `GlobalKey.currentContext` is
/// null (the screen is gone) this aborts cleanly with `null` rather than
/// throwing. Callers are still responsible for their own `mounted` guards
/// around the `await` (this class has no widget lifecycle of its own).
///
/// Writes to `<getTemporaryDirectory()>/share/share_card.png` (architecture
/// v5 §6/§11), not the temp-dir root: `share_plus`'s own bundled
/// `FileProvider` only exposes its private `share_plus/` cache subdir, so
/// the new `SocialSharePlugin`'s dedicated `FileProvider` is scoped to this
/// app-owned `share/` subdir instead of squatting on another plugin's
/// authority. The single fixed filename is preserved (now inside `share/`)
/// so cache files still never accumulate, and the "More…" `share_plus` path
/// is unaffected — it takes a raw path and copies it into its own provider
/// regardless of which directory that path lives in.
class CardRenderer {
  const CardRenderer();

  static const String _subDir = 'share';
  static const String _fileName = 'share_card.png';

  Future<File?> renderToFile(GlobalKey boundaryKey, {double pixelRatio = 3}) async {
    final renderContext = boundaryKey.currentContext;
    if (renderContext == null) return null;

    final renderObject = renderContext.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    ui.Image? image;
    try {
      image = await renderObject.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final Uint8List bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final shareDir = Directory('${tempDir.path}/$_subDir');
      if (!await shareDir.exists()) {
        await shareDir.create(recursive: true);
      }
      final file = File('${shareDir.path}/$_fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
    }
  }
}
