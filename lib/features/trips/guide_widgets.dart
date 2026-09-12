/// 攻略页专用组件（2026-09 UI 重设计）。
///
/// ## 为什么抽出来
/// 旧页面把六栏用同一个 `Card + ListTile(dense)` 平铺，导致「城市头 → 栏目 →
/// 条目」三层信息在视觉上完全同权（用户原话：「很没有层次感」）。
/// 现在按「一屏一屏」的三级层次组织：
///
/// 1. **城市头**（`GuideCityHero`）——城市名 34px + 一句话定位 + 三枚统计
///    （景点数 / 预计阅读 / 数据来源）；
/// 2. **栏目速览**（`GuideSectionGrid`）——2×3 宫格，图标底砖 + 栏名 + 条数 +
///    内容预览，点一下跳到对应栏目；
/// 3. **栏目内容**（`GuideSectionBody`）——每栏按数据类型换渲染形态：
///    景点/美食卡片、交通两行式、预算键值表、准备/避坑段落式。
///
/// 所有间距/圆角/字号/颜色一律走 `theme/tokens.dart`，不硬编码。
library;
import 'package:flutter/material.dart';

import '../../data/guide/guide_models.dart';
import '../../shared/widgets/section_header.dart';
import '../../theme/tokens.dart';
import 'trip_widgets.dart' show SectionCard;

// ---------------------------------------------------------------------------
// 路由参数
// ---------------------------------------------------------------------------

/// 攻略页路由参数（`/guide` 与 `/trips/guide` 共用）。
///
/// 两种入口形态：
/// - `tripId` 有值 → 行程入口，由行程目的地归一化出城市，条目可「加入安排」；
/// - `cityKey` 有值 → 城市入口（选择器/行程列表卡片），无行程上下文，
///   「加入安排」时先弹行程选择。
class GuideRouteArgs {
  const GuideRouteArgs({this.tripId, this.cityKey});
  final String? tripId;
  final String? cityKey;
}

// ---------------------------------------------------------------------------
// 栏目视觉表（图标 / 语气 / 副标题）——六栏唯一出处，避免多处 switch 漂移
// ---------------------------------------------------------------------------

class GuideSectionStyle {
  const GuideSectionStyle({
    required this.icon,
    required this.hint,
    required this.tone,
  });

  final IconData icon;

  /// 宫格里的内容预览（这一栏到底给用户什么）。
  final String hint;

  /// 强调色（同色系里区分栏目，不引入新色板）。
  final Color tone;
}

/// 六栏样式（tone 用语义色 + primary 派生，绝不硬编码随机色值）。
GuideSectionStyle guideSectionStyle(BuildContext context, String key) {
  final scheme = Theme.of(context).colorScheme;
  return switch (key) {
    'prep' => GuideSectionStyle(
        icon: Icons.event_available_rounded,
        hint: '预约 · 季节 · 天数',
        tone: scheme.primary),
    'spots' => GuideSectionStyle(
        icon: Icons.photo_camera_rounded,
        hint: '必去 · 经典 · 小众',
        tone: scheme.tertiary),
    'food' => GuideSectionStyle(
        icon: Icons.restaurant_rounded,
        hint: '招牌菜 · 老店 · 街区',
        tone: SemanticColors.warning),
    'transport' => GuideSectionStyle(
        icon: Icons.directions_transit_rounded,
        hint: '机场 · 地铁 · 打车',
        tone: scheme.secondary),
    'tips' => GuideSectionStyle(
        icon: Icons.report_problem_rounded,
        hint: '排队 · 黄牛 · 闭馆',
        tone: SemanticColors.expense),
    _ => GuideSectionStyle(
        icon: Icons.payments_rounded,
        hint: '住宿 · 餐饮 · 门票',
        tone: SemanticColors.income),
  };
}

/// 该栏的条目名（六栏主键不统一：prep/tips=title、spots/food=name、
/// transport=mode、budget=item）。
String guideItemTitle(String sectionKey, Map<String, dynamic> item) {
  final v = switch (sectionKey) {
    'spots' || 'food' => item['name'] ?? item['title'],
    'transport' => item['mode'] ?? item['line'],
    'budget' => item['item'],
    _ => item['title'] ?? item['name'],
  };
  return (v ?? '').toString();
}

