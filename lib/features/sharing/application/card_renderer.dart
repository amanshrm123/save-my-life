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
class CardRenderer {
  const CardRenderer();

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
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
    }
  }
}
