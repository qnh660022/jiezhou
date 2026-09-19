/// 增减天数弹层（V2.7.2 S2，三宿主共用组件）。
///
/// - 「插入一天」：天序选择列表（最前 / 第 1..N 天后），返回 k（0..N，0=最前）；
/// - 「删除此天」：三选一（顺延到次日 / 并入前一日 / 丢弃安排），
///   k==1 时「并入前一日」禁用、k==N 时「顺延到次日」不渲染（末天无次日可承接），
///   正文列明「将影响 X 张安排卡」，返回 [RemoveMode]；
/// - 移动端走底部抽屉（[showDayInsertPicker] / [showDayRemovePicker]）；
///   桌面 Workbench 用 [openAsDialog] 打开 [DayInsertPickerPanel] /
///   [DayRemovePickerPanel]（对话框形态）。
/// - 空间 viewer 不渲染入口（隐藏不置灰），由调用方保证。
library;
import 'package:flutter/material.dart';

import '../../../data/db/database.dart';
import '../../../data/repo/trips_repo.dart';
import '../../../domain/day_shift_engine.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// 「插入一天」天序面板（纯内容，宿主决定容器）。
class DayInsertPickerPanel extends StatelessWidget {
  const DayInsertPickerPanel({super.key, required this.n, required this.onPick});

  /// 行程天数 N ≥ 1
  final int n;

