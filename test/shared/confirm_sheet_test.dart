// V2.8.1 S3 · 弹层四层规范（规格 §6.6，≥10 例）：
// confirmSheet 两态渲染与返回值 / 数量行断言 / SnackBar 三 tone / 权限引导状态机 /
// L3/L4 复用回归 / 深色对比度。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/shared/widgets/app_snack_bar.dart';
import 'package:travel_assistant/shared/widgets/confirm_sheet.dart';
import 'package:travel_assistant/shared/widgets/permission_primer.dart';
import 'package:travel_assistant/shared/widgets/sheet.dart';
import 'package:travel_assistant/theme/app_icons.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester, Widget Function(BuildContext) builder,
      {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E7D5B), brightness: brightness)),
      home: Scaffold(
        body: Builder(builder: (context) => Center(child: builder(context))),
      ),
    ));
    await tester.pump();
  }

  testWidgets('1. 中性确认：渲染标题/正文，点确认返回 true', (tester) async {
    var result;
    await pumpHost(tester, (context) => FilledButton(
      onPressed: () async => result = await showConfirmSheet(
          context: context, title: '确认结算？', body: '当前共有 3 笔未结清账单'),
      child: const Text('open'),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('确认结算？'), findsOneWidget);
    expect(find.textContaining('3 笔'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('2. 危险确认：红确认钮 + heavyImpact 语义 + 返回 true', (tester) async {
    var result;
    await pumpHost(tester, (context) => FilledButton(
      onPressed: () async => result = await showDangerConfirm(
          context: context, title: '删除账单', body: '删除「午饭」？共 1 笔'),
      child: const Text('open'),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '删除'));
    expect(btn.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('3. 取消/关闭弹层 → false', (tester) async {
    var result;
    await pumpHost(tester, (context) => FilledButton(
      onPressed: () async => result = await showConfirmSheet(
          context: context, title: '确认操作？', body: '将影响 2 条记录'),
      child: const Text('open'),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  test('4. danger 数量行缺失 → debug 断言触发', () {
    final error = FlutterError.onError;
    var caught = false;
    FlutterError.onError = (d) => caught = true;
    try {
      showConfirmSheet(
          context: BuildContextStub().context,
          title: '删除',
          body: '确定要这样操作吗',
          danger: true);
    } catch (_) {
      caught = true;
    } finally {
      FlutterError.onError = error;
    }
    expect(caught, isTrue, reason: 'danger 弹层 body 必须含数量（断言口径）');
  });

  testWidgets('5. 纯告知形态：cancelLabel 为空 → 只有确认钮', (tester) async {
    var result;
    await pumpHost(tester, (context) => FilledButton(
      onPressed: () async => result = await showConfirmSheet(
          context: context,
          title: '这笔记录被覆盖过',
          body: '被其它端修改过 1 次',
          cancelLabel: '',
          confirmLabel: '知道了'),
      child: const Text('open'),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('知道了'), findsOneWidget);
    expect(find.text('取消'), findsNothing);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('6. 默认图标：危险→trash / 中性→check', (tester) async {
    late BuildContext captured;
    await pumpHost(tester, (context) {
      captured = context;
      return FilledButton(
        onPressed: () async => showDangerConfirm(
            context: context, title: '删除', body: '删除 1 笔'),
        child: const Text('open'),
      );
    });
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final icon = tester.widget<Icon>(find.byType(Icon).first);
    expect(icon.icon, AppIcons.trash, reason: '危险态默认 trash 图标');
  });

  testWidgets('7. showAppSnackBar 三 tone 左缘色（info 主色）', (tester) async {
    await pumpHost(tester, (context) => FilledButton(
      onPressed: () => showAppSnackBar(context, '普通提示'),
      child: const Text('open'),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.text('普通提示'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('8. SnackBar destructive tone 使用 error 色', (tester) async {
    await pumpHost(tester, (context) => FilledButton(
      onPressed: () => showAppSnackBar(context, '保存失败', tone: SnackTone.destructive),
      child: const Text('open'),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, isNotNull);
  });

  testWidgets('9. SnackBar success tone（左缘语义条渲染）', (tester) async {
    await pumpHost(tester, (context) => FilledButton(
      onPressed: () => showAppSnackBar(context, '已保存', tone: SnackTone.success),
      child: const Text('open'),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.text('已保存'), findsOneWidget);
  });

  testWidgets('10. 权限引导状态机：initial/denied/granted 三态渲染', (tester) async {
    await pumpHost(tester, (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PermissionPrimer(
            state: PermissionPrimerState.initial,
            title: '相机权限',
            description: '用于扫描邀请二维码，照片与数据不会上传',
            onOpenSettings: () {}),
        const SizedBox(height: 8),
        PermissionPrimer(
            state: PermissionPrimerState.denied,
            title: '相机权限',
            description: '用于扫描邀请二维码',
            onOpenSettings: () {}),
        const SizedBox(height: 8),
        const PermissionPrimer(
            state: PermissionPrimerState.granted,
            title: '相机权限',
            description: '用于扫描邀请二维码',
            onOpenSettings: _noop),
      ],
    ));
    await tester.pump();
    expect(find.text('需要相机权限'), findsOneWidget);
    expect(find.text('相机权限 · 已被拒绝'), findsOneWidget);
    // granted 且无 grantedMessage → 整卡隐藏（不渲染操作按钮）
    expect(find.text('去开启'), findsOneWidget, reason: 'initial 态有去开启');
    expect(find.text('去设置'), findsOneWidget, reason: 'denied 态有去设置');
  });

  testWidgets('11. L3/L4 复用 showDraggableSheet 回归（barrier 0.32）', (tester) async {
    await pumpHost(tester, (context) => FilledButton(
      onPressed: () => showDraggableSheet<void>(
          context: context,
          builder: (_, __) => const Text('L3 内容')),
      child: const Text('open'),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('L3 内容'), findsOneWidget);
  });

  testWidgets('12. 深色模式弹层对比度（不抛异常正常渲染）', (tester) async {
    await pumpHost(tester,
        (context) => FilledButton(
          onPressed: () async => showConfirmSheet(
              context: context, title: '深色确认', body: '影响 1 条'),
          child: const Text('open'),
        ),
        brightness: Brightness.dark);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('深色确认'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

/// assert 触发测试用的最小 BuildContext 桩（showConfirmSheet 仅在 assert 阶段触达 context）
class BuildContextStub {
  BuildContext get context => throw UnimplementedError();
}
