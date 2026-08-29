// 📷 扫码 / 口令同步导入（配合桌面「与手机同步」中心使用）。
// 实时取景自动扫描（camera + zxing2 纯 Dart 解码，离线可用，无需 Google 服务），
// 支持逐页自动连扫（分散在多个二维码里的同步码块可依次扫入，全部集齐后自动合并导入），
// 拍照 / 相册作为兜底识别方式，按钮全部内嵌页面（不再用底部弹层，避免被底栏遮挡）。
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zxing2/qrcode.dart' show QRCodeReader;
import 'package:zxing2/zxing2.dart'
    show
        BinaryBitmap,
        DecodeHints,
        DecodeHintType,
        GlobalHistogramBinarizer,
        HybridBinarizer,
        LuminanceSource,
        RGBLuminanceSource;

import '../../../data/providers.dart' show tripsRepoProvider;
import '../../../platform/detect_env.dart' show isTestEnv;
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/tokens.dart';
import '../../desktop/sync/sync_code.dart';
import '../ledger_providers.dart';

/// 送进解码 isolate 的帧数据（亮度平面 + 宽高）。
class _FrameJob {
  const _FrameJob(this.luminance, this.width, this.height);
  final Uint8List luminance;
  final int width;
  final int height;
}

/// 摄像头 Y 平面直接作为亮度源（避免 RGB 转换；zxing2 未公开导出其 YUV 源类）。
class _YPlaneLuminance extends LuminanceSource {
  _YPlaneLuminance(this._ys, this._w, this._h)
      : super(_w, _h);
  final Uint8List _ys;
  final int _w, _h;

  @override
  Int8List getRow(int y, Int8List? row) {
    if (row == null || row.length < _w) row = Int8List(_w);
    final off = y * _w;
    for (var x = 0; x < _w; x++) {
      row[x] = _ys[off + x].toSigned(8);
    }
    return row;
  }

  @override
  Int8List getMatrix() =>
      Int8List.view(_ys.buffer, _ys.offsetInBytes, _w * _h);
}

