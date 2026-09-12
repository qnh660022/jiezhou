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

/// 当前正在生成的攻略草稿城市 key（AI 生成攻略用）。
///
/// 工具执行器每轮都会新建，草稿 key 必须落在 provider 里才能跨工具调用传递。
final guideDraftKeyProvider = StateProvider<String?>((ref) => null);
