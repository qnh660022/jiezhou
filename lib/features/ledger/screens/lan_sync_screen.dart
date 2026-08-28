import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../lan_sync_service.dart';
import '../ledger_providers.dart';

/// 局域网离线协作记账：同 Wi-Fi 口令快照同步。
/// 「发起」= 主机（出示口令+IP，等对方连接）；「加入」= 输入口令连接，可双向收发。
class LanSyncScreen extends ConsumerStatefulWidget {
  const LanSyncScreen({super.key});

  @override
  ConsumerState<LanSyncScreen> createState() => _LanSyncScreenState();
}

class _LanSyncScreenState extends ConsumerState<LanSyncScreen> {
  final LanSyncManager _mgr = LanSyncManager();
  String _mode = ''; // '' | 'host' | 'join'
  bool _starting = false;
  String? _hostCode;
  int? _hostPort;
  List<String> _hostIPs = const [];
  final List<String> _hostLogs = [];

  LanPeer? _peer;
  bool _connecting = false;
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _ipCtrl = TextEditingController();
  String? _peerStatus;

  String? get _gid => ref.read(activeGroupIdProvider).value;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _ipCtrl.dispose();
    _mgr.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _startHost() async {
    final gid = _gid;
    if (gid == null) {
      _toast('请先到「账本」新建/切换一个当前旅行团');
      return;
    }
    setState(() {
      _starting = true;
      _mode = 'host';
    });
    try {
      final (code, port, ips) = await _mgr.startHost(
        snapshotProvider: () async {
          final g = ref.read(activeGroupIdProvider).value;
          if (g == null) return '{}';
          return exportGroupSnapshot(ref, g);
        },
        snapshotMerger: (raw) async {
          final summary = await mergeGroupSnapshot(ref, raw);
          if (mounted) {
            setState(() => _hostLogs.insert(0, summary));
          }
          return summary;
        },
      );
      if (!mounted) return;
      setState(() {
        _hostCode = code;
        _hostPort = port;
        _hostIPs = ips;
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _mode = '';
      });
      _toast('启动失败：${e.toString()}');
    }
  }

