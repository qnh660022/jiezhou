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

  // 竖屏锁定：**不 await**。部分 Android 机型/ROM（尤其国产定制系统）上
  // SystemChrome.setPreferredOrientations 的平台通道偶发不回调，若在 runApp
  // 之前 await，首帧将永远无法渲染 —— 表现就是「开机白屏，清后台重试才好」。
  // 改为 fire-and-forget：失败无感，首帧绝不阻塞；getSystemUIOverlayStyle 同步调用无此问题。
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // 初始化本地存储后注入 ProviderScope，供主题等持久化使用。
  // 加 4s 超时兜底：SharedPreferences 极少数情况下（进程被强杀后文件未释放 /
  // 平台通道竞态）也会挂起，这里一旦超时立即切换到内存实现，保证 runApp
  // 最迟 4 秒内必然执行 —— 白屏的第二个根因也被封死。
  final prefs = await _loadPrefs();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TravelAssistantApp(),
    ),
  );
}

/// 安全的 SharedPreferences 装载：正常路径直接返回；
/// 超时 / 异常路径切换到内存 mock 实现（仅本次会话丢失持久化，功能可正常使用）。
Future<SharedPreferences> _loadPrefs() async {
  try {
    return await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 4));
  } catch (_) {
    // setMockInitialValues 把平台通道后端替换为内存实现，
    // 之后的 getInstance 立即完成，不再触碰真正的磁盘存储。
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    return await SharedPreferences.getInstance();
  }
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
