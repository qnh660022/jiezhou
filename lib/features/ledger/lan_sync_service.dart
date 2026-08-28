/// 局域网离线协作记账：同一 Wi-Fi 下「发起口令」/「加入口令」快照同步。
///
/// 传输纯走局域网（TCP HTTP + UDP 发现口），全程离线、不依赖公网。
/// 协议：
///   GET  /snapshot  → 返回主机「当前团」整包 JSON 快照（稳定 id），供加入方拉取合并；
///   POST /snapshot  → 请求体为对方快照 JSON，主机解析后按 id 合并进本地（LWW）。
/// 发现：主机周期性向 255.255.255.255 广播 {code,port}；加入方监听并比对口令下发回执；
///        若广播被 AP 隔离，主机界面会展示本机 IP，加入方可用「手动填 IP」兜底。
library;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// UDP 发现端口（两端固定）
const int kLanSyncUdpPort = 45512;
/// 广播目标（同网段广播地址）
const String kLanSyncBroadcast = '255.255.255.255';
/// 时钟心跳广播间隔
const Duration _announceInterval = Duration(milliseconds: 1200);

class LanPeer {
  const LanPeer({required this.ip, required this.port});
  final String ip;
  final int port;
}

/// 局域网同步管理：主机端启动 HTTP 服务 + 口令广播；加入端按口令发现并双向收发。
class LanSyncManager {
  HttpServer? _http;
  RawDatagramSocket? _udp;
  Timer? _announce;
  String? _code;
  bool _closed = false;

  /// 当前团快照提供者（由屏幕注入，取机主「当前团」）
  Future<String> Function()? snapshotProvider;
  /// 快照合并者（屏幕注入，把对方快照 merge 进本地）
  Future<String> Function(String raw)? snapshotMerger;

  /// 启动主机：绑定 HTTP 服务 + UDP 口令广播。返回 (口令, HTTP端口, 本机IPv4列表)。
  Future<(String, int, List<String>)> startHost({
    required Future<String> Function() snapshotProvider,
    required Future<String> Function(String) snapshotMerger,
    int httpPort = 45681,
  }) async {
    this.snapshotProvider = snapshotProvider;
    this.snapshotMerger = snapshotMerger;
    _closed = false;
    _code = _newCode();
    _announce?.cancel(); // 防重复启动造成多定时器叠加

    // HTTP 服务
    _http = await HttpServer.bind(InternetAddress.anyIPv4, httpPort);
    _http!.listen(_onRequest);

    // UDP 广播口令 + 响应加入方发现询问（广播常被 AP 隔离，必须同时支持单播回执）
    _udp = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, kLanSyncUdpPort,
        reuseAddress: true, reusePort: true);
    _udp!.broadcastEnabled = true;
    _udp!.listen(_onUdpEvent); // 处理发现询问，并回执给询问者
    _announce = Timer.periodic(_announceInterval, (_) => _announceCode());

