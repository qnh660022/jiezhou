/// ⚙️ AI 服务设置：OpenAI 兼容接口（Base URL / API Key / 模型名）+ 连通性测试。
///
/// 任意兼容 `/chat/completions` 的服务商都可接入；密钥仅保存在本机
/// SharedPreferences，随应用数据留存、不上传。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../data/services/ai_chat_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/tokens.dart';
import '../../trips/trip_widgets.dart';

/// 快速填充预设：baseUrl + 推荐模型名（均可再手改）
const _presets = [
  ('DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-chat'),
  ('通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'qwen-plus'),
  ('智谱 GLM', 'https://open.bigmodel.cn/api/paas/v4', 'glm-4-flash'),
  ('Kimi', 'https://api.moonshot.cn/v1', 'kimi-latest'),
  ('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
];

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  bool _testing = false;
  bool? _testOk;
  String _testMessage = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await ref.read(prefsRepoProvider).getAiConfig();
    if (!mounted) return;
    setState(() {
      _urlCtrl.text = config['baseUrl'] as String? ?? '';
      _keyCtrl.text = config['apiKey'] as String? ?? '';
      _modelCtrl.text = config['model'] as String? ?? '';
    });
  }

  Map<String, dynamic> _currentConfig() => {
        'baseUrl': _urlCtrl.text.trim(),
        'apiKey': _keyCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
      };

  Future<void> _save({String? savedToast}) async {
    await ref.read(prefsRepoProvider).setAiConfig(_currentConfig());
    ref.invalidate(aiConfigProvider);
    if (savedToast != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(savedToast)));
    }
  }

  Future<void> _testConnection() async {
    // 测试当前输入而不是已保存的旧值
    await _save();
    if (!mounted) return;
    setState(() {
      _testing = true;
      _testOk = null;
    });
    try {
      await ref.read(aiChatServiceProvider).chat(
            config: _currentConfig(),
            messages: const [
              AiMessage(role: 'user', content: 'ping'),
            ],
          );
      if (mounted) {
        setState(() {
          _testing = false;
          _testOk = true;
          _testMessage = '连接成功！';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testOk = false;
          _testMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlassAppBar(title: 'AI 设置'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('服务商预设',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: Spacing.sm),
                  Text('点击自动填入接口地址与推荐模型；使用自建/中转服务时直接手动填写下方三项即可。',
                      style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: Spacing.md),
                  Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.sm,
                    children: [
                      for (final p in _presets)
                        ActionChip(
                          label: Text(p.$1, style: const TextStyle(fontSize: AppFontSizes.caption)),
                          onPressed: () => setState(() {
                            _urlCtrl.text = p.$2;
                            _modelCtrl.text = p.$3;
                            _testOk = null;
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledField(
                    label: '接口地址 Base URL',
                    child: TextField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'https://api.deepseek.com/v1',
                      ),
                      onChanged: (_) => setState(() => _testOk = null),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  LabeledField(
                    label: 'API Key',
                    child: TextField(
                      controller: _keyCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(hintText: 'sk-...'),
                      onChanged: (_) => setState(() => _testOk = null),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  LabeledField(
                    label: '模型名称 Model',
                    child: TextField(
                      controller: _modelCtrl,
                      decoration: const InputDecoration(hintText: 'deepseek-chat / qwen-plus / glm-4-flash …'),
                      onChanged: (_) => setState(() => _testOk = null),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
            PrimaryButton(
              label: _testing ? '测试中…' : '测试连接',
              loading: _testing,
              expanded: true,
              icon: Icons.wifi_find_rounded,
              onPressed: (_testing || _urlCtrl.text.trim().isEmpty) ? null : _testConnection,
            ),
            if (_testOk != null) ...[
              const SizedBox(height: Spacing.md),
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: _testOk!
                      ? SemanticColors.income.withValues(alpha: 0.1)
                      : scheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: AppRadius.input,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testOk! ? Icons.check_circle_rounded : Icons.error_rounded,
                      color: _testOk! ? SemanticColors.income : scheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        _testOk! ? '连接成功！' : '连接失败：$_testMessage',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _testOk! ? SemanticColors.income : scheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Spacing.xxl),
            PrimaryButton(
              label: '保存配置',
              expanded: true,
              onPressed: () => _save(savedToast: '已保存 AI 配置'),
            ),
            const SizedBox(height: Spacing.xl),
            Row(
              children: [
                Icon(Icons.lock_rounded, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: Text(
                    'API Key 仅保存在本机，请求只发往你填写的接口地址。AI 仅能操作本应用内的数据。',
                    style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
