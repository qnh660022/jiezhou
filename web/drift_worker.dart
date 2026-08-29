// drift Web worker 入口。此文件不参与应用主构建，仅用于编译出
// web/drift_worker.dart.js 供 WasmDatabase.open 在后台线程托管 SQLite。
// 编译命令：dart compile js -O4 web/drift_worker.dart
import 'package:drift/wasm.dart';

void main() {
  WasmDatabase.workerMainForOpen();
}