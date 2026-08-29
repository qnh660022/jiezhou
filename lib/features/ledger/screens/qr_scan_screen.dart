// 📷 扫码 / 口令同步导入（配合桌面「与手机同步」中心使用）。
// 拍照或相册选二维码逐页扫描（zxing2 纯 Dart 解码），或直接粘贴同步码。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:zxing2/qrcode.dart';

import '../../../data/providers.dart' show tripsRepoProvider;
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/tokens.dart';
import '../../desktop/sync/sync_code.dart';
import '../ledger_providers.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _pasteCtl = TextEditingController();
  bool _busy = false;
  String _status = '';
  final List<String> _rawChunks = [];
  int _total = 0;

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

  /// 图片字节 → 二维码文本（zxing2 低层 API）。
  Future<String?> _decodeImageBytes(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final conv = decoded.convert(format: img.Format.uint8, numChannels: 4);
    final rgba = conv.getBytes(order: img.ChannelOrder.rgba);
    final w = decoded.width, h = decoded.height;
    final pixels = Int32List(w * h);
    var o = 0;
    for (var i = 0; i < pixels.length; i++) {
      final r = rgba[o++], g = rgba[o++], b = rgba[o++], a = rgba[o++];
      pixels[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }
    final src = RGBLuminanceSource(w, h, pixels);
    final bitmap = BinaryBitmap(HybridBinarizer(src));
    final result = QRCodeReader().decode(bitmap, hints: DecodeHints());
    return result.text;
  }

  Future<void> _scan() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('拍照识别'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    setState(() => _busy = true);
    try {
      final x = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 90);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final text = await _decodeImageBytes(bytes);
      if (text == null) throw StateError('未能识别二维码，请对准重拍');
      await _acceptChunk(text);
    } catch (e) {
      if (mounted) setState(() => _status = '识别失败：${e.toString()}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptChunk(String text) async {
    final parsed = parseChunk(text);
    if (parsed != null) {
      final (total, idx, _) = parsed;
      if (!_rawChunks.any((c) => parseChunk(c)?.$2 == idx)) {
        setState(() {
          _total = total;
          _rawChunks.add(text);
        });
      }
      if (_rawChunks.length >= total) {
        final code = combineChunks(_rawChunks);
        await _importCode(code);
      } else {
        if (mounted) {
          setState(() => _status = '已扫 ${_rawChunks.length}/$total 页，请继续扫描下一张…');
        }
      }
      return;
    }
    await _importCode(text);
  }

  Future<void> _importCode(String code) async {
    final json = decodeSyncCode(code);
    final obj = jsonDecode(json);
    String msg;
    if (obj is Map && obj['group'] is Map) {
      msg = await mergeGroupSnapshot(ref, json);
    } else if (obj is Map && obj['trip'] is Map) {
      final r =
          await ref.read(tripsRepoProvider).importTripBackupMap(obj.cast<String, dynamic>());
      msg = '行程「${r.trip}」导入成功（含安排/相册/清单）';
    } else {
      throw StateError('无法识别的同步内容');
    }
    if (mounted) {
      setState(() {
        _status = msg;
        _rawChunks.clear();
        _total = 0;
      });
      _toast(msg);
    }
  }

  Future<void> _pasteImport() async {
    final text = _pasteCtl.text.trim();
    if (text.isEmpty) {
      _toast('请粘贴同步码');
      return;
    }
    setState(() => _busy = true);
    try {
      await _importCode(text);
    } catch (e) {
      if (mounted) setState(() => _status = '导入失败：${e.toString()}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _rawChunks.clear();
      _total = 0;
      _status = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlassAppBar(title: '扫码同步'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxxl),
          children: [
            Text('从电脑端「与手机同步」生成二维码/同步码，在这里导入。',
                style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.xl),
            PrimaryButton(
              label: _busy ? '识别中…' : '扫描二维码',
              expanded: true,
              onPressed: _busy ? null : _scan,
            ),
            if (_total > 0) ...[
              const SizedBox(height: Spacing.md),
              Text('已扫 ${_rawChunks.length}/$_total 页',
                  style: TextStyle(fontSize: AppFontSizes.body, fontWeight: FontWeight.w700, color: scheme.primary)),
              TextButton(onPressed: _reset, child: const Text('重新开始')),
            ],
            if (_status.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              Text(_status,
                  style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: Spacing.xxl),
            const Divider(),
            Text('或粘贴同步码',
                style: TextStyle(fontSize: AppFontSizes.body, fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: _pasteCtl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '粘贴电脑端复制的同步码…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: Spacing.md),
            PrimaryButton(
              label: '粘贴导入',
              expanded: true,
              onPressed: _busy ? null : _pasteImport,
            ),
            const SizedBox(height: Spacing.md),
            TextButton.icon(
              onPressed: () async {
                final gid = ref.read(activeGroupIdProvider).value;
                if (gid == null) {
                  _toast('请先到「账本」选择一个旅行团');
                  return;
                }
                try {
                  final json = await exportGroupSnapshot(ref, gid);
                  final code = encodeSyncCode(json);
                  await Clipboard.setData(ClipboardData(text: code));
                  _toast('已复制同步码，发送给电脑端「口令码」粘贴导入');
                } catch (e) {
                  _toast('导出失败：${e.toString()}');
                }
              },
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('导出当前团同步码（复制）'),
            ),
          ],
        ),
      ),
    );
  }
}
