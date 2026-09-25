/// 云端账号页（V2.6 §3.17.1）：路由 /profile/cloud。
/// 未登录态：登录/注册同表单；已登录态：账号 + 退出 + 清云端 + AI 配置。
/// 端点配置入口已移除（V2.6.1）：后端密钥仅由构建时 --dart-define 默认注入。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers.dart';
import '../../../theme/theme_provider.dart' show sharedPreferencesProvider;
import '../../../data/sync/sync_account.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/tokens.dart';

class CloudAccountScreen extends ConsumerStatefulWidget {
  const CloudAccountScreen({super.key});

  @override
  ConsumerState<CloudAccountScreen> createState() => _CloudAccountScreenState();
}

class _CloudAccountScreenState extends ConsumerState<CloudAccountScreen> {
  bool _tabSignup = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _aiModel = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAiLocal();
  }

  Future<void> _loadAiLocal() async {
    final cfg = await ref.read(prefsRepoProvider).getAiConfig();
    if (!mounted) return;
    setState(() {
      _baseUrl.text = (cfg['baseUrl'] as String?) ?? '';
      _apiKey.text = (cfg['apiKey'] as String?) ?? '';
      _aiModel.text = (cfg['model'] as String?) ?? '';
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    _aiModel.dispose();
    super.dispose();
  }

  bool _validEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

  Future<void> _submitAuth() async {
    final svc = ref.read(cloudAccountServiceProvider);
    if (svc == null) {
      setState(() => _error = copy('cloud.notConfigured'));
      return;
    }
    final email = _email.text.trim();
    final pass = _password.text;
    if (!_validEmail(email)) {
      // V2.9.0:邮箱格式错误给专用文案(原误用通用「操作失败」，根因被吞)。
      setState(() => _error = '邮箱格式不正确');
      return;
    }
    // 密码强度仅在注册（设置新密码）时强制；登录不拦，避免老密码（6 位）用户被锁死。
    if (_tabSignup) {
      final issue = signupPasswordIssue(pass);
      if (issue != null) {
        setState(() => _error = _mapErr(issue));
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_tabSignup) {
        await svc.signUp(email, pass);
      } else {
        await svc.signIn(email, pass);
      }
      await onSignedIn(ref);
      await _maybeBootstrapUpload();
      if (mounted) setState(() {});
    } on CloudAccountException catch (e) {
      setState(() => _error = _mapErr(e.code, detail: e.detail));
    } catch (_) {
      setState(() => _error = copy('cloud.errNetwork'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mapErr(String code, {String? detail}) {
    // 未知错误码透出服务端原文（此前一律「操作失败」把根因吞掉，无法定位）。
    final fallback = (detail == null || detail.isEmpty)
        ? copy('cloud.errGeneric')
        : '${copy('cloud.errGeneric')}（${detail.trim()}）';
    return switch (code) {
      'email_taken' => copy('cloud.errEmailTaken'),
      'password_short' => copy('cloud.errPasswordShort'),
      'password_weak' => copy('cloud.errPasswordWeak'),
      'bad_credentials' => copy('cloud.errBadCredentials'),
      'email_send_failed' => copy('cloud.errEmailSendFailed'),
      'rate_limited' => copy('cloud.errNetwork'),
      _ => fallback,
    };
  }

  /// 首次引导（§3.10）：未引导账号询问「上传本地数据？」。
  Future<void> _maybeBootstrapUpload() async {
    final engine = ref.read(syncEngineProvider);
    final uid = ref.read(currentUserIdProvider);
    if (engine == null || uid == null) return;
    final bootstrapped = ref.read(sharedPreferencesProvider).getBool('sync_bootstrapped_$uid') ?? false;
    if (bootstrapped) return;
    if (!mounted) return;
    final upload = await showConfirmSheet(
      context: context,
      title: copy('cloud.uploadAskTitle'),
      body: copy('cloud.uploadAskBody'),
      confirmLabel: copy('cloud.uploadYes'),
      cancelLabel: copy('cloud.uploadNo'),
    );
    if (upload) {
      await engine.bootstrapUploadAll();
    } else {
      await engine.syncNow(push: false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showConfirmSheet(
      context: context,
      title: copy('cloud.signOut'),
      body: copy('cloud.signOutConfirm'),
      confirmLabel: copy('cloud.signOut'),
    );
    if (!confirmed) return;
    final svc = ref.read(cloudAccountServiceProvider);
    await svc?.signOut();
    await onSignedOut(ref);
    if (mounted) setState(() {});
  }

  Future<void> _purgeCloud() async {
    final svc = ref.read(cloudAccountServiceProvider);
    if (svc == null) return;
    var ok = await showConfirmSheet(
      context: context,
      title: copy('cloud.purge'),
      body: copy('cloud.purgeConfirm1'),
      confirmLabel: '确定',
    );
    if (!ok) return;
    ok = await showConfirmSheet(
      context: context,
      title: copy('cloud.purge'),
      body: copy('cloud.purgeConfirm2'),
      confirmLabel: '确定清除',
    );
    if (!ok) return;
    try {
      await svc.purgeMyData();
      final engine = ref.read(syncEngineProvider);
      await ref.read(syncOutboxResetProvider)(); // outbox 清空 + 游标归零
      await engine?.syncNow(push: false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(copy('cloud.purged'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(copy('cloud.errGeneric'))));
      }
    }
  }

  Future<void> _saveAiCloud() async {
    // 本机 AI 配置照常保存（apiKey 仅本机）；baseUrl/model 另存云端 app_settings
    final prefs = ref.read(prefsRepoProvider);
    await prefs.setAiConfig({
      'baseUrl': _baseUrl.text.trim(),
      'apiKey': _apiKey.text,
      'model': _aiModel.text.trim(),
    });
    ref.invalidate(aiConfigProvider);
    final svc = ref.read(cloudAccountServiceProvider);
    try {
      await svc?.saveCloudAiSetting('ai.base_url', _baseUrl.text.trim());
      await svc?.saveCloudAiSetting('ai.model', _aiModel.text.trim());
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final email = ref.watch(currentUserEmailProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      // V2.9.0:次级页顶栏统一 GlassAppBar(原裸 AppBar)。
      appBar: GlassAppBar(title: copy('cloud.title')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          if (uid == null) ..._buildAuthForm(scheme) else ..._buildSignedIn(scheme, email),
          const SizedBox(height: Spacing.xl),
          TextButton(
            onPressed: () => context.push('/profile/cloud/sync'),
            child: Text(copy('sync.center')),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Card(
        margin: EdgeInsets.zero,
        child: Padding(padding: const EdgeInsets.all(Spacing.lg), child: child),
      );

  List<Widget> _buildAuthForm(ColorScheme scheme) => [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(copy('cloud.tabLogin'))),
                    ButtonSegment(value: true, label: Text(copy('cloud.tabSignup'))),
                  ],
                  selected: {_tabSignup},
                  onSelectionChanged: (s) => setState(() => _tabSignup = s.first),
                ),
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
                  Text(_error!, style: TextStyle(color: scheme.error, fontSize: AppFontSizes.caption)),
                ],
                const SizedBox(height: Spacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _submitAuth,
                  child: Text(_busy ? '…' : (_tabSignup ? copy('cloud.submitSignup') : copy('cloud.submitLogin'))),
                ),
              ],
            ),
          ),
        ),
      ];

  List<Widget> _buildSignedIn(ColorScheme scheme, String? email) => [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(copy('cloud.signedInAs'),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppFontSizes.caption)),
          const SizedBox(height: Spacing.xs),
          Text(email ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: Spacing.md),
          Row(children: [
            OutlinedButton(onPressed: _signOut, child: Text(copy('cloud.signOut'))),
            const SizedBox(width: Spacing.md),
            OutlinedButton(
                onPressed: _purgeCloud,
                style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                child: Text(copy('cloud.purge'))),
          ]),
        ])),
        const SizedBox(height: Spacing.xl),
        SectionHeader(title: copy('cloud.aiSection')),
        _card(Column(children: [
          TextField(controller: _baseUrl, decoration: InputDecoration(labelText: copy('cloud.aiBaseUrl'))),
          const SizedBox(height: Spacing.md),
          TextField(controller: _aiModel, decoration: InputDecoration(labelText: copy('cloud.aiModel'))),
          const SizedBox(height: Spacing.md),
          TextField(
              controller: _apiKey,
              obscureText: true,
              decoration: InputDecoration(labelText: copy('cloud.aiKeyLocal'))),
          const SizedBox(height: Spacing.md),
          FilledButton(onPressed: _saveAiCloud, child: const Text('保存')),
        ])),
      ];
}

/// 挂在 providers 之外的小工具：清 outbox + 游标（purge 后调用）。
final syncOutboxResetProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final engine = ref.read(syncEngineProvider);
    // outbox/meta 服务挂在引擎上；通过一次全量 reset 语义完成
    await engine?.resetLocalSyncState();
  };
});
