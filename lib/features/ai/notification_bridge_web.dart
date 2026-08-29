/// Web：系统通知空实现。不做任何系统弹窗，桥仍监听预警仅用于状态维护
/// （public API 与 io 版本保持一致，消费方无需分支）。
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalNotificationService {
  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    // Web 不支持系统通知，忽略。
  }
}

class BudgetAlertNotifierBridge {
  BudgetAlertNotifierBridge(this._ref);
  final WidgetRef _ref;

  void Function() attach() => () {};
}

final localNotificationServiceProvider =
    Provider<LocalNotificationService>((_) => LocalNotificationService());