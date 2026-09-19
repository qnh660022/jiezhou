import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../screens/expense_csv_import_screen.dart';

/// V2.8.1 S7：账本工具箱 —— L3 操作抽屉（零新增路由）。
///
/// 收纳从首页/溢出菜单降级的低频功能：变更记录 / 局域网同步 / CSV 导入 /
/// CSV 导出 / 分类管理。
Future<void> showLedgerToolbox(
  BuildContext context, {
  VoidCallback? onExportCsv,
}) {
  return showDraggableSheet<void>(
    context: context,
    initialChildSize: 0.52,
    minChildSize: 0.4,
    builder: (sheetContext, scrollController) {
      final entries = <_ToolboxEntry>[
        _ToolboxEntry(
          icon: Icons.history_rounded,
          title: '变更记录',
          subtitle: '查看团内每一条数据改动痕迹',
          onTap: () {
            Navigator.of(sheetContext).pop();
            context.pushNamed('audit-log');
          },
        ),
        _ToolboxEntry(
          icon: Icons.lan_rounded,
          title: '局域网同步',
          subtitle: '与身边设备点对点互传数据（不上云）',
          onTap: () {
            Navigator.of(sheetContext).pop();
            context.push('/ledger/lan-sync');
          },
        ),
        _ToolboxEntry(
          icon: Icons.file_upload_outlined,
          title: 'CSV 导入',
          subtitle: '从表格文件批量带入账单',
          onTap: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpenseCsvImportScreen()));
          },
        ),
        if (onExportCsv != null)
          _ToolboxEntry(
            icon: Icons.ios_share_rounded,
            title: 'CSV 导出',
            subtitle: '把当前账单导出为表格文件分享',
            onTap: () {
              Navigator.of(sheetContext).pop();
              onExportCsv();
            },
          ),
        _ToolboxEntry(
          icon: Icons.category_rounded,
          title: '分类管理',
          subtitle: '内置分类之外的自定义分类',
          onTap: () {
            Navigator.of(sheetContext).pop();
            context.pushNamed('categories');
          },
        ),
      ];
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
        children: [
          Text('工具箱', style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: Spacing.xs),
          Text('低频功能都收在这里', style: Theme.of(sheetContext).textTheme.bodySmall),
          const SizedBox(height: Spacing.md),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Material(
                color: Theme.of(sheetContext)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                borderRadius: AppRadius.input,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: Icon(e.icon, color: Theme.of(sheetContext).colorScheme.primary),
                  title: Text(e.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(e.subtitle, style: Theme.of(sheetContext).textTheme.bodySmall),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: e.onTap,
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _ToolboxEntry {
  const _ToolboxEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
