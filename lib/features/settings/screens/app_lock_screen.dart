/// 启动锁设置（V2.7.1 S7.2）。入口：我的 → 启动锁。
///
/// * 开启 / 重设 PIN：新 PIN（6 位数字）双重确认；
/// * 关闭锁：**必须先验证当前 PIN**（规格 §S7.2「关闭锁」行）；
/// * 页面写明「忘记 PIN = 只能用备份恢复」与平台存活边界（io / Web 文案不同）；
/// * 不提供任何生物识别开关（不引入 local_auth）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../platform/app_lock.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  AppLockService? _lock;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = await AppLockService.cached();
      if (!mounted) return;
      setState(() {
        _lock = svc;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool get _enabled => _lock?.enabled ?? false;

  Future<void> _onToggle(bool value) async {
    if (value) {
      final pin = await _askNewPin();
      if (pin == null || !mounted) return;
      await _lock!.setPin(pin);
      if (!mounted) return;
      _toast('启动锁已开启');
    } else {
      final pin = await _askExistingPin(title: '关闭启动锁', hint: '请输入当前 6 位 PIN');
      if (pin == null || !mounted) return;
      final ok = await _lock!.disable(pin);
      if (!mounted) return;
      // V2.8.3.4：关锁成功的当刻同步门控状态（locked=false / 会话已解锁），
      // 否则任何一次 `AppLockGate.load()` 都可能把刚关掉锁的用户弹回锁屏
      // ——此时 salt/hash 已删除，输什么 PIN 都进不去。
      if (ok) AppLockGate.markUnlocked();
      _toast(ok ? '启动锁已关闭' : 'PIN 不正确，未能关闭');
    }
    await _load();
  }

  Future<void> _changePin() async {
    // 「当前 PIN」已在弹窗内校验通过，这里只落新 PIN（避免二次校验）。
    final pin = await _askNewPin(title: '重设 PIN', requireCurrent: true);
    if (pin == null || !mounted) return;
    await _lock!.setPin(pin);
    if (!mounted) return;
    _toast('PIN 已更新');
  }

  void _toast(String msg) {
    // V2.8.3.3：收口到全 App 唯一轻提示形态（L1）。
    showAppSnackBar(context, msg);
}

  /// 输入当前 PIN。
  Future<String?> _askExistingPin({required String title, required String hint}) =>
      _showPinDialog(title: title, hint: hint, confirm: false, requireCurrent: true);

  /// 输入新 PIN（可要求先输入当前 PIN）。
  Future<String?> _askNewPin({String title = '开启启动锁', bool requireCurrent = false}) =>
      _showPinDialog(
        title: title,
        hint: '设置 6 位数字 PIN',
        confirm: true,
        requireCurrent: requireCurrent,
      );

  Future<String?> _showPinDialog({
    required String title,
    required String hint,
    required bool confirm,
    required bool requireCurrent,
  }) {
    return showDraggableSheet<String>(
      context: context,
      initialChildSize: 0.5,
      minChildSize: 0.35,
      builder: (dialogContext, scrollController) => _PinSheet(
        title: title,
        hint: hint,
        confirm: confirm,
        requireCurrent: requireCurrent,
        verifyCurrent: (pin) async => await _lock?.verify(pin) ?? false,
        scrollController: scrollController,
        onDone: (v) => Navigator.of(dialogContext).pop(v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('启动锁'), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: Spacing.xxxl),
              children: [
                SwitchListTile(
                  value: _enabled,
                  onChanged: _lock == null ? null : _onToggle,
                  title: const Text('启动锁',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('每次冷启动需要输入 6 位 PIN'),
                  secondary: const Icon(Icons.lock_outline_rounded),
                ),
                if (_enabled)
                  ListTile(
                    leading: const Icon(Icons.password_rounded),
                    title: const Text('重设 PIN'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _changePin,
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.xl, Spacing.lg, Spacing.xl, Spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('说明', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: Spacing.sm),
                      _Bullet('只在 App 冷启动时校验一次；不做进入账本的二次校验。'),
                      _Bullet('PIN 用 PBKDF2-HMAC-SHA256（10 万次迭代 + 随机盐）派生后仅存本机，不上云、不写日志。'),
                      _Bullet('连续错 $kMaxPinFailures 次会冷却 ${kPinCooldown.inSeconds} 秒，但不会擦除任何数据。'),
                      _Bullet('忘记 PIN 只能通过备份恢复数据：芥舟不提供后门、不设找回码。'),
                      _Bullet(appLockPlatformNote),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        '当前设备：${appLockVolatileWithSiteData ? 'Web（浏览器）' : 'App（原生）'}',
                        style: TextStyle(
                            fontSize: AppFontSizes.caption,
                            color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// PIN 输入抽屉（V2.8.3.4 重写：控制器归本组件所有，随路由一起销毁）。
///
/// 原实现把 3 个 `TextEditingController` 建在 `_showPinDialog` 的局部作用域，
/// `await showDraggableSheet(...)` 返回后**立刻** dispose —— 而此刻抽屉的退场
/// 动画还没跑完，输入框会在动画帧里再次 build，抛出
/// 「A TextEditingController was used after being disposed」。
/// 该异常落在弹层退场帧里，release 下表现为一块黑屏/黑抽屉。改由 State 持有
/// 并在 `dispose()` 回收后，生命周期与路由严格一致。
class _PinSheet extends StatefulWidget {
  const _PinSheet({
    required this.title,
    required this.hint,
    required this.confirm,
    required this.requireCurrent,
    required this.verifyCurrent,
    required this.scrollController,
    required this.onDone,
  });

  final String title;
  final String hint;

  /// 需要「再输一次确认」。
  final bool confirm;

  /// 需要先校验当前 PIN。
  final bool requireCurrent;

  final Future<bool> Function(String pin) verifyCurrent;
  final ScrollController scrollController;

  /// 回传结果（null = 取消）。
  final ValueChanged<String?> onDone;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _currentCtl = TextEditingController();
  final _ctl = TextEditingController();
  final _ctl2 = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _error = '';

  @override
  void dispose() {
    _currentCtl.dispose();
    _ctl.dispose();
    _ctl2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.confirm && _ctl.text != _ctl2.text) {
      setState(() => _error = '两次输入不一致');
      return;
    }
    if (widget.requireCurrent && !await widget.verifyCurrent(_currentCtl.text)) {
      if (!mounted) return;
      setState(() => _error = '当前 PIN 不正确');
      return;
    }
    if (!mounted) return;
    widget.onDone(_ctl.text);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.sm,
        Spacing.lg,
        Spacing.lg,
      ),
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Spacing.md),
        Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.requireCurrent)
                _PinField(controller: _currentCtl, label: '当前 PIN'),
              _PinField(controller: _ctl, label: widget.hint),
              if (widget.confirm)
                _PinField(controller: _ctl2, label: '再输一次确认'),
            ],
          ),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            _error,
            style: TextStyle(
              fontSize: AppFontSizes.caption,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => widget.onDone(null),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: _submit,
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('· ',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// 6 位数字输入框（统一键盘类型、长度与校验文案）。
class _PinField extends StatelessWidget {
  const _PinField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: TextFormField(
        controller: controller,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: kPinLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
        ),
        validator: (v) {
          final s = (v ?? '').trim();
          if (s.length != kPinLength) return '请输入 $kPinLength 位数字';
          return null;
        },
      ),
    );
  }
}
