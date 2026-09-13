/// 协作页面短轮询宿主（V2.6.6.2 §4.2 / D6）。
///
/// 把「页面可见」这件事翻译成 [SyncVisibilityPoller] 的 start/stop：
/// * 挂载（进入页面）→ start；
/// * 卸载（离开页面）→ stop；
/// * App 退后台 / 回前台 → stop / start；
/// * 页面仍在 IndexedStack 里但已被别的 Tab 盖住（`ModalRoute.isCurrent == false`）
///   → 定时器到点时跳过本次请求（`isActive` 闸门），不可见就不发网络请求。
///
/// 用法：
/// ```dart
/// CollabPollingScope(child: Scaffold(...))
/// ```
library;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/sync_engine.dart';
import '../../data/sync/sync_visibility_poller.dart';
import '../../data/sync/sync_control_providers.dart';

class CollabPollingScope extends ConsumerStatefulWidget {
  const CollabPollingScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CollabPollingScope> createState() => _CollabPollingScopeState();
}

class _CollabPollingScopeState extends ConsumerState<CollabPollingScope>
    with WidgetsBindingObserver {
  SyncVisibilityPoller? _poller;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final engine = ref.read(syncEngineProvider);
    _poller = SyncVisibilityPoller(
      scheduler: engine?.scheduler ?? const RealSyncScheduler(),
      isActive: () => _resumed && mounted,
      onTick: () {
        // 只拉增量：短轮询的语义是「看看别人改了啥」，
        // 上行交给引擎自己的 debounce / 周期节奏（避免页面轮询放大写流量）。
        final e = ref.read(syncEngineProvider);
        if (e != null) unawaited(e.syncNow(push: false));
      },
    )..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.dispose();
    _poller = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _poller?.onLifecycleChanged(_resumed);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
