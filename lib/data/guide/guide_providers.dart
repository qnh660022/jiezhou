/// 攻略 Riverpod providers（§7.4）。
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart' show tripsRepoProvider;
import 'guide_cache.dart';
import 'guide_crawler.dart';
import 'guide_http.dart';
import 'guide_service.dart';

/// 服务单例（攻略与同步层完全隔离，纯本地不云端）。
final guideServiceProvider = Provider<GuideService>((ref) => GuideService(
      cache: GuideCache(),
      http: GuideHttp.instance,
      crawlLayer: GuideCrawlLayer(GuideHttp.instance),
    ));

/// 行程攻略 future（extra 传 tripId+destination）。
final guideByTripProvider =
    FutureProvider.family<GuideResult, String>((ref, tripId) async {
  final trip = await ref.read(tripsRepoProvider).getById(tripId);
  final dest = trip?.destination ?? '';
  return ref.read(guideServiceProvider).getGuide(dest);
});
