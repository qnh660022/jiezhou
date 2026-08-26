// ⚙️ 地图服务设置：腾讯/高德 key 可视化配置 + 连通性测试
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/tokens.dart';
import '../trip_widgets.dart';

/// 地图服务设置页
class MapSettingsScreen extends ConsumerStatefulWidget {
  const MapSettingsScreen({super.key});

  @override
  ConsumerState<MapSettingsScreen> createState() => _MapSettingsScreenState();
}

class _MapSettingsScreenState extends ConsumerState<MapSettingsScreen> {
  String _provider = 'none';
  final _keyCtrl = TextEditingController();
  bool _testing = false;
  bool _testResult = false;
  bool _hasTested = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await ref.read(prefsRepoProvider).getMapConfig();
    if (mounted) {
      setState(() {
        _provider = config['provider'] as String? ?? 'none';
        _keyCtrl.text = config['key'] as String? ?? '';
      });
    }
  }

  Future<void> _save() async {
    await ref.read(prefsRepoProvider).setMapConfig({
      'provider': _provider,
      'key': _keyCtrl.text.trim(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已保存地图配置')));
    }
  }

  Future<void> _testConnection() async {
    setState(() { _testing = true; _hasTested = false; });
    final ok = await ref.read(travelTimeServiceProvider).pingProvider();
    if (mounted) setState(() { _testing = false; _testResult = ok; _hasTested = true; });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlassAppBar(title: '地图服务设置'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Provider selection
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('地图服务', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: Spacing.sm),
                  Text('默认使用 OSM 免费地图，无需配置。如需真实路线规划，请配置服务商 Key',
                      style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: Spacing.md),
                  for (final opt in [
                    _ProviderOption('none', 'OSM (默认)', '免费开放地图，无需 Key'),
                    _ProviderOption('qq', '腾讯地图', '支持驾车/步行/公交路线规划'),
                    _ProviderOption('amap', '高德地图', '支持驾车/步行/公交路线规划'),
                  ])
                    RadioListTile<String>(
                      value: opt.id,
                      groupValue: _provider,
                      onChanged: (v) => setState(() { _provider = v!; _hasTested = false; }),
                      title: Text(opt.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(opt.desc, style: TextStyle(fontSize: AppFontSizes.caption)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // API Key input
            if (_provider != 'none')
              SectionCard(
                child: LabeledField(
                  label: _provider == 'qq' ? '腾讯地图 Key' : '高德地图 Key',
                  child: TextField(
                    controller: _keyCtrl,
                    decoration: InputDecoration(
                      hintText: _provider == 'qq' ? '请输入腾讯地图 API Key' : '请输入高德地图 API Key',
                    ),
                  ),
                ),
              ),
            if (_provider != 'none') const SizedBox(height: Spacing.lg),

            // Test connection
            if (_provider != 'none')
              PrimaryButton(
                label: _testing ? '测试中…' : '测试连接',
                loading: _testing,
                expanded: true,
                icon: Icons.wifi_find_rounded,
                onPressed: _testing ? null : _testConnection,
              ),
            if (_hasTested && _provider != 'none') ...[
              const SizedBox(height: Spacing.md),
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: _testResult ? SemanticColors.income.withValues(alpha: 0.1) : SemanticColors.expense.withValues(alpha: 0.1),
                  borderRadius: AppRadius.input,
                ),
                child: Row(
                  children: [
                    Icon(_testResult ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: _testResult ? SemanticColors.income : SemanticColors.expense, size: 20),
                    const SizedBox(width: Spacing.sm),
                    Text(_testResult ? '连接成功！' : '连接失败，请检查 Key 是否正确',
                        style: TextStyle(fontWeight: FontWeight.w600, color: _testResult ? SemanticColors.income : SemanticColors.expense)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Spacing.xxl),

            // Save button
            PrimaryButton(
              label: '保存配置',
              expanded: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderOption {
  const _ProviderOption(this.id, this.name, this.desc);
  final String id;
  final String name;
  final String desc;
}