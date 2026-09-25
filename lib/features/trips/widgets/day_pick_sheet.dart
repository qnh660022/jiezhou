// V2.9.0：选天弹层统一组件 —— 1 基 D 序号 + 月日 + 星期 + 当天安排数 + 当前天高亮。
//
// 收敛此前三套口径不一的自绘选天列表：
// * trip_detail_screen `_DayPickSheet`：0 基 D0 + isCurrent 恒 false 死分支；
// * wishlist_panel `_PoolPlaceSheet`：只有「第 N 天」无日期；
// * trip_guide_screen `_DayCard`：信息最全（月日 + 星期 + 安排数）。
// 以信息最全的一套为基准，三处调用点全部换装。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/date_utils.dart' show weekdayCnOf;
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart' show cnMonthDay;

/// 底部抽屉打开「选天」列表。返回所选天的 epochDay；取消返回 null。
///
/// * [startDay]/[endDay]：行程起止（epochDay 闭区间）；
/// * [selectedDay]：当前天（高亮 + 勾标；null = 无高亮）；
/// * [itemCountOf]：可选，返回某天的安排/候选数（null = 不渲染计数）；
/// * [title]：弹层标题。
Future<int?> showDayPickSheet(
  BuildContext context, {
  required int startDay,
  required int endDay,
  int? selectedDay,
  int Function(int epochDay)? itemCountOf,
  String title = '选择哪一天？',
}) {
  return showDraggableSheet<int>(
    context: context,
    initialChildSize: 0.5,
    minChildSize: 0.36,
    builder: (sheetContext, scrollController) => DayPickList(
      startDay: startDay,
      endDay: endDay,
      selectedDay: selectedDay,
      itemCountOf: itemCountOf,
      title: title,
      scrollController: scrollController,
      onPicked: Navigator.of(sheetContext).pop,
    ),
  );
}

/// 选天列表（纯内容，供抽屉 / 桌面对话框复用）。
class DayPickList extends StatelessWidget {
  const DayPickList({
    super.key,
    required this.startDay,
    required this.endDay,
    required this.onPicked,
    this.selectedDay,
    this.itemCountOf,
    this.title = '选择哪一天？',
    this.scrollController,
  });

  final int startDay;
  final int endDay;
  final ValueChanged<int> onPicked;

  /// 当前天（epochDay）：高亮 + 勾标；null = 无高亮。
  final int? selectedDay;

  /// 某天的安排/候选数；null = 不渲染。
  final int Function(int epochDay)? itemCountOf;

  final String title;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = endDay - startDay + 1;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: Spacing.md),
          Flexible(
            child: ListView.builder(
              controller: scrollController,
              itemCount: days,
              itemBuilder: (context, i) {
                final day = startDay + i;
                final isCurrent = day == selectedDay;
                final count = itemCountOf?.call(day);
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // V2.9.0：当前天用主色实底强调，其余天浅底。
                      color: isCurrent
                          ? scheme.primary
                          : scheme.primaryContainer.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      // V2.9.0：统一 1 基 D 序号（此前详情页是 0 基 D0）。
                      'D${i + 1}',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption - 1,
                          fontWeight: FontWeight.w800,
                          color: isCurrent
                              ? scheme.onPrimary
                              : scheme.onPrimaryContainer),
                    ),
                  ),
                  // 月日 + 星期（V2.9.0：星期信息此前只有攻略页有）。
                  title: Text('${cnMonthDay(day)} ${weekdayCnOf(day)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (count != null)
                        Text('$count 项',
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                color: scheme.onSurfaceVariant)),
                      if (isCurrent) ...[
                        const SizedBox(width: Spacing.sm),
                        Icon(Icons.check_rounded,
                            size: 18, color: scheme.primary),
                      ],
                    ],
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPicked(day);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