  Future<void> _connectJoin() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      _toast('请输入对方提供的 6 位口令');
      return;
    }
    setState(() => _connecting = true);
    try {
      final peer = await _mgr.discoverHost(
        code,
        manualIp: _ipCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _peer = peer;
        _mode = 'join';
        _peerStatus = '已连接 ${peer.ip}:${peer.port}';
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _connecting = false);
      _toast('${e.toString()}');
    }
  }

  Future<void> _pull() async {
    final peer = _peer;
    if (peer == null) return;
    setState(() => _peerStatus = '拉取中…');
    try {
      final json = await _mgr.pullSnapshot(peer);
      final summary = await mergeGroupSnapshot(ref, json);
      if (!mounted) return;
      setState(() => _peerStatus = '拉取成功 · $summary');
    } catch (e) {
      if (!mounted) return;
      setState(() => _peerStatus = '拉取失败');
      _toast('拉取失败：${e.toString()}');
    }
  }

  Future<void> _push() async {
    final peer = _peer;
    final gid = _gid;
    if (peer == null) return;
    if (gid == null) {
      _toast('本地还没有当前旅行团可推送');
      return;
    }
    setState(() => _peerStatus = '推送中…');
    try {
      final json = await exportGroupSnapshot(ref, gid);
      final summary = await _mgr.pushSnapshot(peer, json);
      if (!mounted) return;
      setState(() => _peerStatus = '推送成功 · $summary');
    } catch (e) {
      if (!mounted) return;
      setState(() => _peerStatus = '推送失败');
      _toast('推送失败：${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlassAppBar(title: '局域网同步'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxxl),
          children: [
            Text('同 Wi-Fi · 纯离线共享记账',
                style: TextStyle(fontSize: AppFontSizes.bodyLarge, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('两台手机连同一 Wi-Fi，一个「发起」、一个输口令「加入」，就能双向收发当前团的账本；全链路不走网络，断网也能用。',
                style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.xl),

            if (_mode.isEmpty) _buildModePicker(scheme),
            if (_mode == 'host') _buildHostPanel(scheme),
            if (_mode == 'join') _buildJoinPanel(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildModePicker(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeCard(
          icon: Icons.wifi_tethering_rounded,
          color: scheme.primary,
          title: '发起同步（主机）',
          subtitle: '生成 6 位口令与本机 IP，等对方输口令加入',
          onTap: _startHost,
          enabled: !_starting,
          busy: _starting,
        ),
        const SizedBox(height: Spacing.lg),
        _ModeCard(
          icon: Icons.sensors_rounded,
          color: scheme.tertiary,
          title: '加入同步（口令）',
          subtitle: '输入对方口令即可连接；自动发现失败可手动填 IP',
          onTap: () => setState(() => _mode = 'join'),
          enabled: true,
        ),
      ],
    );
  }

  Widget _buildHostPanel(ColorScheme scheme) {
    final groupName = ref.watch(activeGroupProvider).value?.name ?? '未选择团';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hostCode == null)
          Column(children: const [SkeletonBox(height: 120, radius: AppRadius.cardValue)])
        else ...[
          _InfoCard(
            code: _hostCode!,
            ips: _hostIPs,
            port: _hostPort!,
            groupName: groupName,
            scheme: scheme,
          ),
          const SizedBox(height: Spacing.md),
          Text('对方加入后，在本页可看到合并日志。也可让对方在本机用「加入口令」连接后选择拉取/推送。',
              style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
          if (_hostLogs.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            Text('合并日志', style: TextStyle(fontSize: AppFontSizes.body, fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.xs),
            for (final line in _hostLogs.take(20))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('· $line',
                    style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
              ),
          ],
          const SizedBox(height: Spacing.lg),
          PrimaryButton(
            label: '结束同步',
            expanded: true,
            onPressed: () {
              _mgr.dispose();
              setState(() {
                _mode = '';
                _hostCode = null;
                _hostLogs.clear();
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildJoinPanel(ColorScheme scheme) {
    final peer = _peer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (peer == null) ...[
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: '6 位口令'),
          ),
          TextField(
            controller: _ipCtrl,
            decoration: const InputDecoration(
              labelText: '主机 IP（可选）',
              helperText: '自动发现失败时填写主机屏幕显示的 IP，如 192.168.1.5',
            ),
          ),
          const SizedBox(height: Spacing.md),
          PrimaryButton(
            label: _connecting ? '连接中…' : '连接',
            expanded: true,
            onPressed: _connecting ? null : _connectJoin,
          ),
          const SizedBox(height: Spacing.xs),
          TextButton(
            onPressed: () => setState(() => _mode = ''),
            child: const Text('返回'),
          ),
        ] else ...[
          _PeerCard(scheme: scheme, status: _peerStatus ?? ''),
          const SizedBox(height: Spacing.xl),
          Row(children: [
            Expanded(
              child: PrimaryButton(
                label: '拉取对方账本',
                expanded: true,
                onPressed: _pull,
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: OutlinedButton(
                onPressed: _push,
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                ),
                child: const Text('推送我的账本'),
              ),
            ),
          ]),
          const SizedBox(height: Spacing.sm),
          Text('双方已连接的团 id 相同才视为「同一本账」；首次拉取时对方整个团会按同 id 并入本机。',
              style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
    this.busy = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.cardValue),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cardValue),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.buttonValue),
                ),
                child: busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.code,
    required this.ips,
    required this.port,
    required this.groupName,
    required this.scheme,
  });

  final String code;
  final List<String> ips;
  final int port;
  final String groupName;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.cardValue),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('同步口令', style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Row(children: [
            Text(code,
                style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 6, color: scheme.primary)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('口令已复制')));
              },
            ),
          ]),
          const SizedBox(height: Spacing.sm),
          Text('当前团：$groupName  ·  端口 $port',
              style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.xs),
          Text('本机 IP（自动发现失败时让对面手动填）：${ips.join('、')}',
              style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.sm),
          Text('让另一台手机在「加入同步」里输入以上口令即可连接。',
              style: TextStyle(fontSize: AppFontSizes.caption, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PeerCard extends StatelessWidget {
  const _PeerCard({required this.scheme, required this.status});
  final ColorScheme scheme;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.cardValue),
      ),
      child: Row(children: [
        Icon(Icons.sensors_rounded, color: scheme.tertiary),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Text(status,
              style: TextStyle(
                  fontSize: AppFontSizes.caption, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}