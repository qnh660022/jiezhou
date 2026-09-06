/// 统一请求执行器（§7.15）：dio 单例 + 域名节奏器 + 失败分级 + robots 前置。
///
/// 硬性纪律：同域名请求间隔 ≥2s、全局在飞 ≤2、同一域名串行；
/// 反爬信号（403/429/验证码特征）该源冷处理 2h；网络类失败该 URL 30min 退避；
/// 不带 Cookie、不做 UA 伪装、不解 CAPTCHA、不翻页遍历。
library;
import 'dart:async';

import 'package:dio/dio.dart';

import '../../platform/fs.dart' as fs;
import 'guide_crawler_rules.dart';

enum GuideFetchClass { ok, networkFail, blocked, parseFail }

class GuideFetchResult {
  const GuideFetchResult(this.cls, this.body);
  final GuideFetchClass cls;
  final String body; // ok=正文；blocked=说明；其余空
}

class GuideHttp {
  GuideHttp._();

  static final GuideHttp instance = GuideHttp._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      // 常规移动浏览器形态 UA（正常形态、不做伪装）
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/124.0 Mobile Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9',
    },
  ));

  final Map<String, DateTime> _lastRequestAt = {};
  final Map<String, DateTime> _sourceCooldownUntil = {}; // 源冷处理
  final Map<String, DateTime> _urlBackoffUntil = {}; // URL 退避
  int _inFlight = 0;

  /// robots 缓存：domain → (fetchedAt, lines)
  final Map<String, (DateTime, List<String>)> _robotsCache = {};

  static const Duration _minInterval = Duration(seconds: 2);
  static const Duration _sourceCooldown = Duration(hours: 2);
  static const Duration _urlBackoff = Duration(minutes: 30);

  bool isSourceCool(String host) =>
      (_sourceCooldownUntil[host]?.isAfter(DateTime.now())) ?? false;

  bool isUrlBackedOff(String url) =>
      (_urlBackoffUntil[url]?.isAfter(DateTime.now())) ?? false;

  /// GET 文本（含 robots 前置 + 域名节奏 + 失败分级）。
  Future<GuideFetchResult> fetchText(String url,
      {bool checkRobots = true}) async {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) {
      return const GuideFetchResult(GuideFetchClass.parseFail, '');
    }
    if (isSourceCool(host)) return const GuideFetchResult(GuideFetchClass.blocked, 'source_cool');
    if (isUrlBackedOff(url)) {
      return const GuideFetchResult(GuideFetchClass.networkFail, '');
    }
    if (checkRobots) {
      final allowed = await robotsAllows(host, url);
      if (!allowed) {
        _sourceCooldownUntil[host] = DateTime.now().add(_sourceCooldown);
        return const GuideFetchResult(GuideFetchClass.blocked, 'robots_disallow');
      }
    }
    // 域名节奏：等待至 lastRequestAt + 2s
    final last = _lastRequestAt[host];
    if (last != null) {
      final wait = last.add(_minInterval).difference(DateTime.now());
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequestAt[host] = DateTime.now();
    if (_inFlight >= 2) {
      return const GuideFetchResult(GuideFetchClass.networkFail, 'busy');
    }
    _inFlight++;
    try {
      final resp = await _dio.get<String>(url,
          options: Options(responseType: ResponseType.plain));
      final status = resp.statusCode ?? 0;
      if (status == 403 || status == 429) {
        _sourceCooldownUntil[host] = DateTime.now().add(_sourceCooldown);
        return GuideFetchResult(GuideFetchClass.blocked, 'http_$status');
      }
      if (status >= 500 || status == 0) {
        _urlBackoffUntil[url] = DateTime.now().add(_urlBackoff);
        return const GuideFetchResult(GuideFetchClass.networkFail, '');
      }
      final body = resp.data ?? '';
      if (_looksLikeCaptcha(body)) {
        _sourceCooldownUntil[host] = DateTime.now().add(_sourceCooldown);
        return const GuideFetchResult(GuideFetchClass.blocked, 'captcha_like');
      }
      return GuideFetchResult(GuideFetchClass.ok, body);
    } on DioException {
      _urlBackoffUntil[url] = DateTime.now().add(_urlBackoff);
      return const GuideFetchResult(GuideFetchClass.networkFail, '');
    } catch (_) {
      return const GuideFetchResult(GuideFetchClass.parseFail, '');
    } finally {
      _inFlight--;
    }
  }

  bool _looksLikeCaptcha(String body) {
    final lower = body.toLowerCase();
    const marks = ['verify', 'captcha', '滑动验证', '安全验证', '访问过于频繁'];
    return marks.any(lower.contains) && body.length < 20000;
  }

  /// robots 检查（缓存 24h，手写 prefix 规则；仅考虑 User-Agent: * 组）。
  Future<bool> robotsAllows(String host, String url) async {
    final path = Uri.tryParse(url)?.path ?? '/';
    var cached = _robotsCache[host];
    if (cached == null ||
        DateTime.now().difference(cached.$1) > const Duration(hours: 24)) {
      final res = await _fetchRobotsRaw(host);
      if (res == null) {
        // robots 拉不到：视为允许（不冷处理）
        _robotsCache[host] = (DateTime.now(), const <String>[]);
      } else {
        _robotsCache[host] = (DateTime.now(), res);
      }
      cached = _robotsCache[host];
    }
    final lines = cached!.$2;
    // 解析 User-agent: * 的 disallow 前缀
    var inStar = false;
    final disallows = <String>[];
    for (final raw in lines) {
      final line = raw.trim();
      final lower = line.toLowerCase();
      if (lower.startsWith('user-agent:')) {
        inStar = lower.contains('*');
      } else if (inStar && lower.startsWith('disallow:')) {
        final v = line.substring('disallow:'.length).trim();
        if (v.isNotEmpty) disallows.add(v);
      }
    }
    for (final d in disallows) {
      if (d == '/' || path.startsWith(d)) return false;
    }
    return true;
  }

  Future<List<String>?> _fetchRobotsRaw(String host) async {
    // robots.txt 不走限速（每次访问前查），失败静默
    try {
      final resp = await _dio.get<String>('https://$host/robots.txt',
          options: Options(responseType: ResponseType.plain));
      final t = resp.data ?? '';
      return t.split('\n');
    } catch (_) {
      return null;
    }
  }

  // ===== robots 磁盘缓存（§7.17 robot/<domain>.txt，24h TTL） =====

  Future<void> persistRobots(String host) async {
    final dir = await fs.writableDir();
    if (dir == null) return;
    final cached = _robotsCache[host];
    if (cached == null) return;
    await fs.writeFileString(
        '$dir/guide_cache/robot/$host.txt',
        '${cached.$1.millisecondsSinceEpoch}\n${cached.$2.join('\n')}');
  }
}
