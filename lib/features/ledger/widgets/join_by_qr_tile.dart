import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../screens/qr_scan_screen.dart';

/// V2.8.1 S7：统一扫码入口 —— 团管理 / 行程首页 / 分享中心三处共用同一组件。
///
/// [compact] = AppBar 图标形态；否则渲染为整行 ListTile。
class JoinByQrTile extends StatelessWidget {
  const JoinByQrTile({super.key, this.compact = false, this.subtitle});

  final bool compact;
  final String? subtitle;

  Future<void> _open(BuildContext context) {
    return Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => const QrScanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    if (compact) {
      return IconButton(
        tooltip: '扫码/口令同步（与电脑端互导）',
        onPressed: () => _open(context),
        icon: const Icon(Icons.qr_code_scanner_rounded),
      );
    }
    return ListTile(
      leading: Icon(Icons.qr_code_scanner_rounded,
          color: Theme.of(context).colorScheme.primary),
      title: const Text('扫码/口令同步',
          style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
          subtitle ?? '与电脑端互导数据（二维码或口令），全程局域网直连',
          style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () => _open(context),
    );
  }
}
