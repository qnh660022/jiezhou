/// Riverpod Providers：所有仓储的全局实例。
library;
import "package:flutter_riverpod/flutter_riverpod.dart";
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
import "services/exchange_rate_service.dart";
import "services/impl/poi_service_impl.dart";
import "services/impl/flight_service_impl.dart";
import "services/impl/weather_service_impl.dart";
import "services/impl/travel_time_impl.dart";
import "services/impl/ai_chat_service_impl.dart";
import "services/impl/exchange_rate_service_impl.dart";

/// 数据库单例。
/// 平台连接由 [AppDatabase] 默认构造经平台门面解析：
///   原生 = Documents 文件库；测试 = 内存库；Web = sqlite-WASM(IndexedDB)。
/// closeStreamsSynchronously 已由 io 门面在测试路径设置。
final dbProvider = Provider<AppDatabase>((_) => AppDatabase());

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
final exchangeRateServiceProvider = Provider<ExchangeRateService>((r) => ExchangeRateServiceImpl(r.read(prefsRepoProvider)));

/// AI 助手配置（baseUrl/apiKey/model），改动后 invalidate 使聊天页重新读取。
final aiConfigProvider = FutureProvider<Map<String, dynamic>>((r) => r.read(prefsRepoProvider).getAiConfig());

/// 偏好 shortcuts（激活团 id 统一走 ledger_providers.dart 的 StreamProvider 版本）
final themeKeyProvider = StateProvider<String>((_) => "green");

