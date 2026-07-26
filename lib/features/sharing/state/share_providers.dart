import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/card_renderer.dart';
import '../application/share_service.dart';

final Provider<CardRenderer> cardRendererProvider = Provider<CardRenderer>(
  (ref) => const CardRenderer(),
);

final Provider<ShareService> shareServiceProvider = Provider<ShareService>(
  (ref) => const ShareService(),
);
