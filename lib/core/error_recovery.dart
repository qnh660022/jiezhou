/// 全局错误兜底与自愈。
///
/// 背景：release 模式下 widget 构建抛异常时，Flutter 默认渲染一块死灰屏
/// （GSOD，0xF0C0C0C0），无任何信息也无法恢复，用户只能杀进程重开。
/// 本模块把它改造成「可自愈 + 可诊断」：
///   1. 任何构建/异步错误 → 完整堆栈追加写入 Documents/startup_error.log；
///   2. 启动后 10 秒内的首次错误 → 自动整树重启一次（等效用户手动重开，
///      而重开已被证实有效 —— 症状是概率性竞态，重开大概率落进正常路径）；
///   3. 再次出错 → 显示可读错误屏：错误摘要 + 「重启应用」+「复制错误」，
///      用户截图/复制即可回传确切根因。
///
/// 自愈重启通过 [appEpoch] +1 完成：main 中以 ValueKey 包裹整棵应用树，
/// key 变化强制 remount（含 ProviderScope 全新容器），开屏页重播。
library;
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/fs.dart' show persistErrorLog;

/// 应用树纪元：自愈/手动重启时 +1。
final ValueNotifier<int> appEpoch = ValueNotifier<int>(0);

/// 重启应用：整树重挂载，回到开屏页，状态全部重建。
void restartApp() => appEpoch.value++;

DateTime _bootTime = DateTime.now();
bool _autoRecovered = false;
bool _restarting = false;

/// 在 main() 中 runApp 之前调用一次。
void installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    _presentError(details.exception, details.stack, details.toString());
  };
  PlatformDispatcher.instance.onError = (e, stack) {
    _presentError(e, stack, '$e\n\n$stack');
    return true; // 已兜底记录，不让进程直接崩溃
  };
  ErrorWidget.builder = (details) => _ErrorRecoveryBox(error: details.exception);
}

Future<void> _persistLog(String detail) async {
  // 落盘逻辑按平台隔离（Web 无文件系统，为空实现），此处不 catch ——
  // 实现内部均已 try/catch，不会让自愈本身抛错。
  await persistErrorLog(detail);
}

void _presentError(Object error, StackTrace? stack, String detail) {
  // ignore: avoid_print
  print('【启动守卫】捕获错误：$detail');
  _persistLog(detail);

  // 启动窗口期（10s）内首次错误：静默自动重启一次。
  // 只自动一次 —— 若错误对某状态是确定性的，重启不解决，改由错误屏接管，
  // 同时也杜绝「错误→重启→错误」的无限循环。
  final inBootWindow = DateTime.now().difference(_bootTime)
      < const Duration(seconds: 10);
  if (inBootWindow && !_autoRecovered && !_restarting) {
    _autoRecovered = true;
    _restarting = true;
    Timer(const Duration(milliseconds: 400), () {
      _bootTime = DateTime.now();
      restartApp();
      _restarting = false;
    });
  }
}

/// 错误恢复屏：替代 release 死灰屏。
/// 刻意不依赖 Theme/MediaQuery/Material 等任何祖先 —— 它可能在
/// MaterialApp 自身构建失败时显示，祖先树不可信。
class _ErrorRecoveryBox extends StatelessWidget {
  const _ErrorRecoveryBox({required this.error});

  final Object error;

  String get _summary {
    var text = '$error';
    if (text.length > 600) text = text.substring(0, 600);
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFF7FBF8),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              '页面出了点问题，已自动记录',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1E)),
            ),
            const SizedBox(height: 6),
            const Text(
              '点「重启应用」通常即可恢复；\n若反复出现，请截图此页反馈',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF5A5F5A)),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEDEFEA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Text(_summary,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF44484A))),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pill(
                  label: '重启应用',
                  bg: const Color(0xFF2E7D5B),
                  fg: const Color(0xFFFFFFFF),
                  onTap: restartApp,
                ),
                const SizedBox(width: 14),
                _pill(
                  label: '复制错误信息',
                  bg: const Color(0xFFE0E4DE),
                  fg: const Color(0xFF1A1C1E),
                  onTap: () {
                    try {
                      Clipboard.setData(ClipboardData(text: _summary));
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}
