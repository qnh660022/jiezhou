/// 结算分享卡弹层（V2.7.1 S5）：预览 + 分享图片 + 保存图片 + 只读链接。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../export/poster_exporter.dart';
import '../../../export/settle_card_builder.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../shared/widgets/share_link_sheet.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// 打开结算卡弹层（进行中与历史轮次共用）。
Future<void> showSettleCardSheet(
  BuildContext context,
  WidgetRef ref,
  SettlementView settlement,
) async {
  final group = ref.read(activeGroupProvider).value;
  final gid = group?.id ?? ref.read(activeGroupIdProvider).value;
  // 用 repo 取全量成员（含已移除），保证姓名可查（软删成员显示真名）。
  final memberNames = <String, String>{};
  if (gid != null) {
    for (final m in await ref.read(ledgerRepoProvider).getMembers(gid)) {
      memberNames[m.id] = m.name;
    }
  }
  if (!context.mounted) return;
  final data = SettlementCardData(
    groupName: group?.name ?? '账本',
    roundNo: settlement.roundNo,
    completedAtMs: settlement.completedAtMs,
    transfers: settlement.transfers,
    memberNames: memberNames,
    generatedAt: DateTime.now(),
    strategyLabel: settlement.strategy == 'minParticipants' ? '最少人参与' : '最少转账',
  );
  // V2.9.0:裸 showModalBottomSheet 在全局透明 bottomSheet 主题下内容与底页重叠,
  // 统一收口 showDraggableSheet(自带 SheetSurface 玻璃底面 + useRootNavigator)。
  await showDraggableSheet<void>(
    context: context,
    initialChildSize: 0.72,
    minChildSize: 0.4,
    builder: (sheetContext, scrollController) => _SettleCardSheet(
      data: data,
      settlement: settlement,
      scrollController: scrollController,
    ),
  );
}

class _SettleCardSheet extends StatefulWidget {
  const _SettleCardSheet({
    required this.data,
    required this.settlement,
    this.scrollController,
  });

  final SettlementCardData data;
  final SettlementView settlement;

  /// V2.9.0:接 showDraggableSheet 的滚动控制器(拖拽把手联动手势)。
  final ScrollController? scrollController;

  @override
  State<_SettleCardSheet> createState() => _SettleCardSheetState();
}

class _SettleCardSheetState extends State<_SettleCardSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    final msg = await savePosterPng(
        _cardKey, settleCardFileName(widget.data.roundNo, widget.data.generatedAt));
    if (!mounted) return;
    setState(() => _busy = false);
    showAppSnackBar(context, msg);
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    final ok = await sharePosterPng(
      _cardKey,
      settleCardFileName(widget.data.roundNo, widget.data.generatedAt),
      text: '第 ${widget.data.roundNo} 轮结算方案',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    showAppSnackBar(context, ok ? '已调起分享' : '生成图片失败，请重试', tone: SnackTone.destructive);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // V2.9.0:SheetContainer 已处理底部安全区,内层不再包 SafeArea 防双重让位;
    // SingleChildScrollView 挂上抽屉的 scrollController 支持整体拖拽。
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('结算分享卡', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Spacing.sm),
            Text('图片卡只含转账列表，不含账单明细与备注。',
                style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.lg),
            Center(
              child: RepaintBoundary(
                key: _cardKey,
                child: SettleCard(data: widget.data),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            SecondaryButton(
              label: _busy ? '处理中…' : '分享图片',
              expanded: true,
              onPressed: _busy ? null : _share,
            ),
            const SizedBox(height: Spacing.sm),
            SecondaryButton(
              label: '保存图片',
              expanded: true,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: Spacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('复制只读链接'),
              onPressed: () {
                HapticFeedback.selectionClick();
                showShareLinkSheet(context,
                    entityType: 'settle', entityId: widget.settlement.id);
              },
            ),
          ],
        ),
    );
  }
}
