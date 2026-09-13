/// 只读分享页（V2.6 /s/<token>，Web 顶层匿名路由，无桌面宽度要求）：
/// 行程=封面/时间线；账本=成员/账单/近 10 结算。零写控件。
/// 口令缺失/错误 → need_pass / bad_pass 分支。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/providers.dart';
import '../../../data/sync/sync_account.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/copy_tokens.dart';
import '../../../theme/tokens.dart';

class ShareViewScreen extends ConsumerStatefulWidget {
  const ShareViewScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ShareViewScreen> createState() => _ShareViewScreenState();
}

class _ShareViewState {
  bool loaded = false;
  bool needPass = false;
  String? error;
  Map<String, dynamic>? data;
}

class _ShareViewScreenState extends ConsumerState<ShareViewScreen> {
  final _ShareViewState _st = _ShareViewState();
  final _passCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(null);
  }

  @override
  void dispose() {
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _load(String? pass) async {
    final client = ref.read(cloudClientProvider);
    if (client == null) {
      setState(() {
        _st.loaded = true;
        _st.error = copy('sync.status.unconfigured');
      });
      return;
    }
    final shareSvc = ShareService(client);
    try {
      final res = await shareSvc.getShareSnapshot(widget.token, pass);
      final err = res['error'] as String?;
      // need_pass / bad_pass 都停留在口令输入页（bad_pass 显示错误后可重试，
      // 此前误落到错误页且无输入框 → 口令只有一次机会、输错就卡死）。
      _st.needPass = err == 'need_pass' || err == 'bad_pass';
      _st.error = switch (err) {
        'not_found' => copy('share.notFound'),
        'bad_pass' => copy('share.passBad'),
        'need_pass' => null,
        _ => res['ok'] == true ? null : copy('share.notFound'),
      };
      _st.data = res['ok'] == true ? (res['data'] as Map).cast<String, dynamic>() : null;
      _st.loaded = true;
    } catch (_) {
      _st.loaded = true;
      _st.error = copy('cloud.errNetwork');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: !_st.loaded
          ? const Center(child: CircularProgressIndicator())
          : _st.needPass
              ? _passPrompt(scheme)
              : _st.error != null
                  ? _errorView(scheme)
                  : _snapshotView(scheme),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Text(
          copy('share.pageFooter'),
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppFontSizes.caption),
        ),
      ),
    );
  }

  Widget _passPrompt(ColorScheme scheme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, color: scheme.primary),
            const SizedBox(height: Spacing.md),
            Text(copy('share.passTitle')),
            const SizedBox(height: Spacing.md),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _passCtl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
            if (_st.error != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(_st.error!, style: TextStyle(color: scheme.error, fontSize: AppFontSizes.caption)),
            ],
            const SizedBox(height: Spacing.lg),
            FilledButton(onPressed: () => _load(_passCtl.text), child: const Text('验证')),
          ]),
        ),
      );

  Widget _errorView(ColorScheme scheme) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.waves_rounded, size: 48, color: scheme.outline),
          const SizedBox(height: Spacing.md),
          Text(_st.error ?? ''),
        ]),
      );

  Widget _snapshotView(ColorScheme scheme) {
    final data = _st.data!;
    final kind = data['kind'] as String;
    final inner = (data['data'] as Map).cast<String, dynamic>();
    return ListView(
      padding: const EdgeInsets.all(Spacing.xl),
      children: [
        if (kind == 'trip') ..._tripCards(inner, scheme) else ..._groupCards(inner, scheme),
      ],
    );
  }

  List<Widget> _tripCards(Map<String, dynamic> inner, ColorScheme scheme) {
    final trip = (inner['trip'] as Map).cast<String, dynamic>();
    final items = (inner['items'] as List?)?.cast<Map>() ?? const [];
    final fmt = DateFormat('M月d日');
    String dayLabel(int epochDay) => fmt.format(
        DateTime.fromMillisecondsSinceEpoch(epochDay * 86400000, isUtc: true));
    return [
      Text('${trip['emoji'] ?? '✈️'} ${trip['name'] ?? ''}',
          style: Theme.of(context).textTheme.headlineSmall),
      if ((trip['destination'] as String?)?.isNotEmpty == true)
        Text(trip['destination'] as String,
            style: TextStyle(color: scheme.onSurfaceVariant)),
      if (trip['groupName'] != null)
        Text('与「${trip['groupName']}」同行',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppFontSizes.caption)),
      const SizedBox(height: Spacing.lg),
      for (final raw in items)
        Card(
          margin: const EdgeInsets.only(bottom: Spacing.md),
          child: ListTile(
            title: Text(raw['name'] as String? ?? ''),
            subtitle: Text([
              raw['dateEpochDay'] != null ? dayLabel(raw['dateEpochDay'] as int) : '',
              raw['address'] ?? '',
            ].where((s) => (s as String).isNotEmpty).join(' · ')),
            trailing: raw['costCents'] != null
                ? Text('¥${((raw['costCents'] as num).toInt() / 100).toStringAsFixed(0)}')
                : null,
          ),
        ),
    ];
  }

  List<Widget> _groupCards(Map<String, dynamic> inner, ColorScheme scheme) {
    final group = (inner['group'] as Map).cast<String, dynamic>();
    final members = (inner['members'] as List?)?.cast<Map>() ?? const [];
    final expenses = (inner['expenses'] as List?)?.cast<Map>() ?? const [];
    final settlements = (inner['settlements'] as List?)?.cast<Map>() ?? const [];
    return [
      Text('${group['icon'] ?? ''} ${group['name'] ?? ''}',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: Spacing.md),
      Text('成员：${members.map((m) => m['name']).join('、')}',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppFontSizes.caption)),
      const SizedBox(height: Spacing.lg),
      Text('账单明细', style: Theme.of(context).textTheme.titleMedium),
      for (final e in expenses)
        Card(
          margin: const EdgeInsets.only(bottom: Spacing.sm),
          child: ListTile(
            dense: true,
            title: Text(e['title'] as String? ?? ''),
            subtitle: Text(e['categoryKey'] as String? ?? ''),
            trailing: Text(
              '${((e['amountCents'] as num?)?.toInt() ?? 0) < 0 ? '-' : ''}¥'
              '${(((e['amountCents'] as num?)?.toInt() ?? 0).abs() / 100).toStringAsFixed(2)}',
              style: TextStyle(color: ((e['amountCents'] as num?)?.toInt() ?? 0) < 0
                  ? SemanticColors.income
                  : scheme.onSurface),
            ),
          ),
        ),
      if (settlements.isNotEmpty) ...[
        const SizedBox(height: Spacing.md),
        Text('近期结算', style: Theme.of(context).textTheme.titleMedium),
        for (final s in settlements)
          Card(
            margin: const EdgeInsets.only(bottom: Spacing.sm),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Text('第 ${s['roundNo']} 轮 · ${(s['transfersJson'] as String?) ?? '[]'}',
                  style: const TextStyle(fontSize: AppFontSizes.caption)),
            ),
          ),
      ],
    ];
  }
}
