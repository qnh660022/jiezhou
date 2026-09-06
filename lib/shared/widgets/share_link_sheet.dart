/// 只读分享链接创建面板（行程 / 账本通用）：
/// - 语义：拿到链接的任何人**无需登录**即可在 Web 端查看只读快照
///   （行程=封面/时间线；账本=成员/账单/近 10 笔结算），不能写；
///   口令为 4 位数字，可选；链接可随时在「同步中心 → 分享链接」撤销；
/// - 前提：实体已开启云同步且至少成功上云一次（快照读云端表）；
/// - 成功后展示完整 URL + 复制按钮。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/sync_account.dart';
import '../../data/sync/sync_control_providers.dart';
import '../app_meta.dart';
import '../copy_tokens.dart';
import '../../theme/tokens.dart';

/// 弹出创建面板。entityType: 'trip' | 'group'。
Future<void> showShareLinkSheet(BuildContext context,
    {required String entityType, required String entityId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ShareLinkSheet(entityType: entityType, entityId: entityId),
  );
}

class _ShareLinkSheet extends ConsumerStatefulWidget {
  const _ShareLinkSheet({required this.entityType, required this.entityId});

  final String entityType;
  final String entityId;

  @override
  ConsumerState<_ShareLinkSheet> createState() => _ShareLinkSheetState();
}

class _ShareLinkSheetState extends ConsumerState<_ShareLinkSheet> {
  bool _withPass = false;
  final _passCtl = TextEditingController();
  bool _busy = false;
  String? _url;
  String? _error;

  @override
  void dispose() {
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final svc = ref.read(shareServiceProvider);
    if (svc == null) {
      setState(() => _error = copy('sync.status.signedOut'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await svc.createShareLink(
        entityType: widget.entityType,
        entityId: widget.entityId,
        pass: _withPass ? _passCtl.text.trim() : null,
      );
      setState(() {
        _url = shareLinkUrl(token);
        _busy = false;
      });
    } on CloudAccountException catch (e) {
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          'not_found' => '行程/账本尚未上云：请先在 同步中心 开启它的云同步并完成一次同步',
          'forbidden' || 'owner_only' => copy('share.ownerOnly'),
          'bad_pass' || 'need_pass' => '口令格式不正确（4 位数字）',
          _ => copy('cloud.errGeneric'),
        };
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = copy('cloud.errNetwork');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Spacing.lg,
          right: Spacing.lg,
          top: Spacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.lg,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment:
            CrossAxisAlignment.start, children: [
          Text('只读分享链接', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          Text(
            '任何人无需登录即可打开链接查看只读内容'
            '${widget.entityType == 'trip' ? '（行程封面与时间线）' : '（成员、账单与近期结算）'}，'
            '无法修改。可随时在 同步中心 → 分享链接 撤销。',
            style: TextStyle(
                color: scheme.onSurfaceVariant, fontSize: AppFontSizes.caption),
          ),
          const SizedBox(height: Spacing.lg),
          if (_url == null) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('口令保护（4 位数字）'),
              subtitle: Text('打开链接时需输入口令',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: AppFontSizes.caption)),
              value: _withPass,
              onChanged: _busy ? null : (v) => setState(() => _withPass = v),
            ),
            if (_withPass)
              TextField(
                controller: _passCtl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '口令'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.sm),
                child: Text(_error!,
                    style:
                        TextStyle(color: scheme.error, fontSize: AppFontSizes.caption)),
              ),
            const SizedBox(height: Spacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _create,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.link_rounded),
                label: Text(_busy ? '创建中…' : '生成链接'),
              ),
            ),
          ] else ...[
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: SelectableText(_url!,
                    style: const TextStyle(fontSize: AppFontSizes.body)),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _url!));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('链接已复制')));
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('复制链接'),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('完成'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