/// 该栏的正文（detail 优先，回落到 note）。
String guideItemDetail(String sectionKey, Map<String, dynamic> item) =>
    (switch (sectionKey) {
      'spots' || 'food' => item['note'] ?? item['detail'],
      'budget' => item['rangeText'] ?? item['detail'],
      _ => item['detail'] ?? item['note'],
    } ??
        '')
        .toString();

// ---------------------------------------------------------------------------
// 1. 城市头
// ---------------------------------------------------------------------------

/// 城市头：名称 + 定位 + 统计徽章。
class GuideCityHero extends StatelessWidget {
  const GuideCityHero({
    super.key,
    required this.cityName,
    required this.spots,
    required this.textChars,
    required this.readingMinutes,
    required this.sourceLabel,
    this.lead,
    this.onPickCity,
  });

  final String cityName;
  final int spots;
  final int textChars;
  final int readingMinutes;
  final String sourceLabel;

  /// 城市一句话定位（取「城市概述」或首条内容）。
  final String? lead;
  final VoidCallback? onPickCity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, 0),
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.85),
            scheme.surfaceContainerLowest,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  cityName,
                  style: AppTextStyles.headline(scheme).copyWith(fontSize: 30),
                ),
              ),
              // 换城市：任何入口进来都能切换城市，不必退回上一页
              if (onPickCity != null)
                _PillButton(
                  icon: Icons.swap_horiz_rounded,
                  label: '换城市',
                  onTap: onPickCity!,
                ),
            ],
          ),
          if (lead != null && lead!.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              lead!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppFontSizes.body,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: Spacing.lg),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              GuideStatChip(
                  icon: Icons.place_rounded, text: '$spots 个景点/美食'),
              GuideStatChip(
                  icon: Icons.schedule_rounded, text: '约 $readingMinutes 分钟读完'),
              GuideStatChip(
                  icon: Icons.verified_rounded, text: sourceLabel),
            ],
          ),
        ],
      ),
    );
  }
}

/// 统计胶囊（城市头 / 栏目头共用）。
class GuideStatChip extends StatelessWidget {
  const GuideStatChip({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.xs + 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.9),
        borderRadius: AppRadius.capsule,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: scheme.primary),
        const SizedBox(width: Spacing.xs + 2),
        Text(text,
            style: TextStyle(
                fontSize: AppFontSizes.caption, color: scheme.onSurface)),
      ]),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest.withValues(alpha: 0.9),
      borderRadius: AppRadius.capsule,
      child: InkWell(
        borderRadius: AppRadius.capsule,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: Spacing.xs),
            Text(label,
                style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary)),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. 栏目速览宫格
// ---------------------------------------------------------------------------

/// 六栏速览：2 列 × 3 行，点一下滚到对应栏目。空栏置灰但仍可点（会提示暂无）。
class GuideSectionGrid extends StatelessWidget {
  const GuideSectionGrid({
    super.key,
    required this.sections,
    required this.onTap,
  });

