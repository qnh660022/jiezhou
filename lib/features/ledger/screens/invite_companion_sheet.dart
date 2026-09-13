/// 「邀请旅伴」sheet（owner 端，V2.6 §3.13.1）：展示 6 位码 + 链接 + 重新生成。
/// 入口在成员页顶部（成员管理 AppBar 下方）。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/sync_account.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/sheet.dart' show SheetSurface;
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
    } catch (_) {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 全局 bottomSheet 主题为透明背景：必须包不透明面板（否则与底层页面重叠）
    return SheetSurface(
      child: SafeArea(
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
            Text('链接：/invite?c=$_code',
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: AppFontSizes.caption)),
            const SizedBox(height: Spacing.lg),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilledButton.tonal(
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
      ),
    );
  }
}