  /// 选中插入位置：0=最前，1..N=第 k 天后（k==N 即最末）
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PanelScaffold(
      title: '插入一天',
      subtitle: '选择插入位置，其后所有安排自动顺延一天',
      scheme: scheme,
      children: [
        _OptionTile(
          icon: Icons.first_page_rounded,
          title: '最前（出发前新增一天）',
          onTap: () => onPick(0),
        ),
        for (var i = 1; i <= n; i++)
          _OptionTile(
            icon: i == n ? Icons.last_page_rounded : Icons.add_circle_outline_rounded,
            title: '第 $i 天后${i == n ? '（最末）' : ''}',
            subtitle: i == n ? '在行程末尾追加一天' : null,
            onTap: () => onPick(i),
          ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

/// 「删除此天」三选一面板（纯内容，宿主决定容器）。
class DayRemovePickerPanel extends StatelessWidget {
  const DayRemovePickerPanel({
    super.key,
    required this.k,
    required this.n,
    required this.affectedCount,
    required this.onPick,
  });

  /// 被删天序号（1..N）
  final int k;

  /// 行程天数 N ≥ 2（N==1 时入口已被隐藏，不进本面板）
  final int n;
  final int affectedCount;
  final ValueChanged<RemoveMode> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final countText = affectedCount > 0 ? '将影响 $affectedCount 张安排卡' : '当天暂无安排卡';
    return _PanelScaffold(
      title: '删除第 $k 天',
      subtitle: '$countText · 行程将缩短为 ${n - 1} 天，操作不可恢复',
      scheme: scheme,
      children: [
        if (k < n)
          _OptionTile(
            icon: Icons.redo_rounded,
            title: '顺延到次日',
            subtitle: '当天安排整体移到后一天末尾',
            onTap: () => onPick(RemoveMode.shift),
          ),
        _OptionTile(
          icon: Icons.undo_rounded,
          title: '并入前一日',
          subtitle: k == 1 ? '第 1 天没有前一天，不可用' : '当天安排整体移到前一天末尾',
          enabled: k > 1,
          onTap: k > 1 ? () => onPick(RemoveMode.merge) : null,
        ),
        _OptionTile(
          icon: Icons.delete_outline_rounded,
          destructive: true,
          title: '丢弃安排',
          subtitle: affectedCount > 0 ? '当天 $affectedCount 张安排卡将被删除' : '无安排卡可删',
          onTap: () => onPick(RemoveMode.discard),
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

/// 移动端：底部抽屉打开「插入一天」。返回插入位置 k（0..N）；取消返回 null。
Future<int?> showDayInsertPicker(BuildContext context, {required int n}) {
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // V2.8.3.1：内容包 SheetSurface（此前透明底上裸放内容，会与页面文字重叠，
    // 与 sheet.dart 登记的「字与底面重叠」同根因）；barrier 对齐统一入口。
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (_) => SheetSurface(
      child: DayInsertPickerPanel(n: n, onPick: Navigator.of(context).pop),
    ),
  );
}

/// 移动端：底部抽屉打开「删除此天」三选一。返回承接模式；取消返回 null。
Future<RemoveMode?> showDayRemovePicker(
  BuildContext context, {
  required int k,
  required int n,
  required int affectedCount,
}) {
  return showModalBottomSheet<RemoveMode>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // V2.8.3.1：同上 —— 补包 SheetSurface + 统一 barrier。
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (_) => SheetSurface(
      child: DayRemovePickerPanel(
        k: k,
        n: n,
        affectedCount: affectedCount,
        onPick: Navigator.of(context).pop,
      ),
    ),
  );
}

// ===== 完整流程（桌面 Workbench 用；弹面板 + 执行引擎 + 落库） =====

/// 桌面：插入一天完整流程。
/// V2.8.2 S6：AlertDialog → 统一可拖拽抽屉（L3 选择抽屉口径）。
Future<void> runInsertDayDialog(
  BuildContext context, {
  required TripsRepository repo,
  required Trip trip,
  required List<TripItem> items,
}) async {
  final n = tripDaysOf(trip.startEpochDay, trip.endEpochDay);
  if (n < 1) return;
  final k = await showDraggableSheet<int>(
    context: context,
    initialChildSize: 0.44,
    minChildSize: 0.28,
    builder: (dialogContext, scrollController) => ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.xl),
      children: [
        DayInsertPickerPanel(n: n, onPick: Navigator.of(dialogContext).pop),
      ],
    ),
  );
  if (k == null || !context.mounted) return;
  final ops = insertDay(
    startEpochDay: trip.startEpochDay,
    endEpochDay: trip.endEpochDay,
    items: [for (final r in items) TripsRepository.tripItemToRecord(r)],
    k: k,
  );
  await repo.applyDayOps(trip.id, ops);
  _toastOf(context, '已插入一天，后续安排自动顺延');
}

/// 桌面：删除一天完整流程（[k] 为天序号 1..N，[affectedCount] 为该天卡数）。
Future<void> runRemoveDayDialog(
  BuildContext context, {
  required TripsRepository repo,
  required Trip trip,
  required List<TripItem> items,
  required int k,
  required int affectedCount,
}) async {
  final n = tripDaysOf(trip.startEpochDay, trip.endEpochDay);
  if (n < 2 || k < 1 || k > n) return;
  // V2.8.2 S6：AlertDialog → 统一可拖拽抽屉
  final mode = await showDraggableSheet<RemoveMode>(
    context: context,
    initialChildSize: 0.44,
    minChildSize: 0.28,
    builder: (dialogContext, scrollController) => ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.xl),
      children: [
        DayRemovePickerPanel(
          k: k,
          n: n,
          affectedCount: affectedCount,
          onPick: Navigator.of(dialogContext).pop,
        ),
      ],
    ),
  );
  if (mode == null || !context.mounted) return;
  try {
    final ops = removeDay(
      startEpochDay: trip.startEpochDay,
      endEpochDay: trip.endEpochDay,
      items: [for (final r in items) TripsRepository.tripItemToRecord(r)],
      k: k,
      mode: mode,
    );
    await repo.applyDayOps(trip.id, ops);
    final text = switch (mode) {
      RemoveMode.shift => '已删除第 $k 天，安排顺延到次日',
      RemoveMode.merge => '已删除第 $k 天，安排并入前一日',
      RemoveMode.discard => '已删除第 $k 天及其安排',
    };
    if (context.mounted) _toastOf(context, text);
  } on StateError catch (e) {
    if (context.mounted) _toastOf(context, e.message);
  }
}

void _toastOf(BuildContext context, String message) {
  // V2.8.3.3：收口到全 App 唯一轻提示形态（L1）。
  showAppSnackBar(context, message);
}

/// 行程天数（与 core/date_utils.tripDays 同口径，避免 UI 层多余 import）。
int tripDaysOf(int startEpochDay, int endEpochDay) {
  if (endEpochDay < startEpochDay) return 0;
  return endEpochDay - startEpochDay + 1;
}

class _PanelScaffold extends StatelessWidget {
  const _PanelScaffold({
    required this.title,
    required this.subtitle,
    required this.scheme,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.destructive = false,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool destructive;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = !enabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
        : destructive
            ? scheme.error
            : scheme.onSurface;
    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: icon == null ? null : Icon(icon, color: color, size: 22),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: enabled ? 1 : 0.5))),
      onTap: onTap,
    );
  }
}
