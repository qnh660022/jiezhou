/// Web：使用 drift WasmDatabase 在后台 worker 托管 SQLite。
/// 依赖 web/ 下预编译的 sqlite3.wasm 与 drift_worker.dart.js。
library;
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor create() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'travel_v2',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    if (result.missingFeatures.isNotEmpty) {
      // 存储可能已降级（如 IndexedDB / 内存），仅提示，不阻塞使用。
      // ignore: avoid_print
      print('drift 存储降级：${result.chosenImplementation}，'
          '缺失：${result.missingFeatures}');
    }
    return result.resolvedExecutor;
  }));
}