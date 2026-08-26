// 🗂️ 安排详情：按类型主题化的只读详情页。
// 点击行程时间轴里的安排进入本页；顶栏与底部均提供「编辑」入口，进入 ItemEditScreen。
// 数据经 tripsRepoProvider 流驱动，编辑保存返回后本页自动刷新。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';
import 'item_edit_screen.dart';

/// 安排详情页（按 itemId 流式定位，编辑后自动刷新）。
class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key, required this.tripId, required this.itemId});

  final String tripId;
  final String itemId;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  void _openEdit(TripItem item) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => ItemEditScreen(tripId: widget.tripId, item: item),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(tripsRepoProvider);
    return StreamBuilder<List<TripItem>>(
      stream: repo.watchItems(widget.tripId),
      builder: (context, itemsSnap) {
        final items = itemsSnap.data ?? const <TripItem>[];
        TripItem? found;
        for (final it in items) {
          if (it.id == widget.itemId) {
            found = it;
            break;
          }
        }
        if (found == null) {
          return Scaffold(
            appBar: GlassAppBar(title: '安排详情'),
            body: const EmptyState(
              emoji: '🗺️',
              title: '该安排不存在或已删除',
              message: '返回行程重新看看',
            ),
          );
        }
        final item = found; // 提升为非空，闭包内可直接引用
        return StreamBuilder<Trip?>(
          stream: repo.watchTrip(widget.tripId),
          builder: (context, tripSnap) =>
              _DetailView(item: item, trip: tripSnap.data, onEdit: () => _openEdit(item)),
        );
      },
    );
  }
}

/// 详情主体：渐变头图 + 类型主题信息卡 + 底部编辑按钮。
class _DetailView extends StatelessWidget {
  const _DetailView({required this.item, required this.trip, required this.onEdit});

  final TripItem item;
  final Trip? trip;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final visual = tripTypeVisual(item.type);
    final isTransport = item.type == 'transport';
    final isNote = item.type == 'note';

    return Scaffold(
      appBar: GlassAppBar(
        title: item.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: '编辑安排',
            onPressed: onEdit,
          ),
          const SizedBox(width: Spacing.xs),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroCard(item: item, trip: trip, visual: visual),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isTransport)
                    _TransportCard(item: item, color: visual.color),
                  if (isNote)
                    _NoteCard(item: item)
                  else ...[
                    _BasicCard(item: item, visual: visual),
                    if (item.note.isNotEmpty)
                      _NoteCard(item: item),
                  ],
                  const SizedBox(height: Spacing.xl),
                  PrimaryButton(
                    label: '编辑安排',
                    icon: Icons.edit_rounded,
                    expanded: true,
                    onPressed: onEdit,
                  ),
                  const SizedBox(height: Spacing.huge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 渐变头图：类型色渐变 + 大 emoji + 类型胶囊 + 名称 + 日期/地址元信息。
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.item, required this.trip, required this.visual});

  final TripItem item;
  final Trip? trip;
  final TripTypeVisual visual;

  @override
  Widget build(BuildContext context) {
    final dayIndex = trip == null ? null : item.dateEpochDay - trip!.startEpochDay + 1;
    final dateText = trip == null
        ? cnFullDate(item.dateEpochDay)
        : '第 $dayIndex 天 · ${cnFullDate(item.dateEpochDay)}';
    final c1 = visual.color;
    final c2 = Color.lerp(visual.color, Colors.white, 0.3)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, 0),
      padding: const EdgeInsets.all(Spacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
        borderRadius: AppRadius.card,
        boxShadow: [
          BoxShadow(
            color: c1.withValues(alpha: 0.32),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Text(visual.icon, style: const TextStyle(fontSize: 40)),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.md, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.26),
                        borderRadius: AppRadius.capsule,
                      ),
                      child: Text(
                        visual.name,
                        style: TextStyle(
                          fontSize: AppFontSizes.caption - 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppFontSizes.title,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          if (item.startTimeMin != null) ...[
            _HeroMeta(icon: Icons.schedule_rounded, text: hhmm(item.startTimeMin!)),
            const SizedBox(height: Spacing.sm),
          ],
          _HeroMeta(icon: Icons.event_rounded, text: dateText),
          if (item.address.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            _HeroMeta(icon: Icons.place_rounded, text: item.address),
          ],
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.92)),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppFontSizes.caption + 1,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ),
      ],
    );
  }
}

/// 交通专属：出发地 → 到达地 + 航班号。
class _TransportCard extends StatelessWidget {
  const _TransportCard({required this.item, required this.color});

