import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/providers.dart';
import 'features/ai/notification_bridge.dart';
import 'features/ledger/ledger_providers.dart' show currencyRatesProvider;
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 竖屏锁定（行程工具类 App 常规选择）
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // 初始化本地存储后注入 ProviderScope，供主题等持久化使用
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TravelAssistantApp(),
    ),
  );
}

/// App 启动后的后台任务挂载点：由 app.dart 首帧后调用一次。
/// 返回关闭句柄（关闭预警→通知桥的订阅）。
///
/// * 预算预警→系统通知桥（只在预警升级时提醒，同级不重复）；
/// * 汇率静默刷新（12h 节流，失败无感）。
void Function() attachStartupServices(WidgetRef ref) {
  final closeBridge = BudgetAlertNotifierBridge(ref).attach();
  Future(() => ref.read(exchangeRateServiceProvider).refreshIfStale().then((updated) {
    if (updated) ref.invalidate(currencyRatesProvider);
  }));
  return closeBridge;
}
