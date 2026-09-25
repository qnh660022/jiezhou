// V2.9.0：中文日期月历选择抽屉 —— 全工程唯一日期选择形态。
//
// 自绘月历（中文星期/月份），规避未本地化的系统 showDatePicker /
// showDateRangePicker（trip_edit_screen 此前已就地实现，本文件把它抽成
// 共用组件，行程编辑 / 安排编辑 / 模板「用模板建行程」三处统一走这里）。
//
// * 区间模式（默认）：先点起点再点终点，终点 == 起点即单天行程；
// * 单日模式（[RangeCalendarMode.single]）：点一下即选中（起=终），
//   供「安排归属日」「模板出发日」等单日场景调用。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/date_utils.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart' show cnDateRange, dateTimeFromEpochDay, epochDayOf;

/// 选择模式
enum RangeCalendarMode {
  /// 区间选择：起点 → 终点（两次点击）
  range,

  /// 单日选择：一次点击即选中（起=终）
  single,
}

/// 月历选择结果（epochDay 闭区间；单日模式 start == end）
class RangeCalendarResult {
  const RangeCalendarResult(this.startDay, this.endDay);

  final int startDay;
  final int endDay;
}

/// 底部抽屉打开自绘月历。取消返回 null。
///
/// [initialMonth] 决定首屏月份（默认今天所在月）。
Future<RangeCalendarResult?> showRangeCalendarSheet(
  BuildContext context, {
  DateTime? initialMonth,
  int? startDay,
  int? endDay,
  RangeCalendarMode mode = RangeCalendarMode.range,
  String? title,
}) {
  return showDraggableSheet<RangeCalendarResult>(
    context: context,
    initialChildSize: 0.72,
    minChildSize: 0.5,
    builder: (sheetContext, scrollController) => RangeCalendarSheet(
      initialMonth: initialMonth,
      startDay: startDay,
      endDay: endDay,
      mode: mode,
      title: title,
      // V2.9.0：月历区域接抽屉滚动控制器（小屏/测试视口下可滚动，
      // 确认钮始终钉在底部可见）。
      scrollController: scrollController,
    ),
  );
}

/// 自绘中文月历面板（纯内容，宿主决定容器；一般走 [showRangeCalendarSheet]）。
class RangeCalendarSheet extends StatefulWidget {
  const RangeCalendarSheet({
    super.key,
    this.initialMonth,
    this.startDay,
    this.endDay,
    this.mode = RangeCalendarMode.range,
    this.title,
    this.scrollController,
  });

  final DateTime? initialMonth;
  final int? startDay;
  final int? endDay;
  final RangeCalendarMode mode;
  final String? title;

  /// 月历滚动控制器（抽屉容器提供；独立使用可不传）。
  final ScrollController? scrollController;

  @override
  State<RangeCalendarSheet> createState() => _RangeCalendarSheetState();
}

class _RangeCalendarSheetState extends State<RangeCalendarSheet> {
  late DateTime _month = () {
    final m = widget.initialMonth;
    if (m != null) return DateTime(m.year, m.month);
    return DateTime(
        DateTime.now().year, DateTime.now().month);
  }();
  int? _start;
  int? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.startDay;
    _end = widget.endDay;
  }

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  bool get _isSingle => widget.mode == RangeCalendarMode.single;

  List<int> _daysInMonth() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysCount = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7; // 周一为第一列
    return [
      for (var i = 0; i < leading; i++) -1,
      for (var d = 1; d <= daysCount; d++)
        epochDayOf(DateTime(_month.year, _month.month, d)),
    ];
  }

  void _tapDay(int day) {
    HapticFeedback.selectionClick();
    setState(() {
      // V2.9.0：单日模式一次点击即选中（起=终）。
      if (_isSingle) {
        _start = day;
        _end = day;
        return;
      }
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

  bool get _canConfirm => _start != null && _end != null;

  void _confirm() {
    Navigator.of(context).pop(
      RangeCalendarResult(_start!, _end == _start ? _start! : _end!),
    );
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
          if (widget.title != null) ...[
            Text(widget.title!,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: Spacing.sm),
          ],
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
          // V2.9.0：月历放进可滚动区（6 行月份在低视口下不再溢出），
          // 确认按钮钉在底部始终可见。
          Flexible(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 7,
                childAspectRatio: 1.15,
                children: [
                  for (final day in cells)
                    if (day < 0)
                      const SizedBox()
                    else
                      _buildDayCell(day, scheme),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          PrimaryButton(
            label: !_canConfirm
                ? (_isSingle ? '请选择日期' : '请选择日期区间')
                : _isSingle
                    ? '确定 · ${fmtFullDateOfEpoch(_start!)}'
                    : '确定 · ${cnDateRange(_start!, _end!)}',
            expanded: true,
            backgroundColor:
                _canConfirm ? null : scheme.surfaceContainerHigh,
            foregroundColor:
                _canConfirm ? null : scheme.onSurfaceVariant,
            onPressed: _canConfirm ? _confirm : null,
          ),
        ],
      ),
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
