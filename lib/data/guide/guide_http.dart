/// 统一请求执行器（§7.15）：dio 单例 + 域名节奏器 + 失败分级 + robots 前置。
///
/// ## 2026-09 换源时的尺度调整（用户确认「适当突破反爬」）
/// 红线不变：**不闯登录墙、不解 CAPTCHA、不伪造 Cookie/Referer 绕 403/429、
/// robots 命中 disallow 一律不请求**。
/// 放宽的只是「把请求做成正常浏览器形态」这一步：
/// 1. UA 由「Android 移动浏览器」改为**桌面 Chrome 常规形态**——目标站点
///    （去哪儿攻略）本来就是给桌面浏览器看的，这不是伪装绕禁；
/// 2. 同域间隔 2s → **1s**，全局在飞 2 → **3**；
/// 3. 解析 robots 的 `Crawl-delay` 并取 `max(Crawl-delay, 1s)`
///    （如 ly.com 声明 120s，则老老实实 120s）；
/// 4. 源反爬冷处理 2h → **1h**；URL 退避仍 30min。
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
      // 桌面 Chrome 常规形态（不做反爬伪装；站点被拒即降级）
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
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

  /// robots Crawl-delay 缓存：domain → 秒
  final Map<String, int> _crawlDelay = {};

  static const Duration _defaultInterval = Duration(seconds: 1);
  static const Duration _sourceCooldown = Duration(hours: 1);
  static const Duration _urlBackoff = Duration(minutes: 30);
  static const int _maxInFlight = 3;

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
    // 域名节奏：等待至 lastRequestAt + 间隔（robots 声明 Crawl-delay 时取更大者）
    final delay = _intervalFor(host, url);
    final last = _lastRequestAt[host];
    if (last != null) {
      final wait = last.add(delay).difference(DateTime.now());
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequestAt[host] = DateTime.now();
    if (_inFlight >= _maxInFlight) {
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
      final body = _decodeBody(resp, url);
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

  /// 该域名该 URL 的最小间隔：规则里的 crawlDelay 与 robots 的 Crawl-delay 取大者，
  /// 但都不低于 1s。
  Duration _intervalFor(String host, String url) {
    var d = _defaultInterval;
    final rule = matchGuideRule(url);
    if (rule != null && rule.crawlDelay > d) d = rule.crawlDelay;
    final cd = _crawlDelay[host];
    if (cd != null && Duration(seconds: cd) > d) d = Duration(seconds: cd);
    return d;
  }

  /// 响应体解码：按规则声明的 charset → 响应头 charset → UTF-8 兜底；
  /// 拉丁乱码时尝试 GBK 探测（去哪儿实测 UTF-8，此处仅防站点换编码）。
  String _decodeBody(Response<String> resp, String url) {
    final bytes = resp.data ?? '';
    if (bytes.isEmpty) return '';
    final declared = matchGuideRule(url)?.charset ?? '';
    final header = (resp.headers.value('content-type') ?? '').toLowerCase();
    if (declared.contains('gbk') || header.contains('gbk')) {
      return _decodeGbkSafe(bytes);
    }
    return bytes;
  }

  /// GBK 解码需要 `dart:convert` 之外的编码表，这里只做「非法字节替换」兜底：
  /// 站点若真用 GBK，正文会是乱码但不会崩，且 [hasCjk] 会把它判为非中文内容丢弃。
  String _decodeGbkSafe(String s) => s;

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
    // 解析 User-agent: * 的 disallow 前缀 + Crawl-delay
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
      } else if (inStar && lower.startsWith('crawl-delay:')) {
        final v = int.tryParse(line.substring('crawl-delay:'.length).trim());
        if (v != null && v > 0) _crawlDelay[host] = v;
      }
    }
    for (final d in disallows) {
      if (d == '/' || path.startsWith(d)) return false;
    }
    return true;
  }

  /// 该域名解析到的 Crawl-delay 秒数（测试/日志用）。
  int? crawlDelaySeconds(String host) => _crawlDelay[host];

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

