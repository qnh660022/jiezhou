// 回归测试：SpaceCard / SpaceAvatarStack 布局（2026-09-13）。
//
// 历史 bug：SpaceAvatarStack 内层 Stack 只含 Positioned 子级，被放进 Row
// （无界宽）时布局崩溃（debug 断言 "A Stack requires bounded constraints"，
// release 渲染成乱版 —— 空间名消失、「1 位旅伴」逐字竖排、卡内大片空白）。
// 修复：Stack 给显式宽度。本测试在手机尺寸下整卡渲染，断言无异常且
// 空间名 / 成员数文本正常排布（非逐字竖排）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/features/companions/widgets/space_widgets.dart';
import 'package:travel_assistant/theme/tokens.dart';

TravelSpace _space() => TravelSpace(
      id: 'sp1',
      name: '厦门',
      tripId: null,
      groupId: null,
      createdBy: 'u1',
      note: null,
      status: 'active',
      createdMs: 1,
      updatedMs: 1,
      deletedMs: null,
    );

List<SpaceMember> _members() => const [
      SpaceMember(
        id: 'sm1',
        spaceId: 'sp1',
        userId: 'u1',
        role: 'owner',
        displayName: '我',
        joinedMs: 1,
        createdMs: 1,
        updatedMs: 1,
        deletedMs: null,
      ),
    ];

Widget _app(Widget child) => MaterialApp(
      theme: buildAppThemeFor(ThemeFamily.mint, ThemeBrightnessMode.light),
      home: Scaffold(
        body: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('SpaceCard 在手机宽度下不崩溃、不逐字竖排', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(_app(SpaceCard(
      space: _space(),
      members: _members(),
      myRole: 'owner',
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // 空间名完整可见（未因布局崩坏消失）
    expect(find.text('厦门'), findsOneWidget);
    // 成员数文本宽度必须容得下整串文字（逐字竖排 = 宽度 ~14）
    final text = tester.renderObject<RenderBox>(find.text('1 位旅伴'));
    expect(text.size.width, greaterThan(40));
    // 头像叠放有真实宽度（此前恒为 0，头像被裁剪不可见）
    final avatar = tester.renderObject<RenderBox>(find.byType(SpaceAvatarStack));
    expect(avatar.size.width, greaterThan(0));
  });

  testWidgets('SpaceAvatarStack 多成员时宽度按叠放规则计算', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    final members = List<SpaceMember>.generate(
      6,
      (i) => SpaceMember(
        id: 'sm$i',
        spaceId: 'sp1',
        userId: 'u$i',
        role: 'editor',
        displayName: '旅伴$i',
        joinedMs: i,
        createdMs: i,
        updatedMs: i,
        deletedMs: null,
      ),
    );
    await tester.pumpWidget(_app(Row(children: [
      SpaceAvatarStack(names: [
        for (final m in members) m.displayName,
      ], size: 26),
    ])));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // max=4 → 4 个头像 + "+2" 胶囊：宽 = (5-1)*(26-9) + 26 = 94
    final box = tester.renderObject<RenderBox>(find.byType(SpaceAvatarStack));
    expect(box.size.width, 94);
    expect(find.text('+2'), findsOneWidget);
  });
}