  final Map<String, List<Map<String, dynamic>>> sections;
  final void Function(String sectionKey) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '这份攻略包含',
          subtitle: '点一格跳到对应内容',
          trailingLabel: null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          child: LayoutBuilder(builder: (context, c) {
            const gap = Spacing.md;
            final w = (c.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final key in GuideCity.sectionKeys)
                  SizedBox(
                    width: w,
                    child: _SectionTile(
                      sectionKey: key,
                      items: sections[key] ?? const [],
                      onTap: () => onTap(key),
                    ),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.sectionKey,
    required this.items,
    required this.onTap,
  });

  final String sectionKey;
  final List<Map<String, dynamic>> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = guideSectionStyle(context, sectionKey);
    final label = GuideCity.sectionLabels[sectionKey] ?? sectionKey;
    final empty = items.isEmpty;
    final preview = empty
        ? '暂无内容'
        : items
            .take(2)
            .map((e) => guideItemTitle(sectionKey, e))
            .where((s) => s.isNotEmpty)
            .join(' · ');
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: AppRadius.card,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // 图标底砖：让六栏在一眼里可区分
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: style.tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Spacing.md),
                  ),
                  child: Icon(style.icon, size: 19, color: style.tone),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: AppFontSizes.body,
                      fontWeight: FontWeight.w700,
                      color: empty ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      fontWeight: FontWeight.w600,
                      color: empty ? scheme.outline : style.tone),
                ),
              ]),
              const SizedBox(height: Spacing.sm),
              Text(
                preview.isEmpty ? style.hint : preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    height: 1.35,
                    color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. 栏目内容
// ---------------------------------------------------------------------------

/// 栏目卡片：标题行（图标砖 + 栏名 + 条数 + 折叠箭头）+ 条目列表。
class GuideSectionBody extends StatefulWidget {
  const GuideSectionBody({
    super.key,
    required this.sectionKey,
    required this.items,
    this.expanded = true,
    this.onToggle,
    this.itemActionBuilder,
    this.tagFilterEnabled = true,
  });

  final String sectionKey;
  final List<Map<String, dynamic>> items;

  /// 折叠态由页面统一管理（跨会话记忆），这里只负责展示。
  final bool expanded;
  final VoidCallback? onToggle;

  /// 条目右侧动作（「加入安排」）；返回 null 表示不显示。
  final Widget? Function(Map<String, dynamic> item)? itemActionBuilder;

  /// 是否给 spots/food 提供标签筛选（必去/经典/小众…）。
  final bool tagFilterEnabled;

  @override
  State<GuideSectionBody> createState() => _GuideSectionBodyState();
}

class _GuideSectionBodyState extends State<GuideSectionBody> {
  String? _tag;

  List<String> get _tags {
    if (!widget.tagFilterEnabled) return const [];
    if (widget.sectionKey != 'spots' && widget.sectionKey != 'food') {
      return const [];
    }
    final out = <String>[];
    for (final it in widget.items) {
      final t = (it['tag'] ?? '').toString();
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }
    return out.length > 1 ? out : const [];
  }

  List<Map<String, dynamic>> get _visible {
    if (_tag == null) return widget.items;
    return widget.items
        .where((e) => (e['tag'] ?? '').toString() == _tag)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = guideSectionStyle(context, widget.sectionKey);
    final label = GuideCity.sectionLabels[widget.sectionKey] ?? '';
    final tags = _tags;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- 栏目标题行 ----
          InkWell(
            borderRadius: AppRadius.input,
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: style.tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Spacing.sm + 2),
                  ),
                  child: Icon(style.icon, size: 18, color: style.tone),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: AppFontSizes.bodyLarge,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface)),
                      Text(style.hint,
                          style: TextStyle(
                              fontSize: AppFontSizes.caption - 1,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text('${widget.items.length} 条',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(width: Spacing.xs),
                Icon(
                    widget.expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
          if (widget.expanded) ...[
            // ---- 标签筛选（仅 spots/food 且标签多于一种时出现） ----
            if (tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Wrap(
                  spacing: Spacing.sm,
                  children: [
                    _TagChip(
                      label: '全部',
                      selected: _tag == null,
                      onTap: () => setState(() => _tag = null),
                    ),
                    for (final t in tags)
                      _TagChip(
                        label: t,
                        selected: _tag == t,
                        onTap: () => setState(() => _tag = t),
                      ),
                  ],
                ),
              ),
            const Divider(height: 1),
            if (widget.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                child: Text('这一栏还在补充中，可以先看别的栏目',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: scheme.onSurfaceVariant)),
              )
            else
              for (final item in _visible)
                GuideItemRow(
                  sectionKey: widget.sectionKey,
                  item: item,
                  action: widget.itemActionBuilder?.call(item),
                ),
          ],
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: AppRadius.capsule,
      child: InkWell(
        borderRadius: AppRadius.capsule,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.xs + 1),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.caption,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// 单条攻略内容。按栏目换渲染形态：
/// - `spots`：名称 + 区域/标签/时长 + 正文 + 右侧「加入安排」；
/// - `food`：名称 + 区域 + 正文 + 「加入安排」；
/// - `transport`：方式/线路两行 + 说明；
/// - `budget`：项目 ↔ 区间 键值行；
/// - `prep`/`tips`：小标题 + 段落正文（不截断）。
class GuideItemRow extends StatelessWidget {
  const GuideItemRow({
    super.key,
    required this.sectionKey,
    required this.item,
    this.action,
  });

  final String sectionKey;
  final Map<String, dynamic> item;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = guideItemTitle(sectionKey, item);
    final detail = guideItemDetail(sectionKey, item);
    final isFromNetwork = item['source'] != null;

    if (sectionKey == 'budget') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76,
              child: Text(title,
                  style: TextStyle(
                      fontSize: AppFontSizes.body,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface)),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(detail,
                  style: TextStyle(
                      fontSize: AppFontSizes.body,
                      height: 1.4,
                      color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppFontSizes.bodyLarge,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: Spacing.sm),
                action!,
              ],
            ],
          ),
          if (_meta().isNotEmpty) ...[
            const SizedBox(height: Spacing.xs + 2),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: [
                for (final m in _meta())
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: AppRadius.capsule,
                    ),
                    child: Text(m,
                        style: TextStyle(
                            fontSize: AppFontSizes.caption - 1,
                            color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
          ],
          if (detail.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            // 长文完整展示（精品 50 城单条可达 350 字，截断会丢掉关键信息）
            Text(
              detail,
              style: TextStyle(
                fontSize: AppFontSizes.body,
                height: 1.5,
                color: scheme.onSurface,
              ),
            ),
          ],
          if (isFromNetwork)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text('来自 ${item['source']}',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption - 1,
                      color: scheme.outline)),
            ),
        ],
      ),
    );
  }

  /// 副信息：景点/美食给 区域 · 标签 · 时长；交通给 线路。
  List<String> _meta() {
    switch (sectionKey) {
      case 'spots':
        return [
          if ((item['addr'] ?? '').toString().isNotEmpty)
            item['addr'].toString(),
          if ((item['tag'] ?? '').toString().isNotEmpty) item['tag'].toString(),
          if ((item['timeText'] ?? '').toString().isNotEmpty)
            '建议 ${item['timeText']}',
        ];
      case 'food':
        return [
          if ((item['area'] ?? '').toString().isNotEmpty) item['area'].toString(),
        ];
      case 'transport':
        return [
          if ((item['line'] ?? '').toString().isNotEmpty) item['line'].toString(),
        ];
      default:
        return const [];
    }
  }
}

