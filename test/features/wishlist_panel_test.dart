// V2.7.2 S6：想去池面板 Widget 用例 + 分组/时长校验纯函数用例。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/repo/wishlist_repo.dart';
import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/features/trips/widgets/wishlist_panel.dart';

WishlistRecord _rec(String id,
        {String cityKey = '',
        String name = '条目',
        int? durationMin,
        String? tag,
        String? guideRef,
        int sortOrder = 10}) =>
    WishlistRecord(
      id: id,
      tripId: 't1',
      cityKey: cityKey,
      name: name,
      address: '',
      type: 'attraction',
      durationMin: durationMin,
      tag: tag,
      guideRef: guideRef,
      note: '',
      sortOrder: sortOrder,
      createdAt: 1000,
      updatedAt: 1000,
    );

Future<({AppDatabase db, WishlistRepository repo})> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final db = AppDatabase();
  return (db: db, repo: WishlistRepository(db));
}

Widget _host(AppDatabase db, {required Widget child, List<Override>? extra}) {
  return ProviderScope(
    overrides: [dbProvider.overrideWithValue(db), ...?extra],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(height: 600, child: child),
      ),
    ),
  );
}

void main() {
  test('1. parseWishlistDuration：10–720 合法，越界/非法拒绝', () {
    expect(parseWishlistDuration('10'), 10);
    expect(parseWishlistDuration('720'), 720);
    expect(parseWishlistDuration(' 90 '), 90);
    expect(parseWishlistDuration('9'), isNull);
    expect(parseWishlistDuration('721'), isNull);
    expect(parseWishlistDuration(''), isNull);
    expect(parseWishlistDuration('abc'), isNull);
    expect(parseWishlistDuration('-5'), isNull);
  });

  test('2. groupWishlistByCity：分组保序；空 key 归未分类', () {
    final grouped = groupWishlistByCity([
      _rec('a', cityKey: 'hz', name: 'A'),
      _rec('b', cityKey: '', name: 'B'),
      _rec('c', cityKey: 'hz', name: 'C'),
      _rec('d', cityKey: 'sz', name: 'D'),
    ]);
    expect(grouped.keys.toList(), ['hz', '', 'sz']);
    expect(grouped['hz']!.map((e) => e.name), ['A', 'C']);
    expect(grouped['']!.map((e) => e.name), ['B']);
    expect(wishlistGroupLabel('', null), '未分类');
    expect(wishlistGroupLabel('hz', (k) => '杭州'), '杭州');
  });

  testWidgets('3. 渲染：分组、名称、未估时、来源角标', (tester) async {
    final (:db, :repo) = await _setup();
    await repo.addItem(tripId: 't1', name: '攻略条目', guideRef: 'hz#spots#0', cityKey: 'hz');
    await repo.addItem(tripId: 't1', name: '手动条目');
    addTearDown(db.close);
    await tester.pumpWidget(_host(db,
        child: WishlistPanel(tripId: 't1', canEdit: true)));
    await tester.pumpAndSettle();
    expect(find.text('攻略条目'), findsOneWidget);
    expect(find.text('手动条目'), findsOneWidget);
    expect(find.text('未估时'), findsWidgets);
    expect(find.text('攻略'), findsWidgets);
    expect(find.text('未分类'), findsOneWidget, reason: '空 cityKey 归未分类组');
  });

  testWidgets('4. 空池：空态文案', (tester) async {
    final (:db, :repo) = await _setup();
    addTearDown(db.close);
    await tester.pumpWidget(_host(db,
        child: WishlistPanel(tripId: 't1', canEdit: true)));
    await tester.pumpAndSettle();
    expect(find.text('想去池还是空的'), findsOneWidget);
  });

  testWidgets('5. viewer 只读：无表单、无操作菜单', (tester) async {
    final (:db, :repo) = await _setup();
    await repo.addItem(tripId: 't1', name: '只读条目');
    addTearDown(db.close);
    await tester.pumpWidget(_host(db,
        child: WishlistPanel(tripId: 't1', canEdit: false)));
    await tester.pumpAndSettle();
    expect(find.text('只读条目'), findsOneWidget);
    expect(find.text('手动添加想去'), findsNothing);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
  });

  testWidgets('6. 手动表单：name 必填（空名保存不可用）→ 填名入池', (tester) async {
    final (:db, :repo) = await _setup();
    addTearDown(db.close);
    await tester.pumpWidget(_host(db,
        child: WishlistPanel(tripId: 't1', canEdit: true)));
    await tester.pumpAndSettle();

    final saveBtn = find.widgetWithText(FilledButton, '加入想去');
    expect(saveBtn, findsOneWidget);
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNull,
        reason: 'name 必填：空名时保存禁用');

    await tester.enterText(
        find.widgetWithText(TextField, '名称（必填）'), '手滑加的');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNotNull);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    final rows = await repo.getByTrip('t1');
    expect(rows.map((e) => e.name), ['手滑加的']);
    expect(rows.first.type, 'attraction', reason: '默认类型 attraction');
  });
}
