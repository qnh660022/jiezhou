// V2.7.2 S9：锦囊面板 Widget 用例（四栏渲染 / calendar 有无 / 空态 / viewer）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/guide/guide_normalize.dart';
import 'package:travel_assistant/data/guide/guide_providers.dart';
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/repo/checklist_repo.dart';
import 'package:travel_assistant/domain/guide_match.dart';
import 'package:travel_assistant/features/trips/widgets/kit_panel.dart';

KitSeed _seed({
  List<Map<String, dynamic>> calendar = const [],
}) =>
    KitSeed(
      cityKey: 'hangzhou',
      cityName: '杭州',
      area: '华东',
      prep: const [
        {'title': '预约与门票', 'detail': '故宫需实名预约，提前 7 天晚 8 点放票。'},
        {'title': '交通卡', 'detail': '地铁公交支持扫码。'},
      ],
      tips: const [
        {'title': '低价一日游陷阱', 'detail': '50 到 100 元包票包车几乎全是购物团。'},
      ],
      budget: const [
        {'item': '住宿', 'rangeText': '300-600/晚（参考）'},
      ],
      calendar: calendar,
    );

Future<void> _pump(WidgetTester tester,
    {required AppDatabase db,
    required String destination,
    bool canEdit = true,
    KitSeed? seed,
    String? cityKey}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        guideCityKeyByNameProvider.overrideWith((ref) async =>
            cityKey == null ? <String, String>{} : {'杭州': cityKey, '苏州': 'suzhou'}),
        kitSeedProvider.overrideWith((ref, key) async => seed),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: KitPanel(
              tripId: 't1',
              destination: destination,
              canEdit: canEdit,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late ChecklistRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = ChecklistRepository(db);
  });
  tearDown(() async => db.close());

  testWidgets('1. 四栏渲染：prep/tips/budget/城名大区，无 calendar 则不渲染',
      (tester) async {
    await _pump(tester,
        db: db, destination: '杭州', cityKey: 'hangzhou', seed: _seed());
    expect(find.text('杭州'), findsOneWidget);
    expect(find.text('华东'), findsOneWidget);
    expect(find.text('行前准备'), findsOneWidget);
    expect(find.text('避坑注意'), findsOneWidget);
    expect(find.text('预算参考'), findsOneWidget);
    expect(find.text('300-600/晚（参考）'), findsOneWidget,
        reason: 'rangeText 原样保留，不数字化');
    expect(find.text('季节日历'), findsNothing);
  });

  testWidgets('2. calendar 有则渲染整组', (tester) async {
    await _pump(
      tester,
      db: db,
      destination: '杭州',
      cityKey: 'hangzhou',
      seed: _seed(calendar: const [
        {'title': '1-2 月 · 水仙花季', 'detail': '春节前后全城花香。'},
      ]),
    );
    expect(find.text('季节日历'), findsOneWidget);
    expect(find.text('1-2 月 · 水仙花季'), findsOneWidget);
  });

  testWidgets('3. 目的地未命中城 → 空态卡', (tester) async {
    await _pump(tester, db: db, destination: '南京', cityKey: null, seed: null);
    expect(find.text('该目的地暂无锦囊'), findsOneWidget);
  });

  testWidgets('4. prep 加入清单：成功 toast；重复去重 toast「已在清单中」',
      (tester) async {
    await _pump(tester,
        db: db, destination: '杭州', cityKey: 'hangzhou', seed: _seed());
    await tester.tap(find.byIcon(Icons.playlist_add_rounded).first);
    await tester.pump();
    expect(find.text('已加入出行清单'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.playlist_add_rounded).first,
        warnIfMissed: false);
    await tester.pumpAndSettle();
    // 去重：两次点击仍只有一行（细节断言见 guide_match_test 仓储组）
    final rows = await repo.getAllByScope('trip', tripId: 't1');
    expect(rows, hasLength(1));
    expect(rows.first.label, '预约与门票');
    expect(rows.first.category, 'other');
  });

  testWidgets('5. viewer 只读：无加入清单入口', (tester) async {
    await _pump(tester,
        db: db, destination: '杭州', cityKey: 'hangzhou', seed: _seed(), canEdit: false);
    expect(find.byIcon(Icons.playlist_add_rounded), findsNothing);
    expect(find.text('行前准备'), findsOneWidget, reason: '列表仍可见');
  });

  test('GuideLocation 归一化与 matchCityKey 同城一致性（S11 共用前提）', () {
    // 同输入下，种子归一化与锦囊匹配都指向同城的 key
    final loc = normalizeGuideDestination('杭州市');
    expect(loc?.key, 'hangzhou');
    expect(matchCityKey('杭州市', {'杭州': 'hangzhou'}), loc?.key);
  });
}