// ---------------------------------------------------------------------------
// 在线游记流
// ---------------------------------------------------------------------------

/// 「在线攻略」区块：真·游记（来自去哪儿城市页的「热门攻略」清单）。
class GuideArticleList extends StatelessWidget {
  const GuideArticleList({
    super.key,
    required this.articles,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> articles;
  final void Function(Map<String, dynamic> article) onOpen;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '在线攻略（游记）',
          subtitle: '${articles.length} 篇 · 点开看原文',
          trailingLabel: null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          child: Column(
            children: [
              for (final a in articles)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: Material(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: AppRadius.card,
                    child: InkWell(
                      borderRadius: AppRadius.card,
                      onTap: () => onOpen(a),
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.lg),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (a['title'] ?? '').toString(),
                                  style: TextStyle(
                                      fontSize: AppFontSizes.body,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                      color: scheme.onSurface),
                                ),
                                const SizedBox(height: Spacing.xs),
                                Text(
                                  [
                                    (a['source'] ?? '去哪儿攻略').toString(),
                                    if ((a['publishedText'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      a['publishedText'].toString(),
                                  ].join(' · '),
                                  style: TextStyle(
                                      fontSize: AppFontSizes.caption - 1,
                                      color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.open_in_new_rounded,
                              size: 16, color: scheme.primary),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
