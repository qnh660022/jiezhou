// ✏️ 新建 / 编辑行程（V2.8.3.5 方案 A · 预览驱动重排）。
//
// 布局自上而下：实时预览卡（封面渐变 + 徽章 + 名称 + 目的地 + 日期区间）
// → 名称/目的地行内无框输入 → 外观（封面横滑 + 徽章）→ 日期（快捷 chip +
// 区间 + 天数）→ 装配节奏 → 备注（折叠）→ 底部停靠的提交按钮。
// 字段、保存逻辑与 schema 与旧版完全一致，仅重排视觉与交互。
import 'package:flutter/material.dart';
import '../../../core/date_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/uid.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../features/desktop/desktop_utils.dart' show isDesktopWeb;
import 'destination_picker_sheet.dart';

import '../../../domain/assemble_engine.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';
import '../../../shared/widgets/app_snack_bar.dart';

const List<String> kTripEmojis = [
  '✈️', '🏖️', '⛰️', '🏙️', '🎒', '🚗', '🏕️', '🎡', '🛳️', '🗺️',
];

/// 新建 / 编辑行程页（路由 extra 传行程 id 即编辑模式；或直接传 [initialId]）
class TripEditScreen extends ConsumerStatefulWidget {
  const TripEditScreen({super.key, this.initialId});

  /// 编辑模式下待编辑的行程 id。为桌面工作台在 Dialog 内复用而加：
  /// 传入时优先使用，否则回落到路由 extra（移动端/整页跳转不受影响）。
  final String? initialId;

  @override
  ConsumerState<TripEditScreen> createState() => _TripEditScreenState();
}

class _TripEditScreenState extends ConsumerState<TripEditScreen> {
  final _nameCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _emoji = kTripEmojis.first;
  String _coverKey = CoverGradients.keys.first;
  int? _startDay;
  int? _endDay;
  // V2.7.2 S7：行程级装配节奏（relaxed/standard/tight）。
  String _pace = 'standard';
  // V2.8.3.5 方案 A：备注默认折叠成一行，展开才出现输入框。
  bool _noteOpen = false;