    final ips = await _localIPv4s();
    return (_code!, _http!.port, ips);
  }

  void _onRequest(HttpRequest req) async {
    try {
      final uri = req.uri.path;
      if (req.method == 'GET' && uri == '/snapshot') {
        final json = await snapshotProvider?.call() ?? '{}';
        req.response.headers.contentType =
            ContentType('application', 'json', charset: 'utf-8');
        req.response.write(json);
        await req.response.close();
      } else if (req.method == 'POST' && uri == '/snapshot') {
        final body = await utf8.decoder.bind(req).join();
        final summary = await snapshotMerger?.call(body) ?? '合并完成';
        req.response.headers.contentType =
            ContentType('text', 'plain', charset: 'utf-8');
        req.response.write(summary);
        await req.response.close();
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    } catch (e) {
      try {
        req.response.statusCode = HttpStatus.badRequest;
        req.response.write('err:${e.toString()}');
        await req.response.close();
      } catch (_) {}
    }
  }

  void _announceCode() {
    if (_closed || _udp == null || _code == null) return;
    final msg = utf8.encode(
        jsonEncode({'app': 'trip-sync', 'code': _code, 'port': _http?.port}));
    try {
      _udp!.send(msg, InternetAddress(kLanSyncBroadcast), kLanSyncUdpPort);
    } catch (_) {}
  }

  /// 主机端 UDP 事件：收到加入方的发现询问时，单播回执（把广播受限无法到达的兜底掉）。
  ///
  /// 【防回声风暴 · 关键】只对「纯询问包」（不带 port 字段）做单播回执；
  /// 带 port 的包是广播宣告（可能是自己周期性发出的、被本机回收，也可能是
  /// 同网另一台主机端发来的），一律不回。否则主机会把自己的宣告/回声
  /// 反复回给自己 → 数据报指数放大 → 主进程忙死、界面卡死、HTTP 快照
  /// 响应被饿死（对方「拉取不到账本」），且无法退出共享。
  void _onUdpEvent(RawSocketEvent event) {
    if (_closed || _udp == null || _code == null) return;
    if (event != RawSocketEvent.read) return;
    final dg = _udp!.receive();
    if (dg == null) return;
    try {
      final obj = jsonDecode(utf8.decode(dg.data));
      if (obj is Map &&
          obj['app'] == 'trip-sync' &&
          obj['code'] is String &&
          obj['code'] == _code &&
          obj['port'] is! int) {
        // 对方在问我的口令（纯询问，无 port）—— 单播回我的端口，
        // 确保即使广播被隔离也能被发现。
        final reply = utf8.encode(jsonEncode(
            {'app': 'trip-sync', 'code': _code, 'port': _http?.port}));
        _udp!.send(reply, dg.address, dg.port);
      }
    } catch (_) {}
  }

  /// 关闭主机服务
  Future<void> dispose() async {
    _closed = true;
    _announce?.cancel();
    try {
      await _http?.close(force: true);
    } catch (_) {}
    try {
      _udp?.close();
    } catch (_) {}
    _http = null;
    _udp = null;
  }

  // ---- 加入端 ----

  /// 按口令发现主机；成功返回其 (ip, port)。可传 [manualIp] 兜底（主机屏幕会展示 IP）。
  Future<LanPeer> discoverHost(String code,
      {String? manualIp, int manualPort = 45681}) async {
    final ip = manualIp?.trim() ?? '';
    if (ip.isNotEmpty) {
      return LanPeer(ip: ip, port: manualPort);
    }
    final completer = Completer<LanPeer>();
    final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, kLanSyncUdpPort,
        reuseAddress: true, reusePort: true);
    socket.broadcastEnabled = true;
    final listen = socket.listen((event) {
      if (event != RawSocketEvent.read || completer.isCompleted) return;
      final dg = socket.receive();
      if (dg == null) return;
      try {
        final obj = jsonDecode(utf8.decode(dg.data));
        if (obj is Map &&
            obj['app'] == 'trip-sync' &&
            obj['code'] == code &&
            (obj['port'] is int) &&
            !completer.isCompleted) {
          completer.complete(
              LanPeer(ip: dg.address.address, port: obj['port'] as int));
        }
      } catch (_) {}
    });
    final query = utf8.encode(jsonEncode({'app': 'trip-sync', 'code': code}));
    final target = InternetAddress(kLanSyncBroadcast);
    var attempts = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 1100), (t) {
      if (completer.isCompleted) {
        t.cancel();
        return;
      }
      try {
        socket.send(query, target, kLanSyncUdpPort);
      } catch (_) {}
      attempts++;
      if (attempts >= 12) {
        t.cancel();
        if (!completer.isCompleted) {
          completer.completeError(Exception(
              '未找到对口令的主机：请确认在同一 Wi-Fi，或手动填主机 IP'));
        }
      }
    });
    try {
      return await completer.future;
    } finally {
      listen.cancel();
      timer.cancel();
      socket.close();
    }
  }

  // ---- 传输 ----

  /// 拉取主机快照（join 侧）：返回主机当前团快照 JSON。
  Future<String> pullSnapshot(LanPeer peer) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(
              Uri.parse('http://${peer.ip}:${peer.port}/snapshot'))
        ..headers.contentType =
            ContentType('application', 'json', charset: 'utf-8');
      final res = await req.close();
      // 读取阶段也加总超时：主机忙碌/网络抖动时避免 join 侧无限挂起。
      return await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
    }
  }

  /// 推送本机快照给主机（join 侧）：返回主机合并后的摘要。
  Future<String> pushSnapshot(LanPeer peer, String snapshotJson) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client
          .postUrl(Uri.parse('http://${peer.ip}:${peer.port}/snapshot'))
        ..headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      req.write(snapshotJson);
      final res = await req.close();
      return await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
    }
  }

  // ---- 工具 ----

  String _newCode() {
    var n = '';
    for (var i = 0; i < 6; i++) {
      n += (1 + Random().nextInt(9)).toString();
    }
    return n;
  }

  Future<List<String>> _localIPv4s() async {
    final out = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (final i in interfaces) {
        for (final a in i.addresses) {
          final ip = a.address;
          if (!ip.startsWith('127.') && !out.contains(ip)) out.add(ip);
        }
      }
    } catch (_) {}
    if (out.isEmpty) out.add('未识别');
    return out;
  }
}