  final TripItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fromName = item.fromName;
    final toName = item.toName;
    final hasRoute = fromName.isNotEmpty || toName.isNotEmpty;
    final hasFlight = (item.flightNo ?? '').isNotEmpty;
    if (!hasRoute && !hasFlight) return const SizedBox.shrink();

    return SectionCard(
      color: color.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, size: 18, color: color),
              const SizedBox(width: Spacing.sm),
              Text('行程',
                  style: TextStyle(
                      fontSize: AppFontSizes.bodyLarge,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
          const SizedBox(height: Spacing.md),
          if (hasRoute)
            Row(
              children: [
                Expanded(
                  child: _RouteNode(
                    label: '出发',
                    name: fromName.isEmpty ? '未填写' : fromName,
                    sub: item.fromAddress,
                    color: color,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  child: Icon(Icons.arrow_forward_rounded, color: color),
                ),
                Expanded(
                  child: _RouteNode(
                    label: '到达',
                    name: toName.isEmpty ? '未填写' : toName,
                    sub: item.toAddress,
                    color: color,
                  ),
                ),
              ],
            ),
          if (hasRoute && hasFlight) const SizedBox(height: Spacing.md),
          if (hasFlight)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.capsule,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flight_rounded, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    '航班号  ${item.flightNo!}',
                    style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      fontWeight: FontWeight.w700,
                      fontFeatures: AppTextStyles.tabularFigures,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteNode extends StatelessWidget {
  const _RouteNode({
    required this.label,
    required this.name,
    required this.sub,
    required this.color,
  });

  final String label;
  final String name;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: AppFontSizes.caption - 1,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant)),
        const SizedBox(height: 3),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: AppFontSizes.body, fontWeight: FontWeight.w700)),
        if (sub.isNotEmpty)
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: AppFontSizes.caption - 1,
                  color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

/// 通用信息卡：日期 / 时间 / 时长 / 计划费用。
class _BasicCard extends StatelessWidget {
  const _BasicCard({required this.item, required this.visual});

  final TripItem item;
  final TripTypeVisual visual;

  String get _durationLabel {
    switch (item.type) {
      case 'food':
        return '建议用餐时长';
      case 'stay':
        return '预计停留时长';
      case 'transport':
        return '行程时长';
      default:
        return '建议游玩时长';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasTime = item.startTimeMin != null;
    final hasDuration = item.durationMin != null && item.durationMin! > 0;
    final hasCost = item.costCents != null && item.costCents != 0;
    final rows = <Widget>[];

    if (hasTime) {
      rows.add(_InfoRow(
        icon: Icons.schedule_rounded,
        label: item.type == 'transport' ? '出发时间' : '开始时间',
        value: hhmm(item.startTimeMin!),
      ));
    }
    if (hasDuration) {
      rows.add(_InfoRow(
        icon: Icons.timelapse_rounded,
        label: _durationLabel,
        value: formatDuration(item.durationMin!),
      ));
    }
    if (hasCost) {
      rows.add(_InfoRow(
        icon: Icons.payments_rounded,
        label: '计划费用',
        valueWidget: MoneyText(
          item.costCents!,
          symbol: (currencyByCode(item.costCurrency)?.symbol) ?? '¥',
          color: visual.color,
        ),
      ));
    }
    // 交通的起止已在 _TransportCard 展示，这里不再重复地址。
    if (item.address.isNotEmpty && item.type != 'transport') {
      rows.add(_InfoRow(
        icon: Icons.place_rounded,
        label: '地址',
        value: item.address,
      ));
    }

    if (rows.isEmpty) {
      return SectionCard(
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text('暂无更多安排信息',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      );
    }

    return SectionCard(
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Divider(
              height: Spacing.xl + Spacing.md,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          rows[i],
        ],
      ]),
    );
  }
}

/// 备注卡。
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.item});

  final TripItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final note = item.note;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: Spacing.sm),
              Text('备注',
                  style: TextStyle(
                      fontSize: AppFontSizes.bodyLarge,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            note.isEmpty ? '未填写备注' : note,
            style: TextStyle(
              fontSize: AppFontSizes.body,
              height: 1.55,
              color: note.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单行信息条目：图标 + 标签 + 值。
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.value, this.valueWidget});

  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadius.button,
          ),
          child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              if (value != null)
                Text(value!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: AppFontSizes.body,
                        fontWeight: FontWeight.w600,
                        height: 1.3)),
              ?valueWidget,
            ],
          ),
        ),
      ],
    );
  }
}
