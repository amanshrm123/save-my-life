import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ad_service.dart';
import '../application/fake_ad_service.dart';

/// Kept-alive for the whole app session — a single `FakeAdService` instance
/// (architecture v3 §5), never `.autoDispose`.
final Provider<AdService> adServiceProvider = Provider<AdService>((ref) => FakeAdService());
