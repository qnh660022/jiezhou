/// Riverpod Providers：所有仓储的全局实例。
library;
import "dart:io" show Platform;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:drift/drift.dart" show DatabaseConnection;
import "package:drift/native.dart";
import "db/database.dart";
import "repo/trips_repo.dart";
import "repo/ledger_repo.dart";
import "repo/categories_repo.dart";
import "repo/checklist_repo.dart";
import "repo/prefs_repo.dart";
import "services/poi_service.dart";
import "services/flight_service.dart";
import "services/weather_service.dart";
import "services/travel_time_service.dart";
import "services/ai_chat_service.dart";
import "services/impl/poi_service_impl.dart";
import "services/impl/flight_service_impl.dart";
import "services/impl/weather_service_impl.dart";
import "services/impl/travel_time_impl.dart";
import "services/impl/ai_chat_service_impl.dart";

/// 数据库单例。
/// flutter_test 环境（FLUTTER_TEST 环境变量由测试运行时注入）下改用内存库：
/// 测试沙箱没有平台通道，path_provider 永不返回会导致首页数据流
/// 永远处于 waiting、骨架屏无限 shimmer、pumpAndSettle 超时。
/// closeStreamsSynchronously 让 drift 在最后一个监听者取消时同步关闭流查询，
/// 避免其内部 Timer.run 缓存批处理在 widget 测试收尾时留下 pending timer。
final dbProvider = Provider<AppDatabase>((_) {
  if (Platform.environment.containsKey("FLUTTER_TEST")) {
    return AppDatabase(DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ));
  }
  return AppDatabase();
});

/// 仓储 providers
final tripsRepoProvider = Provider<TripsRepository>((r) => TripsRepository(r.read(dbProvider)));
final ledgerRepoProvider = Provider<LedgerRepository>((r) => LedgerRepository(r.read(dbProvider), r.read(prefsRepoProvider)));
final categoriesRepoProvider = Provider<CategoriesRepository>((r) => CategoriesRepository(r.read(dbProvider)));
final checklistRepoProvider = Provider<ChecklistRepository>((r) => ChecklistRepository(r.read(dbProvider)));
final prefsRepoProvider = Provider<PrefsRepository>((_) => PrefsRepository());

/// 服务 providers
final poiServiceProvider = Provider<PoiService>((r) => PoiServiceImpl(prefsRepo: r.read(prefsRepoProvider)));
final flightServiceProvider = Provider<FlightService>((_) => FlightServiceImpl());
final weatherServiceProvider = Provider<WeatherService>((_) => WeatherServiceImpl());
final travelTimeServiceProvider = Provider<TravelTimeService>((r) => TravelTimeServiceImpl(prefsRepo: r.read(prefsRepoProvider)));
final aiChatServiceProvider = Provider<AiChatService>((r) => AiChatServiceImpl());

/// AI 助手配置（baseUrl/apiKey/model），改动后 invalidate 使聊天页重新读取。
final aiConfigProvider = FutureProvider<Map<String, dynamic>>((r) => r.read(prefsRepoProvider).getAiConfig());

/// 偏好 shortcuts（激活团 id 统一走 ledger_providers.dart 的 StreamProvider 版本）
final themeKeyProvider = StateProvider<String>((_) => "green");

