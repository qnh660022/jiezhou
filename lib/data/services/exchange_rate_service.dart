/// 汇率服务抽象接口：拉取真实汇率并写入偏好存储（与用户记忆汇率同源）。
library;

abstract class ExchangeRateService {
  /// 拉取最新汇率（相对人民币）并落盘到 PrefsRepository 的 currencyRates。
  ///
  /// 12 小时节流：距上次成功拉取不足 12h 时直接跳过（返回 false 表示未更新）。
  /// 网络失败静默返回 false，不影响任何 UI 流程。
  Future<bool> refreshIfStale({bool force = false});

  /// 距上次成功拉取的小时数；从未拉取过返回 null。
  Future<int?> hoursSinceLastFetch();
}
