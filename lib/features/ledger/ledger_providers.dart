/// 记账线数据桥接层（barrel 文件）。
///
/// 【G4 拆分（V2.7.1 S2）】原单体文件（约 29KB：视图转换 + Provider + Repo 调用 +
/// 全部 Action）已拆分到 `ledger_providers/` 目录：
///
/// * `bills.dart`  —— 账单视图转换 + 增删改 Action
/// * `settle.dart` —— 净额、结算轮、转账确认、撤销
/// * `stats.dart`  —— 统计与预算
/// * `io_csv.dart` —— 导入导出、备份、快照、CSV
/// * `groups.dart` —— 团、成员、分类
///
/// 本文件**保留为 barrel**：`export` 上述全部文件，因此
/// `import '.../ledger_providers.dart'`（含
/// `space_detail_screen.dart` 的 `import ... show activateGroup`）与全部屏幕
/// **零改动**。纯重构，不改任何行为、Provider 名与 Action 签名。
library;

export 'ledger_providers/bills.dart';
export 'ledger_providers/funds.dart';
export 'ledger_providers/groups.dart';
export 'ledger_providers/inbox.dart';
export 'ledger_providers/io_csv.dart';
export 'ledger_providers/settle.dart';
export 'ledger_providers/stats.dart';
export 'ledger_providers/sub_budgets.dart'; // V2.8.1 分类子预算
