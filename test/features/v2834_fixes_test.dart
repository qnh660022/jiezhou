// V2.8.3.4：本轮 8 项修复的回归门禁。
//
// 覆盖：玻璃特效撤销（仅底栏保留）/ 角色判定硬化（记一笔与工具箱消失的根因）/
// 详情页长按拖拽 / 更多抽屉可上拉 / 时间线与攻略底部留白 / 攻略直接排天序号 /
// 我的页入口清理 / 启动锁关闭后黑屏。
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/sync/sync_account.dart' show SpaceRole;
import 'package:travel_assistant/features/ledger/ledger_access.dart';
import 'package:travel_assistant/features/lock/lock_screen.dart';
import 'package:travel_assistant/features/trips/trip_access.dart' as trips;
import 'package:travel_assistant/platform/app_lock.dart';
import 'package:travel_assistant/theme/tokens.dart';

String _src(String path) => File(path).readAsStringSync();

/// lib 下所有 dart 文件（相对仓库根，统一正斜杠）。
List<File> _libDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppLockGate.reset();
    AppLockService.resetCache();
    db = AppDatabase();
  });

  tearDown(() async {
    await db.close();
    AppLockGate.reset();
    AppLockService.resetCache();
  });

  // ---------------------------------------------------------------------
  // 一、角色判定硬化 —— 「记一笔」「工具箱」「局域网同步」同时消失的根因
  // ---------------------------------------------------------------------
  group('角色判定硬化（ledger_access / trip_access 同构）', () {
    Future<void> seedSpace(
      String id, {
      String? groupId,
      String? tripId,
      String createdBy = 'u-owner',
    }) =>
        db.into(db.travelSpaces).insert(TravelSpacesCompanion.insert(
              id: id,
              name: '空间',
              createdBy: createdBy,
              groupId: Value(groupId),
              tripId: Value(tripId),
              createdMs: 1,
              updatedMs: 1,
            ));

    Future<void> seedMember(String spaceId, String userId, String role) =>
        db.into(db.spaceMembers).insert(SpaceMembersCompanion.insert(
              id: 'sm-$spaceId-$userId-$role',
              spaceId: spaceId,
              userId: userId,
              role: Value(role),
              joinedMs: 1,
              createdMs: 1,
              updatedMs: 1,
            ));

    Future<void> seedLocalGroup(String id) => db.into(db.groups).insert(
        GroupsCompanion.insert(id: id, name: '我建的团', createdAt: 1, updatedAt: 1));

    Future<void> seedLocalTrip(String id) => db.into(db.trips).insert(
        TripsCompanion.insert(id: id, name: '我建的行程', createdAt: 1, updatedAt: 1));

    test('1. 空间创建者恒为 owner：成员行是历史/异常取值时不再被降级为观察者', () async {
      await seedSpace('s1', groupId: 'g1', tripId: 't1', createdBy: 'u-me');
      await seedMember('s1', 'u-me', ''); // 空串：旧列默认值/解码缺列
      expect(await resolveMyGroupRole(db, 'g1', 'u-me'), LedgerRole.owner);
      expect(await trips.resolveMyTripRole(db, 't1', 'u-me'), trips.TripRole.owner);
    });

    test('2. 历史取值 member（云端账本域词表）不再被误判为 viewer', () async {
      await seedSpace('s1', groupId: 'g1', tripId: 't1');
      await seedMember('s1', 'u-x', 'member');
      await seedLocalGroup('g1');
      await seedLocalTrip('t1');
      expect(await resolveMyGroupRole(db, 'g1', 'u-x'), LedgerRole.owner);
      expect(await trips.resolveMyTripRole(db, 't1', 'u-x'), trips.TripRole.owner);
    });

    test('3. 重复成员行（本地占位 + 服务端真行）取最高权限，不再抛异常', () async {
      await seedSpace('s1', groupId: 'g1');
      await seedMember('s1', 'u-me', SpaceRole.viewer);
      await seedMember('s1', 'u-me', SpaceRole.owner);
      expect(await resolveMyGroupRole(db, 'g1', 'u-me'), LedgerRole.owner);
    });

    test('4. 真正的观察者（非创建者 + 唯一 viewer 行）仍为只读', () async {
      await seedSpace('s1', groupId: 'g1');
      await seedMember('s1', 'u-x', SpaceRole.viewer);
      expect(await resolveMyGroupRole(db, 'g1', 'u-x'), LedgerRole.viewer);
      expect(LedgerAccess.of(LedgerRole.viewer).canWrite, isFalse);
    });

    test('5. 完全解析不出 → null，UI 按可写放开（写入口不得被误藏）', () async {
      expect(await resolveMyGroupRole(db, 'g-void', 'u-x'), isNull);
      expect(LedgerAccess.of(null).canWrite, isTrue);
      expect(trips.TripAccess.of(null).canWrite, isTrue);
    });

    test('6. normalizeSpaceRole：未知取值不参与竞争，多行取最高', () {
      expect(normalizeSpaceRole(const ['']), isNull);
      expect(normalizeSpaceRole(const ['member']), isNull);
      expect(normalizeSpaceRole(const []), isNull);
      expect(normalizeSpaceRole(const ['viewer', 'editor']), LedgerRole.editor);
      expect(normalizeSpaceRole(const ['viewer', 'editor', 'owner']),
          LedgerRole.owner);
      expect(normalizeSpaceRole(const ['member', 'viewer']), LedgerRole.viewer);
    });
  });

  // ---------------------------------------------------------------------
  // 二、玻璃特效撤销（唯一保留处 = 悬浮胶囊底栏）
  // ---------------------------------------------------------------------
  group('玻璃特效撤销', () {
    test('7. lib 内只有悬浮胶囊底栏显式开启实时模糊', () {
      final blurFiles = _libDartFiles()
          .where((f) => f.readAsStringSync().contains('blur: true'))
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList();
      expect(blurFiles, ['lib/shared/widgets/floating_capsule_nav_bar.dart'],
          reason: 'V2.8.3.4：玻璃只保留在底栏；命中：${blurFiles.join('、')}');
    });

    test('8. 顶栏不再走玻璃分支', () {
      final appBar = _src('lib/shared/widgets/glass_app_bar.dart');
      expect(appBar.contains('blur: true'), isFalse);
      expect(appBar.contains('GlassSurface('), isTrue,
          reason: '仍走统一表面组件，只是落在实色分支');
    });

    test('9. 玻璃默认关闭：GlassSurface.blur 缺省值必须是 false', () {
      final src = _src('lib/shared/widgets/glass_surface.dart');
      expect(src.contains('this.blur = false'), isTrue);
      expect(src.contains('final useGlass = blur && !fallbackOpaque;'), isTrue);
    });
  });

  // ---------------------------------------------------------------------
  // 三、行程详情页交互
  // ---------------------------------------------------------------------
  group('行程详情页交互', () {
    final detail = () => _src('lib/features/trips/screens/trip_detail_screen.dart');

    test('10. 拖动行程卡改为长按后允许', () {
      final src = detail();
      expect(src.contains('ReorderableDelayedDragStartListener'), isTrue);
      expect(src.contains('ReorderableDragStartListener'), isFalse,
          reason: '碰触即拖会在滚动流里误拖（旧实现）');
    });

    test('11.「更多」抽屉内容挂上 scrollController，可再次上拉', () {
      final src = detail();
      expect(src.contains('builder: (ctx, sheetScroll) => ListView('), isTrue);
      expect(src.contains('controller: sheetScroll'), isTrue);
    });

    test('12. 时间线与攻略末尾留白同口径（都让位底栏 + 停靠双段）', () {
      expect(detail().contains('AppBottomLayout.dockedContentTail'), isTrue);
      expect(detail().contains('AppBottomLayout.segmentDockHeight'), isTrue);
      final kit = _src('lib/features/trips/widgets/kit_panel.dart');
      expect(kit.contains('bottomInset'), isTrue);
      expect(AppBottomLayout.dockedContentTail,
          AppBottomLayout.contentTail + AppBottomLayout.segmentDockHeight);
    });

    test('13. 停靠双段横向 inset 与全局胶囊底栏对齐', () {
      final src = detail();
      // 停靠双段：left/right 必须是 Spacing.lg（= 底栏 Padding 值）
      expect(
          RegExp(r'Positioned\(\s*left: Spacing\.lg,\s*right: Spacing\.lg,')
              .hasMatch(src),
          isTrue,
          reason: 'V2.8.3.4：时间线/攻略停靠段应与底栏同宽并紧贴其上');
    });

    // -------------------------------------------------------------------
    // V2.8.3.5：停靠条「贴紧」底部胶囊栏（消除 2px 缝 + 视觉连体）
    // -------------------------------------------------------------------
    test('16. navBarHeight 是胶囊栏占位的单一真值，且停靠条用它定位', () {
      expect(AppBottomLayout.navBarHeight, 78,
          reason: '= FloatingCapsuleNavBar 的 4 + 66 + 8，不含安全区');
      final src = detail();
      expect(src.contains('AppBottomLayout.navBarHeight'), isTrue);
      expect(
          RegExp(r'bottom: AppBottomLayout\.withSafeArea\(\s*context,\s*'
                  r'AppBottomLayout\.navBarHeight,\s*\)')
              .hasMatch(src),
          isTrue,
          reason: '停靠双段不再复用 FAB 的 actionButtonOffset(80)，否则留 2px 缝');
    });

    test('17. 停靠条下两角归零、只留上左右三边描边（与胶囊栏连体）', () {
      final src = detail();
      expect(src.contains('BorderRadius.vertical(top: Radius.circular(18))'),
          isTrue,
          reason: 'V2.8.3.5：下两角归零才能与胶囊栏顶边接合');
      expect(
          RegExp(r'Border\(\s*top: BorderSide\(color: lineColor\),\s*'
                  r'left: BorderSide\(color: lineColor\),\s*'
                  r'right: BorderSide\(color: lineColor\),\s*\)')
              .hasMatch(src),
          isTrue,
          reason: '去下描边，保留上/左/右');
      expect(AppBottomLayout.segmentDockHeight, 56,
          reason: '按 _DetailDock 实测高（≈46）重算，留 10 与内容分隔');
    });

    test('18. 批量操作条不再用魔法数 62', () {
      final src = detail();
      expect(src.contains('AppBottomLayout.actionButtonOffset + 62'), isFalse,
          reason: 'V2.8.3.5：改走 navBarHeight + segmentDockHeight 同口径');
      expect(
          RegExp(r'AppBottomLayout\.navBarHeight \+\s*'
                  r'AppBottomLayout\.segmentDockHeight,')
              .hasMatch(src),
          isTrue);
    });
  });

  // ---------------------------------------------------------------------
  // 四、文案与入口
  // ---------------------------------------------------------------------
  group('文案与入口', () {
    test('14. 攻略「直接排」提示打印天序号（不再是 epochDay 两万多天）', () {
      final src = _src('lib/features/trips/screens/trip_guide_screen.dart');
      expect(src.contains(r'已排入第 $dayNo 天'), isTrue);
      expect(src.contains(r'已排入第 $day 天'), isFalse);
      expect(
          src.contains('rawDay.clamp(trip.startEpochDay, trip.endEpochDay)'),
          isTrue,
          reason: '落库前必须把天数夹取在行程区间内');
      // 弹层回传 (epochDay, dayNo, slot) 三元组
      expect(src.contains('showModalBottomSheet<(int, int, int)>'), isTrue);
      expect(src.contains('Navigator.pop(context, (day, dayNo, slot))'), isTrue);
    });

    test('15. 我的页移除「账本工具箱」入口', () {
      final src = _src('lib/features/settings/screens/profile_screen.dart');
      expect(src.contains("title: '账本工具箱'"), isFalse);
      expect(src.contains("'账本工具箱', '变更记录"), isFalse);
      expect(RegExp('账本工具箱').allMatches(src).length, lessThanOrEqualTo(1),
          reason: '仅允许注释保留一句「已移除」说明');
    });
  });

  // ---------------------------------------------------------------------
  // 五、启动锁
  // ---------------------------------------------------------------------
  group('启动锁', () {
    test('16. 锁屏吞掉返回键（防止根导航栈被弹空 → 全屏黑）', () {
      final src = _src('lib/features/lock/lock_screen.dart');
      expect(src.contains('PopScope('), isTrue);
      expect(src.contains('canPop: false'), isTrue);
    });

    test('17. 关闭锁后会话保持解锁：冷启动判据为「不锁」', () async {
      final svc = await AppLockService.cached();
      await svc.setPin('123456');
      expect(svc.enabled, isTrue);

      // 冷启动：会话标记复位 → 判据为「锁」
      AppLockService.sessionUnlocked = false;
      AppLockGate.reset();
      expect(await AppLockGate.load(), isTrue);

      // 关锁：必须留在这个「已解锁」态，否则会被弹回一个输不进 PIN 的锁屏
      expect(await svc.disable('123456'), isTrue);
      expect(svc.enabled, isFalse);
      expect(svc.saltHex, isNull);
      expect(AppLockService.sessionUnlocked, isTrue);
      expect(AppLockGate.locked, isFalse);
      expect(await AppLockGate.load(), isFalse);
    });

    testWidgets('18. 锁屏 PopScope 实测禁止 pop', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LockScreen()));
      await tester.pumpAndSettle();
      final scope = tester.widget<PopScope>(find.byType(PopScope));
      expect(scope.canPop, isFalse);
    });
  });
}
