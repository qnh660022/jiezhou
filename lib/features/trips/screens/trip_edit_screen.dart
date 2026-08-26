// ✏️ 新建 / 编辑行程：名称目的地 + 10 emoji + 6 渐变封面 + 中文日期区间选择
// 数据访问集中区 —— 按 t2 命名假设编写：
import 'package:flutter/material.dart';
import '../../../core/date_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/uid.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart' show MoneyFormat;
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';

const List<String> kTripEmojis = [
  '✈️', '🏖️', '⛰️', '🏙️', '🎒', '🚗', '🏕️', '🎡', '🛳️', '🗺️',
];

/// 新建 / 编辑行程页（路由 extra 传行程 id 即编辑模式）
class TripEditScreen extends ConsumerStatefulWidget {
  const TripEditScreen({super.key});

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

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
      _loaded = true;
    });
  }

  Future<void> _pickDateRange() async {
    HapticFeedback.selectionClick();
    final initialStart =
        _startDay ?? todayEpochDay();
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
      final arg = GoRouterState.of(context).extra;
      if (arg is String && _editId == null) {
        _editId = arg;
        _loadExisting(arg);
      }
      if (_editId == null) _loaded = true;
    }
    return Scaffold(
      appBar: GlassAppBar(title: _editId == null ? '新建行程' : '编辑行程'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBasicsCard(),
            const SizedBox(height: Spacing.lg),
            _buildEmojiCard(),
            const SizedBox(height: Spacing.lg),
            _buildCoverCard(),
            const SizedBox(height: Spacing.lg),
            _buildDateCard(),
            const SizedBox(height: Spacing.lg),
            _buildNoteCard(),
            const SizedBox(height: Spacing.xxl),
            PrimaryButton(
              label: _editId == null ? '创建行程' : '保存修改',
              loading: _saving,
              expanded: true,
              onPressed: _save,
            ),
            const SizedBox(height: Spacing.huge),
          ],
        ),
      ),
    );
  }

  // ============ 区块：基础信息 / emoji / 封面 ============

  Widget _buildBasicsCard() {
    return SectionCard(
      child: Column(
        children: [
          LabeledField(
            label: '行程名称',
            child: TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              maxLength: 20,
              decoration:
                  const InputDecoration(hintText: '例如：东京五日游', counterText: ''),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          LabeledField(
            label: '目的地',
            child: TextField(
              controller: _destCtrl,
              textInputAction: TextInputAction.done,
              maxLength: 30,
              decoration:
                  const InputDecoration(hintText: '例如：日本 · 东京', counterText: ''),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiCard() {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: LabeledField(
        label: '行程徽章',
        child: SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kTripEmojis.length,
            separatorBuilder: (_, __) => const SizedBox(width: Spacing.md),
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
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  transformAlignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerLow,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? scheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  transform: Matrix4.diagonal3Values(
                      selected ? 1.12 : 1.0, selected ? 1.12 : 1.0, 1),
                  child: Text(e, style: const TextStyle(fontSize: 26)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCoverCard() {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('封面渐变',
              style: TextStyle(
                  fontSize: AppFontSizes.caption,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.2)),
          const SizedBox(height: Spacing.md),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Spacing.md,
            crossAxisSpacing: Spacing.md,
            childAspectRatio: 1.6,
            children: [
              for (final key in CoverGradients.keys)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _coverKey = key);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      gradient: CoverGradients.gradientFor(key),
                      borderRadius: AppRadius.input,
                      border: Border.all(
                        color: _coverKey == key
                            ? scheme.onSurface
                            : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _coverKey == key
                            ? Icons.check_rounded
                            : Icons.auto_awesome_rounded,
                        size: 20,
                        color: CoverGradients.onCover.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }


  // ============ 区块：日期区间 / 备注 ============

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
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
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

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              padding:
                  const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
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

  Widget _buildNoteCard() {
    return SectionCard(
      child: LabeledField(
        label: '备注（选填）',
        child: TextField(
          controller: _noteCtrl,
          maxLines: 4,
          minLines: 2,
          decoration: const InputDecoration(hintText: '签证、预订、注意事项…'),
        ),
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