  String? _editId;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _destCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// 目的地选择弹层：全国城市多选 + 海外手动填；确定后以「-」回填。
  Future<void> _pickDestination() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDestinationPicker(context, _destCtrl.text);
    if (picked == null || !mounted) return;
    setState(() => _destCtrl.text = picked);
  }

  void _toast(String message) {
    // V2.8.3.3：收口到全 App 唯一轻提示形态（L1）。
    showAppSnackBar(context, message);
  }

  Future<void> _loadExisting(String id) async {
    final trip = await ref.read(tripsRepoProvider).watchTrip(id).first;
    if (!mounted || trip == null) return;
    setState(() {
      _nameCtrl.text = trip.name;
      _destCtrl.text = trip.destination;
      _noteCtrl.text = trip.note ?? '';
      _emoji = trip.emoji;
      _coverKey = CoverGradients.keys.contains(trip.cover) ? trip.cover : _coverKey;
      _startDay = trip.startEpochDay;
      _endDay = trip.endEpochDay;
      _pace = trip.pace;
      _loaded = true;
    });
  }

  Future<void> _pickDateRange() async {
    HapticFeedback.selectionClick();
    final initialStart = _startDay ?? todayEpochDay();

    // 桌面 Web：用原生日期区间对话框（确认/取消按钮均可见），
    // 规避底部抽屉在桌面对话框/大窗内“确认被遮挡”的问题。
    if (isDesktopWeb(context)) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: _startDay != null && _endDay != null
            ? DateTimeRange(
                start: epochDayToDate(_startDay!),
                end: epochDayToDate(_endDay!))
            : DateTimeRange(
                start: epochDayToDate(initialStart),
                end: epochDayToDate(initialStart)),
        helpText: '选择行程日期区间',
      );
      if (range != null && mounted) {
        setState(() {
          _startDay = dateToEpochDay(range.start);
          _endDay = dateToEpochDay(range.end);
        });
      }
      return;
    }

    final result = await showDraggableSheet<_DateRangeResult>(
      context: context,
      initialChildSize: 0.72,
      minChildSize: 0.5,
      builder: (sheetContext, _) => _RangeCalendarSheet(
        initialMonth: dateTimeFromEpochDay(initialStart),
        startDay: _startDay,
        endDay: _endDay,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _startDay = result.startDay;
        _endDay = result.endDay;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('请填写行程名称');
      return;
    }
    if (_startDay == null || _endDay == null || _startDay! > _endDay!) {
      _toast('请选择合法的出发与结束日期');
      return;
    }
    setState(() => _saving = true);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final id = _editId ?? newId('trip'); // ASSUMED(t2): uid.dart
    final existing =
        _editId == null ? null : await ref.read(tripsRepoProvider).watchTrip(_editId!).first;
    final trip = Trip(
      id: id,
      name: name,
      destination: _destCtrl.text.trim(),
      emoji: _emoji,
      cover: _coverKey,
      startEpochDay: _startDay!,
      endEpochDay: _endDay!,
      note: _noteCtrl.text.trim().isEmpty ? '' : _noteCtrl.text.trim(),
      groupId: existing?.groupId,
      archived: existing?.archived ?? false,
      // V2.7.2 S7：装配节奏档（行程级设置一次，装配台不再询问）。
      pace: _pace,
      createdAt: existing?.createdAt ?? nowMs,
      updatedAt: nowMs,
    );
    await ref.read(tripsRepoProvider).upsertTrip(trip); // ASSUMED(t2): 存在即更新
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      // 桌面工作台在 Dialog 内复用时由 widget.initialId 提供编辑目标；
      // 移动端/整页跳转依旧从路由 extra 读取。
      if (widget.initialId != null) {
        _editId = widget.initialId;
        _loadExisting(_editId!);
      } else {
        try {
          final arg = GoRouterState.of(context).extra;
          if (arg is String && _editId == null) {
            _editId = arg;
            _loadExisting(arg);
          }
        } catch (_) {
          // 桌面工作台以 Dialog 打开（非 go_router 子树）时无 GoRouterState → 按新建处理。
          _editId = null;
        }
      }
      if (_editId == null) _loaded = true;
    }
    return Scaffold(
      appBar: GlassAppBar(
        title: _editId == null ? '新建行程' : '编辑行程',
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              minimumSize: const Size(48, 36),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            ),
            child: const Text('取消'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.xl, Spacing.md, Spacing.xl, Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // V2.8.3.5 方案 A：顶部实时预览（所见即所得）
                  _buildHeroPreview(context),
                  const SizedBox(height: Spacing.md),
                  _buildInlineFields(context),
                  const SizedBox(height: Spacing.md),
                  _buildAppearanceCard(),
                  const SizedBox(height: Spacing.md),
                  _buildDateCard(),
                  const SizedBox(height: Spacing.md),
                  _buildPaceCard(),
                  const SizedBox(height: Spacing.md),
                  _buildNoteCard(),
                ],
              ),
            ),
          ),
          // V2.8.3.5：提交动作从滚动末尾移到停靠区，滚多远都在
          _buildDockSave(context),
        ],
      ),
    );
  }

  /// 停靠的提交区：避让底部悬浮胶囊栏（桌面 Dialog 复用时不避让）。
  Widget _buildDockSave(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPad = isDesktopWeb(context)
        ? Spacing.md
        : Spacing.sm +
            AppBottomLayout.withSafeArea(context, AppBottomLayout.navBarHeight);
    return Container(
      padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, bottomPad),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: PrimaryButton(
        label: _editId == null ? '创建行程' : '保存修改',
        loading: _saving,
        expanded: true,
        onPressed: _save,
      ),
    );
  }

  // ============ 区块：实时预览 / 行内输入 / 外观 ============

  /// 顶部实时预览卡：封面渐变 + 徽章 + 名称 + 目的地 + 日期区间。
  ///
  /// 名称与目的地走 [ValueListenableBuilder]，输入即刷新，不必 setState；
  /// 封面与日期随 setState 重建。整卡即行程列表里那张卡的缩影。
  Widget _buildHeroPreview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: CoverGradients.gradientFor(_coverKey),
        borderRadius: AppRadius.card,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: Spacing.lg,
            top: Spacing.md,
            child: Text(_emoji, style: const TextStyle(fontSize: 30)),
          ),
          Positioned(
            left: Spacing.lg,
            right: Spacing.lg,
            bottom: Spacing.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _nameCtrl,
                  builder: (context, v, _) {
                    final t = v.text.trim();
                    return Text(
                      t.isEmpty ? '未命名行程' : t,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: CoverGradients.onCover
                            .withValues(alpha: t.isEmpty ? 0.72 : 1.0),
                        shadows: const [
                          Shadow(
                              color: Color(0x40000000),
                              blurRadius: 10,
                              offset: Offset(0, 2)),
                        ],
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _destCtrl,
                  builder: (context, v, _) {
                    final t = v.text.trim();
                    if (t.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        t,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: CoverGradients.onCover.withValues(alpha: 0.92),
                        ),
                      ),
                    );
                  },
                ),
                if (_startDay != null && _endDay != null) ...[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: AppRadius.capsule,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '🗓 ${cnDateRange(_startDay!, _endDay!)} · 共 ${tripTotalDays(_startDay!, _endDay!)} 天',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: CoverGradients.onCover,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 名称 / 目的地：无框行内输入（去掉 TextField 描边，保留 34px 图标底片）。
  Widget _buildInlineFields(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget row({
      required IconData icon,
      required String label,
      required TextEditingController controller,
      required String hint,
      required int maxLength,
      bool big = false,
      Widget? trailing,
    }) {
      final textSize = big ? 17.0 : AppFontSizes.body;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  TextField(
                    controller: controller,
                    maxLength: maxLength,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontSize: textSize,
                      fontWeight: big ? FontWeight.w700 : FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintStyle: TextStyle(
                        fontSize: textSize,
                        fontWeight: FontWeight.w500,
                        color:
                            scheme.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );
    }

    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 4),
      child: Column(
        children: [
          row(
            icon: Icons.sell_rounded,
            label: '行程名称',
            controller: _nameCtrl,
            hint: '例如：东京五日游',
            maxLength: 20,
            big: true,
          ),
          Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.8)),
          row(
            icon: Icons.place_rounded,
            label: '目的地',
            controller: _destCtrl,
            hint: '例如：成都-稻城',
            maxLength: 60,
            trailing: TextButton(
              onPressed: _pickDestination,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: scheme.primary,
              ),
              child: const Text('选城市',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  /// 外观卡：封面由 3×2 方格改横滑 snap，徽章独立一行；两张卡并成一张。
  Widget _buildAppearanceCard() {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontSize: AppFontSizes.caption,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.2,
    );
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('封面', style: labelStyle),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text('左右滑动',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption - 1,
                      color: scheme.onSurfaceVariant)),
            ),
          ]),
          const SizedBox(height: Spacing.md),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: CoverGradients.keys.length,
              separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
              itemBuilder: (context, i) {
                final key = CoverGradients.keys[i];
                final selected = key == _coverKey;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _coverKey = key);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 62,
                    decoration: BoxDecoration(
                      gradient: CoverGradients.gradientFor(key),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selected ? scheme.onSurface : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Text('徽章', style: labelStyle),
          const SizedBox(height: Spacing.md),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kTripEmojis.length,
              separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
              itemBuilder: (context, i) {
                final e = kTripEmojis[i];
                final selected = e == _emoji;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _emoji = e);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    transformAlignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            selected ? scheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    transform: Matrix4.diagonal3Values(
                        selected ? 1.08 : 1.0, selected ? 1.08 : 1.0, 1),
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============ 区块：日期区间 / 备注 ============

  /// 快捷预设是否有命中（用于 chip 高亮）：要求起点 = 今天。
  bool _isQuickRange(int days) {
    if (_startDay == null || _endDay == null) return false;
    final today = todayEpochDay();
    return _startDay == today && _endDay == today + days - 1;
  }

  /// 快捷区间：起点今天，长度 days 天。
  void _applyQuickRange(int days) {
    HapticFeedback.selectionClick();
    final start = todayEpochDay();
    setState(() {
      _startDay = start;
      _endDay = start + days - 1;
    });
  }

  /// 「本周末」：下一个周六 → 周日（今天即周六则从今天起）。
  void _applyThisWeekend() {
    HapticFeedback.selectionClick();
    final untilSat =
        (DateTime.saturday - DateTime.now().weekday + 7) % 7;
    final sat = todayEpochDay() + untilSat;
    setState(() {
      _startDay = sat;
      _endDay = sat + 1;
    });
  }

  bool _isThisWeekend() {
    if (_startDay == null || _endDay == null) return false;
    final untilSat =
        (DateTime.saturday - DateTime.now().weekday + 7) % 7;
    final sat = todayEpochDay() + untilSat;
    return _startDay == sat && _endDay == sat + 1;
  }

  Widget _buildDateCard() {
    final scheme = Theme.of(context).colorScheme;
    Widget tile(String label, int? day, VoidCallback onTap) {
      final has = day != null;
      return Expanded(
        child: InkWell(
          borderRadius: AppRadius.input,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadius.input,
              border:
                  Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  has ? cnFullDate(day) : '选择日期',
                  style: TextStyle(
                    fontSize: AppFontSizes.bodyLarge,
                    fontWeight: FontWeight.w700,
                    color: has ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontFeatures: AppTextStyles.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget quick(String label, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerLow,
            borderRadius: AppRadius.capsule,
            border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.35)
                    : Colors.transparent),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('日期',
              style: TextStyle(
                  fontSize: AppFontSizes.caption,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.2)),
          const SizedBox(height: Spacing.md),
          // V2.8.3.5：四个快捷预设，一键补齐区间（仍可点开自绘日历微调）
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              quick('本周末', _isThisWeekend(), _applyThisWeekend),
              quick('3 天', _isQuickRange(3), () => _applyQuickRange(3)),
              quick('5 天', _isQuickRange(5), () => _applyQuickRange(5)),
              quick('一周', _isQuickRange(7), () => _applyQuickRange(7)),
            ],
          ),
          const SizedBox(height: Spacing.md),
          LabeledField(
            label: '行程日期',
            child: Row(
              children: [
                tile('出发', _startDay, _pickDateRange),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
                tile('结束', _endDay, _pickDateRange),
              ],
            ),
          ),
          if (_startDay != null && _endDay != null) ...[
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: AppRadius.capsule,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🗓️', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    '全程 ${tripTotalDays(_startDay!, _endDay!)} 天 · ${cnDateRange(_startDay!, _endDay!)}',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============ 区块：装配节奏（V2.7.2 S7） ============

  Widget _buildPaceCard() {
    final scheme = Theme.of(context).colorScheme;
    Widget tile(TripPace pace, String desc) {
      final selected = _pace == pace.name;
      return Expanded(
        child: InkWell(
          borderRadius: AppRadius.input,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _pace = pace.name);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: Spacing.md, horizontal: Spacing.xs),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerLow,
              borderRadius: AppRadius.input,
              border: Border.all(
                  color: selected
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(tripPaceLabel(pace),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface)),
                const SizedBox(height: 2),
                Text(desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppFontSizes.caption - 1,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('装配节奏', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text('想去装配台按此档估算每天可排时长',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      color: scheme.onSurfaceVariant)),
            ),
          ]),
          const SizedBox(height: Spacing.md),
          Row(children: [
            tile(TripPace.relaxed, '每天约 6 小时'),
            const SizedBox(width: Spacing.sm),
            tile(TripPace.standard, '每天约 8 小时'),
            const SizedBox(width: Spacing.sm),
            tile(TripPace.tight, '每天约 10 小时'),
          ]),
        ],
      ),
    );
  }

  /// 备注：默认折叠成一行，展开才出现输入框（方案 A 的第 6 条）。
  Widget _buildNoteCard() {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg,
          _noteOpen ? Spacing.lg : Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: AppRadius.input,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _noteOpen = !_noteOpen);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Row(
                children: [
                  const Text('备注', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('选填',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: scheme.onSurfaceVariant)),
                  const SizedBox(width: Spacing.sm),
                  AnimatedRotation(
                    turns: _noteOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 18, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _noteOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: Spacing.sm),
                    child: TextField(
                      controller: _noteCtrl,
                      maxLines: 4,
                      minLines: 2,
                      decoration:
                          const InputDecoration(hintText: '签证、预订、注意事项…'),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}


// ============ 中文日期区间选择抽屉（自绘月历，规避未本地化的系统控件） ============

class _DateRangeResult {
  const _DateRangeResult(this.startDay, this.endDay);

  final int startDay;
  final int endDay;
}

class _RangeCalendarSheet extends StatefulWidget {
  const _RangeCalendarSheet({
    required this.initialMonth,
    this.startDay,
    this.endDay,
  });

  final DateTime initialMonth;
  final int? startDay;
  final int? endDay;

  @override
  State<_RangeCalendarSheet> createState() => _RangeCalendarSheetState();
}

class _RangeCalendarSheetState extends State<_RangeCalendarSheet> {
  late DateTime _month =
      DateTime(widget.initialMonth.year, widget.initialMonth.month);
  int? _start;
  int? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.startDay;
    _end = widget.endDay;
  }

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  List<int> _daysInMonth() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysCount = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7; // 周一为第一列
    return [
      for (var i = 0; i < leading; i++) -1,
      for (var d = 1; d <= daysCount; d++) epochDayOf(DateTime(_month.year, _month.month, d)),
    ];
  }

  void _tapDay(int day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = day;
        _end = null;
      } else if (day < _start!) {
        _start = day;
      } else if (day == _start) {
        _end = day;
      } else {
        _end = day;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cells = _daysInMonth();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xs, Spacing.xl, Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_month.year} 年 ${_month.month} 月',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month - 1);
                }),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month + 1);
                }),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              for (final w in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(w,
                        style: TextStyle(
                            fontSize: AppFontSizes.caption,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: [
              for (final day in cells)
                if (day < 0)
                  const SizedBox()
                else
                  _buildDayCell(day, scheme),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          PrimaryButton(
            label: _start != null && _end != null
                ? '确定 · ${cnDateRange(_start!, _end!)}'
                : '请选择日期区间',
            expanded: true,
            backgroundColor:
                _start != null && _end != null ? null : scheme.surfaceContainerHigh,
            foregroundColor:
                _start != null && _end != null ? null : scheme.onSurfaceVariant,
            onPressed:
                _start != null && _end != null ? _confirm : null,
          ),
        ],
      ),
    );
  }

  void _confirm() {
    Navigator.of(context).pop(
      _DateRangeResult(_start!, _end == _start ? _start! : _end!),
    );
  }

  Widget _buildDayCell(int day, ColorScheme scheme) {
    final isStart = day == _start;
    final isEnd = day == _end && _end != _start || (day == _end && day == _start);
    final inRange = _start != null &&
        _end != null &&
        day > _start! &&
        day < _end!;
    final selected = isStart || isEnd;
    return GestureDetector(
      onTap: () => _tapDay(day),
      child: Container(
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : inRange
                  ? scheme.primaryContainer.withValues(alpha: 0.6)
                  : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(
          '${dateTimeFromEpochDay(day).day}',
          style: TextStyle(
            fontSize: AppFontSizes.body,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected
                ? scheme.onPrimary
                : scheme.onSurface,
            fontFeatures: AppTextStyles.tabularFigures,
          ),
        ),
      ),
    );
  }
}

