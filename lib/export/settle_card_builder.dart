/// 结算单分享卡（V2.7.1 S5 · E1）。
///
/// 把「最少转账方案」从屏幕内列表变成可分享的图片卡。配色一律取
/// `Theme.of(context).colorScheme` 语义色（**不用红绿表示应收应付**），
/// 金额列等宽数字对齐，零转账渲染空态卡。
library;

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../features/ledger/ledger_models.dart';
import '../theme/tokens.dart';

/// 分享卡输入数据（只含转账列表所需的展示信息）。
class SettlementCardData {
  const SettlementCardData({
    required this.groupName,
    required this.roundNo,
    required this.transfers,
    required this.memberNames,
    required this.generatedAt,
    this.completedAtMs,
    this.currencyCode = 'CNY',
    this.strategyLabel = '最少转账',
  });

  final String groupName;
  final int roundNo;

  /// null = 进行中
  final int? completedAtMs;
  final List<TransferView> transfers;

  /// memberId -> 姓名（缺失回退「已移除成员」）
  final Map<String, String> memberNames;
  final String currencyCode;
  final DateTime generatedAt;

  /// 策略脚注（S9：最少转账 / 最少人参与）。
  final String strategyLabel;
}

/// 文件名规范：`settle-round<N>-<yyyyMMdd-HHmm>.png`
String settleCardFileName(int roundNo, DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${at.year}${two(at.month)}${two(at.day)}-${two(at.hour)}${two(at.minute)}';
  return 'settle-round$roundNo-$stamp.png';
}

String _dateLabel(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

String _stampLabel(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// 分享卡本体（放进 RepaintBoundary 后由 [captureBoundaryPng] 出图）。
class SettleCard extends StatelessWidget {
  const SettleCard({super.key, required this.data});

  final SettlementCardData data;

  String _nameOf(String id) {
    final n = data.memberNames[id];
    return (n == null || n.isEmpty) ? '已移除成员' : n;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completed = data.completedAtMs != null;
    return Container(
      width: 420,
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data.groupName} · 第 ${data.roundNo} 轮结算',
            style: TextStyle(
              fontSize: AppFontSizes.title,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            completed ? '完成于 ${_dateLabel(data.completedAtMs!)}' : '进行中',
            style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.lg),
          const Divider(height: 1),
          const SizedBox(height: Spacing.md),
          if (data.transfers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
              child: Center(
                child: Text(
                  '本轮无需转账，账目已平',
                  style: TextStyle(
                      fontSize: AppFontSizes.bodyLarge,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface),
                ),
              ),
            )
          else
            for (final t in data.transfers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_nameOf(t.from)} → ${_nameOf(t.to)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppFontSizes.body, color: scheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Text(
                      '¥${formatMoney(t.cents)}',
                      style: TextStyle(
                        fontSize: AppFontSizes.body,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: Spacing.md),
          const Divider(height: 1),
          const SizedBox(height: Spacing.sm),
          Text(
            '共 ${data.transfers.length} 笔转账 · 已按${data.strategyLabel}方案计算',
            style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            '芥舟 · 生成于 ${_stampLabel(data.generatedAt)}',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