/// 解码一帧（在 isolate 中运行）：平面亮度 → HybridBinarizer + tryHarder。
/// 失败返回 null，不抛异常。
String? _decodeFrame(_FrameJob job) {
  final src = _YPlaneLuminance(job.luminance, job.width, job.height);
  final bitmap = BinaryBitmap(HybridBinarizer(src));
  final hints = DecodeHints()
    ..put(DecodeHintType.tryHarder);
  try {
    return QRCodeReader().decode(bitmap, hints: hints).text;
  } catch (_) {
    return null;
  }
}

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _pasteCtl = TextEditingController();

  // ---- 摄像头实时扫码 ----
  CameraController? _cam;
  bool _camError = false; // 摄像头不可用（无权限/无相机），退回照片方式
  bool _decoding = false; // 正在解码上一帧
  bool _paused = false; // 多页扫描暂停（等用户对准下一张）时置为 true
  DateTime _lastDecodeAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _torchOn = false;

  // ---- 识别 / 导入状态 ----
  bool _busy = false; // 照片识别 / 导入进行中
  String _status = '';
  final List<String> _rawChunks = [];
  int _total = 0;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && !isTestEnv) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    _pausePreview();
    _cam?.dispose();
    _pasteCtl.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------------------------------------------------------------------------
  // 摄像头：初始化、帧走进、启停
  // ---------------------------------------------------------------------------

  Future<void> _initCamera() async {
    try {
      if (await Permission.camera.isGranted == false) {
        final res = await Permission.camera.request();
        if (!res.isGranted) {
          if (mounted) {
            setState(() {
              _camError = true;
              _status = '未授予相机权限，请使用「拍照/相册」或粘贴同步码';
            });
          }
          return;
        }
      }
      final cams = await availableCameras();
      if (cams.isEmpty) throw StateError('no camera');
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      // Android 走 yuv420 平面（直接用 Y 平面亮度解码，最省）；iOS 不指定保持默认。
      final ctr = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.unknown,
      );
      await ctr.initialize();
      if (!mounted) {
        await ctr.dispose();
        return;
      }
      _cam = ctr;
      setState(() => _camError = false);
      await _resumePreview();
    } catch (e) {
      dev.log('相机初始化失败：$e', name: 'qr_scan');
      if (mounted) {
        setState(() {
          _camError = true;
          _status = '相机不可用（${e is CameraException ? e.code : '依赖' }）\n请使用「拍照/相册」识别或粘贴同步码';
        });
      }
    }
  }

  Future<void> _resumePreview() async {
    final ctr = _cam;
    if (ctr == null || !ctr.value.isInitialized) return;
    try {
      if (!ctr.value.isStreamingImages) {
        await ctr.startImageStream(_onFrame);
      }
      if (mounted) setState(() => _paused = false);
    } catch (_) {
      // 已在流或权限异常时忽略，照片方式兜底
    }
  }

  Future<void> _pausePreview() async {
    final ctr = _cam;
    if (ctr == null) return;
    try {
      if (ctr.value.isStreamingImages) {
        await ctr.stopImageStream();
      }
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    final ctr = _cam;
    if (ctr == null) return;
    final next = !_torchOn;
    try {
      await ctr.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = next);
    } catch (_) {
      _toast('该设备不支持手电筒');
    }
  }

  /// 每帧回调：节流 + 拷贝亮度平面 + isolate 解码 + 自动连扫。
  /// 多页二维码之间不暂停：识别到一页立即继续解码下一帧，重复页按块号去重；
  /// 全部集齐并合并导入成功后冻结取景（显示结果），可点「继续扫描」再来一轮。
  Future<void> _onFrame(CameraImage image) async {
    if (_decoding || _paused || _busy) return;
    final now = DateTime.now();
    if (now.difference(_lastDecodeAt) < const Duration(milliseconds: 220)) return;
    _decoding = true;
    try {
      final job = _frameToLuminance(image);
      if (job == null) return;
      _lastDecodeAt = now;
      final text = await compute(_decodeFrame, job);
      if (text != null && mounted) {
        final done = await _acceptChunk(text);
        if (done) {
          // 全部数据已导入：不再解码后续帧（不停流，避免在回调内 stopImageStream 死锁）
          if (mounted) setState(() => _paused = true);
        } else if (mounted && _total > 0) {
          setState(() => _status = '已扫 ${_rawChunks.length}/$_total 页 · 请对准下一张二维码（自动继续）');
        }
      }
    } catch (e) {
      dev.log('识别/导入失败：$e', name: 'qr_scan');
      if (mounted) {
        setState(() => _status = '识别或导入失败：$e');
      }
    } finally {
      _decoding = false;
    }
  }

  /// CameraImage → (亮度平面, 宽, 高)。yuv420 直接取 Y 平面（处理行距），
  /// bgra8888（iOS）现场算亮度；返回独立副本，避免底层缓冲复用。
  _FrameJob? _frameToLuminance(CameraImage image) {
    final w = image.width, h = image.height;
    final group = image.format.group;
    if (group == ImageFormatGroup.yuv420 && image.planes.isNotEmpty) {
      final plane = image.planes[0];
      final bytesPerRow = plane.bytesPerRow;
      final lum = Uint8List(w * h);
      if (bytesPerRow == w) {
        lum.setRange(0, lum.length, plane.bytes);
      } else {
        final rowLen = w < bytesPerRow ? w : bytesPerRow;
        for (var r = 0; r < h; r++) {
          final src = r * bytesPerRow;
          final dst = r * w;
          lum.setRange(dst, dst + rowLen, plane.bytes, src);
        }
      }
      return _FrameJob(lum, w, h);
    }
    if (group == ImageFormatGroup.bgra8888 && image.planes.isNotEmpty) {
      final bytes = image.planes[0].bytes;
      final lum = Uint8List(w * h);
      var o = 0;
      for (var i = 0; i < lum.length; i++) {
        final b = bytes[o], g = bytes[o + 1], r = bytes[o + 2];
        lum[i] = ((299 * r + 587 * g + 114 * b + 500) ~/ 1000).toInt();
        o += 4;
      }
      return _FrameJob(lum, w, h);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 同步码：分块收集 / 合并 / 智能导入
  // ---------------------------------------------------------------------------

  /// 处理识别到的文本，返回 true 表示「数据已全部导入，无需继续扫描」。
  Future<bool> _acceptChunk(String text) async {
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
        return true;
      }
      return false;
    }
    await _importCode(text);
    return true;
  }

  /// 智能识别同步码：全量包 / 单团包 / 单行程包，分别走对应合并导入。
  Future<void> _importCode(String code) async {
    final json = decodeSyncCode(code);
    final obj = jsonDecode(json) as Map;
    String msg;
    if (obj['groups'] is List && obj['standaloneTrips'] is List) {
      msg = await importFullSyncJson(ref, json);
    } else if (obj['group'] is Map) {
      msg = await mergeGroupSnapshot(ref, json);
    } else if (obj['trip'] is Map) {
      final r = await ref
          .read(tripsRepoProvider)
          .importTripBackupMap(obj.cast<String, dynamic>());
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

  Future<bool> _runImport(String Function() dec) async {
    setState(() => _busy = true);
    try {
      final text = dec();
      await _importCode(text);
      return true;
    } catch (e) {
      if (mounted) setState(() => _status = '导入失败：$e');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 拍照 / 相册兜底识别（图片字节 → 二维码文本）
  // ---------------------------------------------------------------------------

  Future<String?> _decodeImageBytes(Uint8List bytes) async {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
      if (decoded != null) {
        // 统一烘焙 EXIF 旋转方向（无 EXIF 时是空操作），避免拍竖屏图倒转。
        decoded = img.bakeOrientation(decoded);
      }
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) return null;
    // 缩小到 ≤1000 宽：保解码速度与抗噪，zxing 对过大的图反而更易失败
    if (decoded.width > 1000) {
      decoded = img.copyResize(decoded, width: 1000, interpolation: img.Interpolation.average);
    }
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
    final hints = DecodeHints()..put(DecodeHintType.tryHarder);
    // 主尝试：HybridBinarizer；兜底：GlobalHistogramBinarizer（对低对比/眩光图更稳）
    try {
      return QRCodeReader()
          .decode(BinaryBitmap(HybridBinarizer(src)), hints: hints)
          .text;
    } catch (_) {
      final second = RGBLuminanceSource(w, h, pixels);
      try {
        return QRCodeReader()
            .decode(BinaryBitmap(GlobalHistogramBinarizer(second)), hints: hints)
            .text;
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _pickAndDecode(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final x = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 88);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final text = await _decodeImageBytes(bytes);
      if (text == null) throw StateError('未能识别二维码，请对准重拍或换一张更清晰的');
      await _acceptChunk(text);
    } catch (e) {
      if (mounted) setState(() => _status = '识别失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 粘贴 & 导出
  // ---------------------------------------------------------------------------

  Future<void> _pasteImport() async {
    final text = _pasteCtl.text.trim();
    if (text.isEmpty) {
      _toast('请粘贴同步码');
      return;
    }
    await _runImport(() => text);
  }

  Future<void> _exportFullCode() async {
    try {
      final json = await exportFullSyncJson(ref);
      final code = encodeSyncCode(json);
      final chunks = chunkSyncCode(code);
      await Clipboard.setData(ClipboardData(text: code));
      var tip = '已复制全量同步码（第 1 页/共 ${chunks.length} 页），发送给电脑端「口令码」粘贴导入';
      if (chunks.length == 1) tip = '已复制全量同步码，发送给电脑端「口令码」粘贴导入';
      _toast(tip);
    } catch (e) {
      _toast('导出失败：${e.toString()}');
    }
  }

  Future<void> _exportGroupCode() async {
    try {
      // 优先当前团，无则取第一个可用团（导出单团码，数据较少、更容易一张二维码带走）
      String? gid = ref.read(activeGroupIdProvider).value;
      if (gid == null) {
        final groups = ref.read(groupsProvider).valueOrNull ?? [];
        if (groups.isNotEmpty) gid = groups.first.id;
      }
      if (gid == null) {
        _toast('暂无旅行团可导出；可改用「导出全量同步码」');
        return;
      }
      final json = await exportGroupSnapshot(ref, gid);
      final code = encodeSyncCode(json);
      await Clipboard.setData(ClipboardData(text: code));
      _toast('已复制当前团同步码，发送给电脑端「口令码」粘贴导入');
    } catch (e) {
      _toast('导出失败：${e.toString()}');
    }
  }

  void _reset() {
    _pausePreview();
    setState(() {
      _rawChunks.clear();
      _total = 0;
      _status = '';
    });
    _resumePreview();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final camReady = _cam?.value.isInitialized ?? false;
    return Scaffold(
      appBar: GlassAppBar(title: '扫码同步'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxxl),
          children: [
            Text('对准电脑端「与手机同步」二维码自动识别；多页二维码逐张对准即可，全部扫完自动合并导入。',
                style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.md),
            // ---- 实时取景框 ----
            if (!kIsWeb && !_camError)
              ClipRRect(
                borderRadius: AppRadius.card,
                child: AspectRatio(
                  aspectRatio: camReady ? (_cam!.value.aspectRatio < 0.5 ? 0.75 : _cam!.value.aspectRatio) : 0.75,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      camReady
                          ? CameraPreview(_cam!)
                          : ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2))),
                      // 取景框 + 状态蒙层
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: _paused ? scheme.tertiary : scheme.primary, width: 2.5),
                            borderRadius: AppRadius.card,
                          ),
                        ),
                      ),
                      if (_paused)
                        Container(
                          color: Colors.black.withValues(alpha: 0.5),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(Spacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 34),
                              const SizedBox(height: Spacing.sm),
                              Text(_status.isEmpty ? '已导入' : _status,
                                  textAlign: TextAlign.center,
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                              const SizedBox(height: Spacing.xs),
                              TextButton.icon(
                                onPressed: _resumePreview,
                                icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                                label: const Text('继续扫描', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _camReadyIconButton(
                          icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          onTap: _toggleTorch,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_camError) ...[
              const SizedBox(height: Spacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: AppRadius.card,
                ),
                child: Text('相机不可用，请用下方「拍照 / 相册」识别，或直接粘贴同步码',
                    style: TextStyle(fontSize: 13, color: scheme.onErrorContainer)),
              ),
            ],
            const SizedBox(height: Spacing.md),
            // ---- 多页进度 ----
            if (_total > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _rawChunks.length / _total,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Text('${_rawChunks.length}/$_total 页',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.primary)),
                ],
              ),
              TextButton(onPressed: _reset, child: const Text('重新开始')),
            ],
            if (_status.isNotEmpty && _total == 0) ...[
              const SizedBox(height: Spacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.45),
                  borderRadius: AppRadius.card,
                ),
                child: Text(_status,
                    style: TextStyle(fontSize: 13, color: scheme.onSecondaryContainer)),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            // ---- 内嵌操作（不再弹底部弹层，避免被遮挡） ----
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pickAndDecode(ImageSource.camera),
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_camera_rounded, size: 18),
                    label: const Text('拍照识别'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pickAndDecode(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('相册识别'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xl),
            const Divider(),
            const SizedBox(height: Spacing.md),
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
            const SizedBox(height: Spacing.xl),
            const Divider(),
            const SizedBox(height: Spacing.md),
            Text('导出到电脑端',
                style: TextStyle(fontSize: AppFontSizes.body, fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.sm),
            Text('复制同步码后到电脑「与手机同步 → 口令码」粘贴导入；数据多时建议直接全量导出。',
                style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.md),
            OutlinedButton.icon(
              onPressed: _busy ? null : _exportFullCode,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('导出全量同步码（所有团 + 未绑团行程）'),
            ),
            const SizedBox(height: Spacing.sm),
            TextButton.icon(
              onPressed: _busy ? null : _exportGroupCode,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('导出当前团同步码'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _camReadyIconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}