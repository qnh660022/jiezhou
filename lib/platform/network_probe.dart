/// 网络类型探测门面（「仅 Wi-Fi 同步」用）。
///
/// 设计取舍：不引入 `connectivity_plus` 等新依赖（需 pub get + 重新打包，收益
/// 不匹配），改用纯 Dart 条件导入 + 接口名启发式判定，沿用项目既有
/// `detect_env` / `db_connection` 惯例。
///
/// **调用方约定：`unknown` 一律 fail-open（视为允许同步）**——静默停同步会让
/// 跨端数据长期不一致且用户无感，代价高于偶发走一次蜂窝。真正要不要拦，由
/// 引擎的 `_wifiBlocked` 决定，策略点集中在一处。
library;

import 'network_probe_io.dart'
    if (dart.library.js_interop) 'network_probe_web.dart' as impl;

/// 当前网络类型（尽力而为）。
enum NetKind { wifi, mobile, unknown }

/// 探测当前网络类型；异常/无法判定 → [NetKind.unknown]。
Future<NetKind> probeNetKind() async => _fromName(await impl.probeNetKindName());

NetKind _fromName(String name) => switch (name) {
      'wifi' => NetKind.wifi,
      'mobile' => NetKind.mobile,
      _ => NetKind.unknown,
    };
