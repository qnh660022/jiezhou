import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/error_recovery.dart';
import 'core/supabase_config.dart';
import 'data/sync/sync_control_providers.dart' show bootstrapCloud;
import 'data/providers.dart';
import 'features/ai/notification_bridge.dart';
import 'features/ledger/ledger_providers.dart' show currencyRatesProvider;
import 'platform/context_menu_guard.dart';
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

  // 云后端接入（V2.6 §3.2.3）：resolve 有效则初始化 Supabase；整个步骤 4s 超时，
  // 超时/异常都继续启动（云功能按未配置处理），绝不让网络 await 挡首帧。
  await _initSupabaseQuiet(prefs);

  // 全局错误兜底：release 灰屏 → 自动记录堆栈 + 启动窗口期自愈重启 +
  // 可读错误屏（重启/复制按钮）。必须在 runApp 之前装好。
  installGlobalErrorHandlers();

  // Web 端屏蔽浏览器原生右键菜单（桌面工作台提供自定义右键菜单）；原生为空实现。
  disableBrowserContextMenu();

  runApp(_BootGate(prefs: prefs));
}

/// 应用树外壳：监听 [appEpoch]，自愈/手动重启时换 key 强制整树 remount
/// （含 ProviderScope 全新容器与开屏页重播），无需杀进程。
class _BootGate extends StatefulWidget {
  const _BootGate({required this.prefs});

  final SharedPreferences prefs;

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  @override
  void initState() {
    super.initState();
    appEpoch.addListener(_onEpochChanged);
  }

  void _onEpochChanged() => setState(() {});

  @override
  void dispose() {
    appEpoch.removeListener(_onEpochChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey('app-tree-${appEpoch.value}'),
      child: ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(widget.prefs)],
        child: const TravelAssistantApp(),
      ),
    );
  }
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

/// 云后端静默初始化：resolve → Supabase.initialize；4s 超时或异常都静默跳过，
/// 会话恢复由 supabase_flutter 内部处理（不额外 await）。
Future<void> _initSupabaseQuiet(SharedPreferences prefs) async {
  try {
    final cfg = SupabaseCfg.resolveSync(prefs);
    if (cfg == null) return;
    await Supabase.initialize(
      url: cfg.url,
      anonKey: cfg.anonKey,
      debug: false,
    ).timeout(const Duration(seconds: 4));
  } catch (_) {
    // 初始化失败：云功能按未配置处理，不影响本地功能。
  }
}

/// App 启动后的后台任务挂载点：由 app.dart 首帧后调用一次。
/// 返回关闭句柄（关闭预警/同步通知桥的订阅）。
///
/// * 预算预警→系统通知桥（只在预警升级时提醒，同级不重复）；
/// * 同步失败/恢复→系统通知桥（§3.18）；
/// * 汇率静默刷新（12h 节流，失败无感）。
void Function() attachStartupServices(WidgetRef ref) {
  // 云引擎先就绪（幂等；app.dart 首帧也会调一次，重复调用直接复用），
  // 同步失败/恢复通知桥要等引擎建好后才能挂接，故放异步段。
  Future(() async {
    try {
      await bootstrapCloud(ref);
    } catch (_) {}
    try {
      final closeSync = SyncNotifierBridge(ref).attach();
      _startupClosers.add(closeSync);
    } catch (_) {}
  });
  final closeBridge = BudgetAlertNotifierBridge(ref).attach();
  _startupClosers.add(closeBridge);
  Future(() async {
    try {
      final updated = await ref.read(exchangeRateServiceProvider).refreshIfStale();
      if (updated) ref.invalidate(currencyRatesProvider);
    } catch (_) {
      // 汇率刷新失败无感（12h 后会再试），不产生未捕获异步错误。
    }
  });
  return () {
    for (final c in _startupClosers) {
      c();
    }
    _startupClosers.clear();
  };
}

final List<void Function()> _startupClosers = [];
