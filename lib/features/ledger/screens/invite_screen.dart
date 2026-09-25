/// 邀请加入页（V2.6 /invite，Web 深链）：未登录先登录（携带 ?c= 回填），
/// 已登录输入/回填 6 位码 → add_collab_member → 提示并回账本首页。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/sync/sync_account.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../../companions/space_actions.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, this.code});

  /// 从路由 query ?c= 解出的邀请码。
  final String? code;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  late final TextEditingController _code = TextEditingController(text: widget.code ?? '');
  bool _busy = false;
  String? _message;

  Future<void> _join() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      // 未登录：引导登录后原地回填继续（§3.13.1）
      final ok = await showLoginGate(context);
      if (!ok) return;
    }
    final svc = ref.read(collabServiceProvider);
    if (svc == null) {
      setState(() => _message = copy('sync.status.unconfigured'));
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // V2.6.6.2 §7.4：加入逻辑统一切到 join_space（服务端内置旧账本码回退，
      // 客户端另有一层 add_collab_member 兜底，见 data/sync/join_flow.dart）。
      final (spaceId, legacy, err) = await SpaceActions.join(ref, _code.text);
      if (!mounted) return;
      if (err.isEmpty) {
        // 加入成功：重置空间域 + 行程域游标并全量拉取（引擎内部处理）
        showAppSnackBar(context,
            legacy ? '已加入（旧共享账本已自动升级为旅伴空间）' : copy('share.joinOk'));
        if (spaceId.isNotEmpty) {
          // V2.9.0:context.go 清栈后落地页无返回路径 —— 改 pushReplacement,
          // 保持顶层全屏语义,仅修返回栈(可返回账本首页)。
          context.pushReplacement('/companions/space/$spaceId');
        } else {
          context.go('/ledger');
        }
      } else {
        setState(() => _message = spaceErrorText(err));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> showLoginGate(BuildContext context) async {
    // V2.9.0:裸 showModalBottomSheet 在透明主题下内容重叠,统一收口 showDraggableSheet。
    final ok = await showDraggableSheet<bool>(
      context: context,
      initialChildSize: 0.42,
      minChildSize: 0.3,
      builder: (sheetContext, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
        child: const _MiniLoginGate(),
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      // V2.9.0:次级页顶栏统一 GlassAppBar。
      appBar: GlassAppBar(title: copy('share.joinTitle')),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(children: [
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: copy('share.joinBody'),
              counterText: '',
            ),
          ),
          const SizedBox(height: Spacing.lg),
          FilledButton(onPressed: _busy ? null : _join, child: Text(copy('share.joinTitle'))),
          if (_message != null) ...[
            const SizedBox(height: Spacing.md),
            Text(_message!, style: TextStyle(color: scheme.error, fontSize: AppFontSizes.caption)),
          ],
        ]),
      ),
    );
  }
}

class _MiniLoginGate extends ConsumerStatefulWidget {
  const _MiniLoginGate();

  @override
  ConsumerState<_MiniLoginGate> createState() => _MiniLoginGateState();
}

class _MiniLoginGateState extends ConsumerState<_MiniLoginGate> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final svc = ref.read(cloudAccountServiceProvider);
    if (svc == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await svc.signIn(_email.text.trim(), _password.text);
      await onSignedIn(ref);
      if (mounted) Navigator.pop(context, true);
    } on CloudAccountException catch (e) {
      setState(() => _error = e.code == 'bad_credentials'
          ? copy('cloud.errBadCredentials')
          : copy('cloud.errGeneric'));
    } catch (_) {
      setState(() => _error = copy('cloud.errNetwork'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // V2.9.0:键盘避让由 SheetContainer 统一处理,内层不再自加 viewInsets。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(copy('share.needLogin'), textAlign: TextAlign.center),
        const SizedBox(height: Spacing.lg),
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
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: AppFontSizes.caption)),
        ],
        const SizedBox(height: Spacing.lg),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(copy('cloud.submitLogin'))),
      ]),
    );
  }
}
