/// 本地系统通知服务：预算预警主动提醒。
///
/// 仅在预警升级（info→warning→danger 跨级）时发一条系统通知，
/// 同级重复不骚扰；通知内容直接用预警引擎的中文文案。
library;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme_provider.dart';
import '../ledger/ledger_providers.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    _initialized = true;
  }

  /// 展示一条普通优先级通知（id 固定按用途，重复调用覆盖旧通知）
  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    await ensureInitialized();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'budget_alerts',
        '预算预警',
        channelDescription: '预算使用达到阈值时提醒',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        styleInformation: BigTextStyleInformation(''),
      ),
    );
    await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
  }
}

/// 预警→通知桥：随预警流监听，只在「最高级别变化」时通知（升级或新触发）。
///
/// 已通知级别存 SharedPreferences key `budget_alert_notified_$gid`，
/// 与预警中心的「已读级别」分开——通知读过没有不等于没发过。
class BudgetAlertNotifierBridge {
  BudgetAlertNotifierBridge(this._ref);
  final WidgetRef _ref;

  String _key(String gid) => 'budget_alert_notified_$gid';

  /// 由 App 启动时调用一次；返回取消订阅的句柄函数。
  /// FLUTTER_TEST 环境下通知插件无平台通道，app.dart 已在测试环境跳过挂载。
  void Function() attach() {
    var lastMaxLevel = -1;

    // 回调发生在 riverpod 通知级联内部：绝不能同步 read provider——
    // 同步 flush 会重入依赖图，在迭代 _dependencies 时触发并发修改异常
    // （Concurrent modification during iteration）。这里把所有读取推迟到
    // 微任务执行，读到的都是通知收敛后的稳定最新态，天然规避竞态。
    void onChange() {
      Future.microtask(() async {
        try {
          final alerts = _ref.read(budgetAlertsProvider);
          final group = _ref.read(activeGroupProvider).value;
          if (group == null || alerts.isEmpty) {
            lastMaxLevel = -1;
            return;
          }
          final enabled = await _ref.read(budgetAlertsEnabledProvider.future);
          if (!enabled) return;
          final maxLevel =
              alerts.map((a) => a.level.index).reduce((a, b) => a > b ? a : b);
          if (maxLevel <= lastMaxLevel) return; // 同级或降级不重复通知
          lastMaxLevel = maxLevel;

          final prefs = _ref.read(sharedPreferencesProvider);
          final notified = int.tryParse(prefs.getString(_key(group.id)) ?? '') ?? -1;
          if (maxLevel > notified) {
            await prefs.setString(_key(group.id), '$maxLevel');
            final worst = alerts
                .firstWhere((a) => a.level.index == maxLevel, orElse: () => alerts.first);
            final levelText = switch (maxLevel) {
              2 => '预算已超支！',
              1 => '预算预警',
              _ => '预算提醒',
            };
            await _ref.read(localNotificationServiceProvider).showBudgetAlert(
                  id: 1001,
                  title: '「${group.name}」$levelText',
                  body: worst.messageCn,
                );
          }
        } catch (_) {
          // 通知失败无感：桥只是增值提醒，任何异常都不能冒泡进 riverpod 通知循环。
        }
      });
    }

    final sub1 = _ref.listenManual(budgetAlertsProvider, (_, __) => onChange());
    final sub2 = _ref.listenManual(activeGroupProvider, (_, __) {
      lastMaxLevel = -1;
      onChange();
    });
    // 延迟到微任务再首查：attach 发生在首帧渲染之后，但同步读 provider
    // 仍会触发 riverpod 的并发修改异常，统一走微任务。
    Future.microtask(onChange);
    return () {
      sub1.close();
      sub2.close();
    };
  }
}

final localNotificationServiceProvider =
    Provider<LocalNotificationService>((_) => LocalNotificationService());
