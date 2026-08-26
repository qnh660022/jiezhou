
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_assistant/router.dart' as app;
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/core/uid.dart';
import 'package:drift/drift.dart' show Value;

void main() {
  testWidgets('ui smoke overflow scan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360 * 3, 690 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final trips = container.read(tripsRepoProvider);
    final ledger = container.read(ledgerRepoProvider);
    final today = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    final tripId = await trips.createTrip(
      name: '特别长的行程名称用来测试文本溢出边界情况',
      dest: '东京 · 京都 · 大阪很长的目的地信息',
      start: today - 1,
      end: today + 2,
    );
    await trips.insertItem(TripItemsCompanion.insert(
      id: newId('item'),
      tripId: tripId,
      dateEpochDay: Value(today),
      type: Value('food'),
      name: Value('非常长名称的安排项目用来测试时间轴卡片文本溢出'),
      sortOrder: Value(10),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    final group = await ledger.addGroup('特别长的旅行团名称', '🧭');
    await ledger.setActiveGroup(group.id);
    await ledger.addMember(group.id, '非常非常长的成员昵称');
    await ledger.addExpense(ExpensesCompanion.insert(
      id: newId('expense'),
      groupId: group.id,
      title: Value('非常长标题的账单用来测试省略与换行行为'),
      amountCents: Value(123456),
      dateEpochDay: Value(today),
      categoryKey: Value('food'),
      currency: Value('CNY'),
      rate: Value(100.0),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));

    final errors = <String>[];
    FlutterError.onError = (d) => errors.add(d.toString());

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: app.appRouter),
    ));
    await tester.pump(const Duration(seconds: 2));

    Future<void> go(String loc) async {
      app.appRouter.go(loc);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
    }

    Future<void> push(String loc, [Object? extra]) async {
      await app.appRouter.push(loc, extra: extra);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    await go('/trips');
    await go('/checklist');
    await go('/ledger');
    await go('/expenses');
    await go('/profile');
    await go('/ledger/groups');
    await go('/ledger/members');
    await go('/expenses/categories');
    await push('/trips/detail', tripId);
    await push('/trips/map', tripId);
    await push('/trips/album', tripId);
    await push('/trips/export', tripId);
    await push('/trips/share', tripId);
    await push('/expenses/edit');
    await push('/expenses/stats');

    // ignore: avoid_print
    print('SMOKE_ERRORS=' + errors.length.toString());
    for (final e in errors.take(30)) {
      // ignore: avoid_print
      print(e);
    }
  });
}
