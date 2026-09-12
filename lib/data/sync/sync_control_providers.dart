/// 同步层 Riverpod 控制：云引擎单例、账号态、状态流、共享数据源。
///
/// 客户端策略：main 阶段已 `Supabase.initialize` 则复用其单例客户端；
/// 配置仅来自构建时 --dart-define（V2.6.1 起无运行期改端点入口）。
library;
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../db/database.dart';
import '../providers.dart' show dbProvider;
import '../../theme/theme_provider.dart' show sharedPreferencesProvider;
import 'sync_account.dart';
import 'sync_engine.dart';
import 'sync_models.dart';
import 'sync_transport_supabase.dart';

/// 云功能就绪标记（有可用 client）。
final cloudReadyProvider = StateProvider<bool>((_) => false);

/// 当前 SupabaseClient（引擎与账号服务共用；未配置时 null）。
final cloudClientProvider = StateProvider<SupabaseClient?>((_) => null);

/// 同步引擎（云功能未就绪时 null；登录后 start、登出后 stop）。
final syncEngineProvider = StateProvider<SyncEngine?>((_) => null);

/// 当前登录用户 id / 邮箱（登录、登出、改端点后刷新）。
final currentUserIdProvider = StateProvider<String?>((_) => null);
final currentUserEmailProvider = StateProvider<String?>((_) => null);

Future<SupabaseClient?> _resolveClient() async {
  final cfg = await SupabaseCfg.resolve();
  if (cfg == null) return null;
  try {
    await Supabase.initialize(url: cfg.url, anonKey: cfg.anonKey, debug: false);
    return Supabase.instance.client;
  } catch (_) {
    // 已初始化过（main 阶段完成）→ 复用单例
    try {
      return Supabase.instance.client;
    } catch (_) {
      return SupabaseClient(cfg.url, cfg.anonKey);
    }
  }
}

SyncEngine? _spawnEngine(WidgetRef ref, SupabaseClient client) {
  final engine = SyncEngine.init(
    ref.read(dbProvider),
    SyncTransportSupabase(client),
    ref.read(sharedPreferencesProvider),
  );
  ref.read(syncEngineProvider.notifier).state = engine;
  return engine;
}

void _refreshIdentity(WidgetRef ref, SupabaseClient? client) {
  ref.read(currentUserIdProvider.notifier).state = client?.auth.currentUser?.id;
  ref.read(currentUserEmailProvider.notifier).state = client?.auth.currentUser?.email;
}

/// 匿名公开路由（只读分享页 `/s/<token>`、邀请页 `/invite`）。
///
/// 这两条路由是给「没装 App 的人」在浏览器里直接看的，访问者没有账号、
/// 也没有本设备数据可同步。此时启动同步引擎只会白拉一次本地数据库
/// （Web 上 = 下载并初始化 sqlite3.wasm + drift worker，几 MB 且拖慢首屏），
/// 因此只建 client、不建引擎。原生端恒为 false，行为完全不变。
bool get isAnonymousWebRoute => kIsWeb && _isPublicWebPath;

bool get _isPublicWebPath {
  final p = Uri.base.path;
  return p.startsWith('/s/') || p.startsWith('/invite');
}

/// App 首帧后调用一次：resolve 配置 → 建 client → 引擎冷启动。
/// 配置无效时静默保持未配置态。
Future<void> bootstrapCloud(WidgetRef ref) async {
  if (ref.read(syncEngineProvider) != null) return; // 幂等：重复调用直接复用
  final client = await _resolveClient();
  ref.read(cloudClientProvider.notifier).state = client;
  ref.read(cloudReadyProvider.notifier).state = client != null;
  _refreshIdentity(ref, client);
  if (client != null && !isAnonymousWebRoute) {
    final engine = _spawnEngine(ref, client);
    await engine?.start();
  }
}

/// 登录成功后调用：刷新账号态 + 启动引擎调度（引擎未建则先建）。
Future<void> onSignedIn(WidgetRef ref) async {
  final client = ref.read(cloudClientProvider);
  if (client == null) return;
  _refreshIdentity(ref, client);
  var engine = ref.read(syncEngineProvider);
  engine ??= _spawnEngine(ref, client);
  await engine?.start();
}

/// 登出后调用：停调度 + 复位运行时状态；保留 outbox 与引导标记。
///
/// 必须调 `resetRuntimeState()`：只 stop 的话，节流标志 / 失败计数 / 协作名单
/// 会残留到下一个账号，新账号一登录就顶着「离线 / 节流」（历史 bug M9）。
Future<void> onSignedOut(WidgetRef ref) async {
  final engine = ref.read(syncEngineProvider);
  engine?.stop();
  engine?.resetRuntimeState();
  _refreshIdentity(ref, ref.read(cloudClientProvider));
}

/// 账号服务。
final cloudAccountServiceProvider = Provider<CloudAccountService?>((ref) {
  final client = ref.watch(cloudClientProvider);
  return client == null ? null : CloudAccountService(client);
});

final collabServiceProvider = Provider<CollabService?>((ref) {
  final client = ref.watch(cloudClientProvider);
  return client == null ? null : CollabService(client);
});

final shareServiceProvider = Provider<ShareService?>((ref) {
  final client = ref.watch(cloudClientProvider);
  return client == null ? null : ShareService(client);
});

/// 同步状态流（同步中心 + 首页胶囊）。引擎未建时给静态态。
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  final cfgReady = ref.watch(cloudReadyProvider);
  final uid = ref.watch(currentUserIdProvider);
  if (engine == null) {
    final kind = !cfgReady
        ? SyncStatusKind.unconfigured
        : (uid == null ? SyncStatusKind.signedOut : SyncStatusKind.idle);
    return Stream.value(SyncStatus(kind: kind));
  }
  late StreamController<SyncStatus> ctl;
  late StreamSubscription<SyncStatus> sub;
  ctl = StreamController<SyncStatus>.broadcast(onListen: () {
    ctl.add(engine.status);
    sub = engine.statusStream.listen(ctl.add, onDone: ctl.close, onError: (_) {});
  }, onCancel: () => sub.cancel());
  return ctl.stream;
});

/// 共享账本（受邀端镜像）数据源：sharedGroups 表流。
final sharedGroupsStreamProvider = StreamProvider<List<SharedGroup>>((ref) {
  final db = ref.watch(dbProvider);
  return db.select(db.sharedGroups).watch();
});

/// 共享成员流（按团）。
final sharedMembersStreamProvider =
    StreamProvider.family<List<SharedMember>, String>((ref, groupId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.sharedMembers)..where((m) => m.groupId.equals(groupId))).watch();
});

/// 共享账单流（按团）。
final sharedExpensesStreamProvider =
    StreamProvider.family<List<SharedExpense>, String>((ref, groupId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.sharedExpenses)..where((e) => e.groupId.equals(groupId)))
      .watch();
});

/// 共享结算流（按团）。
final sharedSettlementsStreamProvider =
    StreamProvider.family<List<SharedSettlement>, String>((ref, groupId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.sharedSettlements)..where((s) => s.groupId.equals(groupId)))
      .watch();
});
