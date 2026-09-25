/// 「邀请旅伴」sheet（owner 端，V2.6 §3.13.1）：展示 6 位码 + 完整链接 + 复制/分享。
/// 入口在成员页顶部（成员管理 AppBar 下方）。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/sync/sync_account.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/app_meta.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../theme/tokens.dart';

class InviteCompanionSheet extends ConsumerStatefulWidget {
  const InviteCompanionSheet({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<InviteCompanionSheet> createState() => _InviteCompanionSheetState();
}

class _InviteCompanionSheetState extends ConsumerState<InviteCompanionSheet> {
  String? _code;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ensure();
  }

  Future<void> _ensure() async {
    final svc = ref.read(collabServiceProvider);
    if (svc == null) {
      setState(() {
        _busy = false;
        _error = copy('sync.status.unconfigured');
      });
      return;
    }
    try {
      final code = await svc.ensureInvite(widget.groupId);
      setState(() {
        _code = code;
        _busy = false;
      });
    } catch (e, s) {
      // V2.9.0:原始异常只进调试日志。
      debugPrint('ensureInvite failed: $e\n$s');
      setState(() {
        _busy = false;
        _error = copy('cloud.errGeneric');
      });
    }
  }

  Future<void> _regen() async {
    final svc = ref.read(collabServiceProvider);
    if (svc == null) return;
    setState(() => _busy = true);
    try {
      final code = await svc.regenerateInviteCode(widget.groupId);
      setState(() {
        _code = code;
        _busy = false;
      });
    } on CloudAccountException {
      setState(() {
        _busy = false;
        _error = copy('share.ownerOnly');
      });
    }
  }

  /// V2.9.0:复制邀请链接并给轻提示（不再只展示相对路径）。
  void _copyLink(String url) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: url));
    showAppSnackBar(context, '邀请链接已复制');
  }

  /// V2.9.0:调起系统分享面板（share_plus），失败只进日志并轻提示。
  Future<void> _shareLink(String url) async {
    HapticFeedback.selectionClick();
    try {
      await SharePlus.instance.share(ShareParams(
        title: '来芥舟一起记账',
        text: '邀请你加入我的账本，邀请码 $_code，链接：$url',
      ));
      if (mounted) showAppSnackBar(context, '已调起分享');
    } catch (e, s) {
      debugPrint('share invite link failed: $e\n$s');
      if (mounted) {
        showAppSnackBar(context, '分享没有调起来，请复制链接发给对方', tone: SnackTone.destructive);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // V2.9.0:本组件改由 showDraggableSheet 承载（SheetContainer 自带玻璃底面），
    // 内层不再包 SheetSurface 防双重面板。
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(copy('share.invite'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.lg),
          if (_busy)
            const Padding(
                padding: EdgeInsets.all(Spacing.lg),
                child: CircularProgressIndicator()),
          if (!_busy && _code != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xl, vertical: Spacing.lg),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(Spacing.lg),
              ),
              child: Text(_code!,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(letterSpacing: 8, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: Spacing.md),
            // V2.9.0:展示完整可点的深链（与分享中心同源 inviteLinkUrl），不再是相对路径。
            Text('链接：${inviteLinkUrl(_code!)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: AppFontSizes.caption)),
            const SizedBox(height: Spacing.lg),
            Row(children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _copyLink(inviteLinkUrl(_code!)),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('复制链接'),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareLink(inviteLinkUrl(_code!)),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('分享'),
                ),
              ),
            ]),
            const SizedBox(height: Spacing.md),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('完成')),
              const SizedBox(width: Spacing.md),
              OutlinedButton(onPressed: _regen, child: Text(copy('share.inviteRegen'))),
            ]),
          ],
          if (!_busy && _error != null)
            Text(_error!, style: TextStyle(color: scheme.error, fontSize: AppFontSizes.caption)),
        ]),
      ),
    );
  }
}
