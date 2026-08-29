/// 桌面「与手机同步」中心：全量/单团备份文件互传 + 二维码 + 口令码。
/// 无后端；浏览器受限能力（局域网）不出现。
library;
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/providers.dart' show tripsRepoProvider;
import '../../../export/backup_format.dart';
import '../../../export/share_helper.dart';
import '../../../theme/tokens.dart';
import '../../ledger/ledger_providers.dart';
import 'sync_code.dart';

/// 打开同步中心（桌面态专用）。
Future<void> showSyncCenter(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _SyncCenterDialog(),
  );
}

class _SyncCenterDialog extends ConsumerStatefulWidget {
  const _SyncCenterDialog();

  @override
  ConsumerState<_SyncCenterDialog> createState() => _SyncCenterDialogState();
}

class _SyncCenterDialogState extends ConsumerState<_SyncCenterDialog> {
  int _tab = 0; // 0 备份文件 / 1 二维码 / 2 口令码
  bool _busy = false;

  // 二维码
  String _code = '';
  List<String> _chunks = const [];
  int _page = 0;
  String _qrNote = '';

  // 口令码粘贴
  final _pasteCtl = TextEditingController();
  String _pasteMsg = '';

  @override
  void dispose() {
    _pasteCtl.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(String label, Future<String> Function() job) async {
    setState(() => _busy = true);
    try {
      final msg = await job();
      if (mounted) _toast(msg);
    } catch (e) {
      if (mounted) _toast('$label失败：${e.toString()}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- 备份文件 ----------
  Future<void> _exportFull() => _run('导出全量备份', () async {
        final (bytes, name) = await exportFullBackup(ref);
        await shareFile(bytes, name, 'application/x-travel-assistant-full');
        return '已导出 $name（请在浏览器下载/分享到手机）';
      });

  Future<void> _importFile() => _run('导入', () async {
        final result = await FilePicker.pickFiles(withData: true);
        if (result.isEmpty) throw StateError('未选择文件');
        final bytes = await result.single.readAsBytes();
        if (bytes.isEmpty) throw StateError('读取文件失败');
        if (looksLikeBackupEnvelope(bytes, acceptedMagics: [kFullBackupMagic])) {
          final replace = await _askMergeOrReplace();
          return importFullBackupFile(ref, bytes, replace: replace);
        }
        if (looksLikeBackupEnvelope(bytes, acceptedMagics: [kGroupBackupMagic])) {
          return importGroupBackupFile(ref, bytes);
        }
        if (looksLikeBackupEnvelope(bytes, acceptedMagics: [kTripBackupMagic])) {
          final r = await ref.read(tripsRepoProvider).importTripBackupBytes(bytes);
          return '行程「${r.trip}」导入成功（含安排/相册/清单）';
        }
        // 兼容旧 JSON 文本备份
        return importGroupFromText(ref, utf8.decode(bytes));
      });

  Future<bool> _askMergeOrReplace() async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导入全量备份'),
            content: const Text('选择「合并」会把数据按最新时间合并进本机；选择「覆盖恢复」会先清空本机全部数据再导入。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('合并')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                    foregroundColor: Theme.of(ctx).colorScheme.onError),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('覆盖恢复'),
              ),
            ],
          ),
        )) ??
        false;
  }

  // ---------- 二维码 ----------
  Future<void> _buildQr() async {
    final gid = ref.read(activeGroupIdProvider).value;
    if (gid == null) {
      _toast('请先到「账本」选择一个旅行团');
      return;
    }
    await _run('生成二维码', () async {
      final json = await exportGroupSnapshot(ref, gid);
      final code = encodeSyncCode(json);
      final chunks = chunkSyncCode(code);
      if (mounted) {
        setState(() {
          _code = code;
          _chunks = chunks;
          _page = 0;
          _qrNote = '共 ${chunks.length} 页 · 手机「扫码同步」逐页扫描；扫描完成后自动合并';
        });
      }
      return '已生成 ${chunks.length} 页二维码';
    });
  }

  Future<void> _copyCode() async {
    if (_code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _code));
    _toast('同步码已复制');
  }

  Future<void> _downloadCode() async {
    if (_code.isEmpty) return;
    await shareFile(utf8.encode(_code), 'sync_code.tsync', 'text/plain');
  }

  // ---------- 口令码 ----------
  Future<void> _pasteImport() async {
    final text = _pasteCtl.text.trim();
    if (text.isEmpty) {
      _toast('请粘贴手机端导出的同步码');
      return;
    }
    await _run('导入', () async {
      final json = decodeSyncCode(text);
      final obj = jsonDecode(json);
      if (obj is Map && obj['group'] is Map) {
        return mergeGroupSnapshot(ref, json);
      }
      if (obj is Map && obj['trip'] is Map) {
        final root = obj.cast<String, dynamic>();
        final r = await ref.read(tripsRepoProvider).importTripBackupMap(root);
        return '行程「${r.trip}」导入成功';
      }
      throw StateError('无法识别的同步内容');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: scheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xl, Spacing.lg, Spacing.sm),
              child: Row(
                children: [
                  const Text('与手机同步', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('备份文件'), icon: Icon(Icons.save_alt_rounded, size: 16)),
                  ButtonSegment(value: 1, label: Text('二维码'), icon: Icon(Icons.qr_code_2_rounded, size: 16)),
                  ButtonSegment(value: 2, label: Text('口令码'), icon: Icon(Icons.keyboard_rounded, size: 16)),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _tab = v.first),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Expanded(
              child: switch (_tab) {
                0 => _buildFiles(scheme),
                1 => _buildQrTab(scheme),
                _ => _buildCodeTab(scheme),
              },
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(
                '手机端操作：账本 → 团管理 → 导入备份 / 扫码同步；行程 → 更多 → 导入备份。全链路离线、无网络依赖。',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiles(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      children: [
        _ActionCard(
          icon: Icons.upload_file_rounded,
          color: scheme.primary,
          title: '导出全量备份（全部团 + 全部行程）',
          subtitle: '下载 .tavA 文件，通过微信/网盘/数据线发给手机后导入',
          busy: _busy,
          onTap: _exportFull,
        ),
        const SizedBox(height: Spacing.md),
        _ActionCard(
          icon: Icons.download_rounded,
          color: scheme.tertiary,
          title: '导入备份文件',
          subtitle: '支持全量 .tavA、单团 .tav、单行程 .tat（合并 / 覆盖可选）',
          busy: _busy,
          onTap: _importFile,
        ),
      ],
    );
  }

  Widget _buildQrTab(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      children: [
        _ActionCard(
          icon: Icons.qr_code_2_rounded,
          color: scheme.primary,
          title: '生成二维码（当前团 + 全部行程快照）',
          subtitle: '数据较多时自动分页；手机「扫码同步」逐页扫描',
          busy: _busy,
          onTap: _buildQr,
        ),
        const SizedBox(height: Spacing.md),
        if (_chunks.isNotEmpty) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: _chunks[_page],
                    version: QrVersions.auto,
                    size: 220,
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text('第 ${_page + 1} / ${_chunks.length} 页',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('$_qrNote', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              IconButton(
                onPressed: _page < _chunks.length - 1 ? () => setState(() => _page++) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: _copyCode,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('复制完整同步码（发给手机粘贴导入）'),
          ),
          TextButton.icon(
            onPressed: _downloadCode,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('下载同步码文本'),
          ),
        ],
      ],
    );
  }

  Widget _buildCodeTab(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      children: [
        Text('手机导出 → 本机粘贴导入',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
        const SizedBox(height: Spacing.xs),
        Text('手机端在账本/行程的「导出同步码」复制内容，粘贴到下方；本端同步码也可复制后发到手机端粘贴。',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: _pasteCtl,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '在此粘贴同步码…',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _pasteImport,
                icon: const Icon(Icons.download_done_rounded, size: 18),
                label: const Text('粘贴导入'),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportCurrentCode,
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('导出当前团同步码'),
              ),
            ),
          ],
        ),
        if (_pasteMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.md),
            child: Text(_pasteMsg, style: TextStyle(fontSize: 12, color: scheme.primary)),
          ),
      ],
    );
  }

  Future<void> _exportCurrentCode() async {
    final gid = ref.read(activeGroupIdProvider).value;
    if (gid == null) {
      _toast('请先到「账本」选择一个旅行团');
      return;
    }
    await _run('导出同步码', () async {
      final json = await exportGroupSnapshot(ref, gid);
      final code = encodeSyncCode(json);
      if (mounted) {
        setState(() {
          _code = code;
          _chunks = [];
          _qrNote = '';
        });
      }
      await Clipboard.setData(ClipboardData(text: code));
      return '已复制同步码，粘贴给手机端导入';
    });
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.button,
      child: InkWell(
        borderRadius: AppRadius.button,
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: AppRadius.button,
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
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
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
