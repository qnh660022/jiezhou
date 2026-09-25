/// 登录引导 sheet（V2.6 §3.17.4）：未登录点任何云能力入口时弹出；
/// 成功后原地回填原操作（[onSignedInCallback]）。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/sync_account.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';

/// 返回 true = 登录成功（调用方继续执行原操作）。
Future<bool> showLoginGateSheet(BuildContext context, WidgetRef ref,
    {Future<void> Function()? onSignedInCallback}) async {
  // V2.9.0:改走 showDraggableSheet 统一入口——原裸 showModalBottomSheet 未包
  // 表面(全局透明 bottomSheetTheme → 字与底层页面文字重叠事故形态),且缺
  // 拖拽把手与键盘避让。
  final ok = await showDraggableSheet<bool>(
    context: context,
    initialChildSize: 0.55,
    minChildSize: 0.38,
    builder: (ctx, scrollController) => SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
      child: _LoginGateSheet(onSignedInCallback: onSignedInCallback),
    ),
  );
  return ok == true;
}

class _LoginGateSheet extends ConsumerStatefulWidget {
  const _LoginGateSheet({this.onSignedInCallback});

  final Future<void> Function()? onSignedInCallback;

  @override
  ConsumerState<_LoginGateSheet> createState() => _LoginGateSheetState();
}

class _LoginGateSheetState extends ConsumerState<_LoginGateSheet> {
  bool _signup = false;
  bool _busy = false;
  String? _error;
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final svc = ref.read(cloudAccountServiceProvider);
    if (svc == null) return;
    // 密码强度仅在注册（设置新密码）时强制；登录不拦，避免老密码（6 位）用户被锁死。
    if (_signup) {
      final issue = signupPasswordIssue(_password.text);
      if (issue != null) {
        setState(() => _error = copy(issue == 'password_short'
            ? 'cloud.errPasswordShort'
            : 'cloud.errPasswordWeak'));
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signup) {
        await svc.signUp(_email.text.trim(), _password.text);
      } else {
        await svc.signIn(_email.text.trim(), _password.text);
      }
      await onSignedIn(ref);
      await widget.onSignedInCallback?.call();
      if (mounted) Navigator.pop(context, true);
    } on CloudAccountException catch (e) {
      setState(() => _error = switch (e.code) {
            'email_taken' => copy('cloud.errEmailTaken'),
            'password_short' => copy('cloud.errPasswordShort'),
            'password_weak' => copy('cloud.errPasswordWeak'),
            'bad_credentials' => copy('cloud.errBadCredentials'),
            _ => copy('cloud.errGeneric'),
          });
    } catch (_) {
      setState(() => _error = copy('cloud.errNetwork'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(copy('cloudLoginIntro'),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: Spacing.lg),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(copy('cloud.tabLogin'))),
              ButtonSegment(value: true, label: Text(copy('cloud.tabSignup'))),
            ],
            selected: {_signup},
            onSelectionChanged: (s) => setState(() => _signup = s.first),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: copy('cloud.email'))),
          const SizedBox(height: Spacing.md),
          TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: copy('cloud.password'))),
          if (_error != null) ...[
            const SizedBox(height: Spacing.md),
            Text(_error!, style: TextStyle(color: scheme.error, fontSize: AppFontSizes.caption)),
          ],
          const SizedBox(height: Spacing.lg),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? '…' : (_signup ? copy('cloud.submitSignup') : copy('cloud.submitLogin'))),
          ),
        ]),
      ),
    );
  }
}
