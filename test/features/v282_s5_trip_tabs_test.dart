// V2.8.2 S5 行程详情页签层回归（V2.9.0 裁剪）：
// TripDetailTabs 四页签组件已随 V2.8.3.2 双视图改造退役（V2.9.0 删除死代码），
// 仅保留「宿主不再挂页签层」的文件断言，防止页签层回潮。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('S5 组件下沉（文件断言）', () {
    test('V2.8.3.2：四页签 → 双视图+底部双段，大纲/装配改抽屉宿主', () {
      final screenSrc =
          File('lib/features/trips/screens/trip_detail_screen.dart').readAsStringSync();
      // 宿主不再挂 TripDetailTabs 页签层（组件本体已删除）
      expect(screenSrc.contains('TripDetailTabs('), isFalse);
      expect(screenSrc.contains('TabBarView('), isFalse);
      // 双视图：时间线（IndexedStack）+ 攻略（KitTab 并入）+ 停靠双段
      expect(screenSrc.contains('IndexedStack('), isTrue);
      // V2.8.3.4：攻略视图由 KitTab 承载（末尾留白与时间线同口径）
      expect(screenSrc.contains('KitTab('), isTrue);
      expect(screenSrc.contains('canEdit: _canWrite,'), isTrue);
      expect(screenSrc.contains('_DetailDock('), isTrue);
      // 大纲入「更多」、装配半屏抽屉
      expect(screenSrc.contains('_openOutlineSheet'), isTrue);
      expect(screenSrc.contains('_openAssembleSheet'), isTrue);
      expect(screenSrc.contains('行程大纲'), isTrue);
    });
  });
}
