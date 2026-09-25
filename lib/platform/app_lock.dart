/// 启动锁（V2.7.1 S7.2 · F3）门面：状态、校验与冷启动门控。
///
/// 【范围红线（§S7.2「不做」清单）】
/// * 只在 App **冷启动**判断一次（`GoRouter` redirect → `/lock`）；
/// * ❌ 不做进入账本二级校验 ❌ 不做后台回前台上锁 ❌ 不引入生物识别；
/// * PIN 与哈希**仅存本地 SharedPreferences**，不上云、不写日志、不进崩溃上报。
///
/// 【口令学】PBKDF2-HMAC-SHA256(pin, 16B 随机盐, 100000 迭代, 32B)，
/// 比较走常量时间（见 `core/app_lock_crypto.dart`），绝不 `==` 比哈希串。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_lock_io.dart' if (dart.library.js_interop) 'app_lock_web.dart'
    as impl;
import '../core/app_lock_crypto.dart';

/// 平台差异说明（设置页展示）。
String get appLockPlatformNote => impl.kAppLockPlatformNote;

/// Web 端清站点数据即失效（UI 需额外提示）。
bool get appLockVolatileWithSiteData => impl.kAppLockVolatileWithSiteData;

/// PIN 位数（仅 6 位数字，Android / Web 一致）。
const int kPinLength = 6;

/// PBKDF2 迭代次数（规格定死，不做二选一）。
const int kPinIterations = 100000;

/// 连续失败上限与冷却时长。
const int kMaxPinFailures = 5;
const Duration kPinCooldown = Duration(seconds: 30);

/// 本地存储键（不参与云同步）。
abstract final class AppLockKeys {
  static const String enabled = 'app_lock.enabled';
  static const String salt = 'app_lock.salt';
  static const String hash = 'app_lock.hash';
  static const String failCount = 'app_lock.failCount';
  static const String lockUntil = 'app_lock.lockUntil';
}

/// 启动锁服务：全部状态落在 SharedPreferences。
class AppLockService {
  AppLockService(this._prefs);

  final SharedPreferences _prefs;

  static AppLockService? _cached;

  /// 进程内缓存的实例（避免每次读锁都 await 插件）。
  static Future<AppLockService> cached() async =>
      _cached ??= AppLockService(await impl.appLockPrefs());

  /// 测试复位（清除进程缓存）。
  static void resetCache() => _cached = null;

  /// 本次冷启动是否已解锁（**内存态**，不落盘 → 重启后自然要求重新解锁）。
  static bool sessionUnlocked = false;

  bool get enabled => _prefs.getBool(AppLockKeys.enabled) ?? false;
  String? get saltHex => _prefs.getString(AppLockKeys.salt);
  String? get hashHex => _prefs.getString(AppLockKeys.hash);
  int get failCount => _prefs.getInt(AppLockKeys.failCount) ?? 0;
  int get lockUntilMs => _prefs.getInt(AppLockKeys.lockUntil) ?? 0;

  /// 冷却剩余毫秒（0 = 不在冷却中）。
  int cooldownRemainingMs([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final left = lockUntilMs - now;
    return left > 0 ? left : 0;
  }

  bool inCooldown([int? nowMs]) => cooldownRemainingMs(nowMs) > 0;

  /// 开启锁 / 重设 PIN。开启即视为本次启动已解锁（用户刚设完，不该被立刻锁住）。
  Future<void> setPin(String pin) async {
    validatePin(pin);
    final salt = generateSaltHex();
    await _prefs.setString(AppLockKeys.salt, salt);
    await _prefs.setString(AppLockKeys.hash, hashPin(pin, salt));
    await _prefs.setBool(AppLockKeys.enabled, true);
    await _prefs.setInt(AppLockKeys.failCount, 0);
    await _prefs.setInt(AppLockKeys.lockUntil, 0);
    sessionUnlocked = true;
  }

  /// 校验 PIN（含失败计数与冷却）。
  Future<bool> verify(String pin, {int? nowMs}) async {
    if (!enabled) return true;
    if (inCooldown(nowMs)) return false;
    final salt = saltHex;
    final stored = hashHex;
    if (salt == null || stored == null) return false;
    if (matchesPin(pin, salt, stored)) {
      await _prefs.setInt(AppLockKeys.failCount, 0);
      await _prefs.setInt(AppLockKeys.lockUntil, 0);
      sessionUnlocked = true;
      return true;
    }
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final next = failCount + 1;
    if (next >= kMaxPinFailures) {
      await _prefs.setInt(AppLockKeys.lockUntil,
          now + kPinCooldown.inMilliseconds);
      await _prefs.setInt(AppLockKeys.failCount, 0);
    } else {
      await _prefs.setInt(AppLockKeys.failCount, next);
    }
    return false;
  }

  /// 关闭锁：**必须先验证当前 PIN**（§S7.2）。验证失败返回 false 且不改状态。
  ///
  /// V2.8.3.4：关锁后把会话标记为**已解锁**（原实现置 false）。原因：
  /// `AppLockGate.load()` 的判据是 `enabled && !sessionUnlocked`，把
  /// `sessionUnlocked` 置回 false 会留下一个「enabled 还没写完、sessionUnlocked
  /// 已复位」的窗口 —— 此时任何一次 `load()`（开屏重播 / 自愈重启）都会算出
  /// `locked = true`，把已经关掉锁的用户弹回锁屏：他刚把锁关掉，输什么 PIN
  /// 都不对（salt/hash 已删），只能卡死在锁屏或看到空栈黑屏。
  /// 关锁即解锁是唯一自洽的语义。
  Future<bool> disable(String pin, {int? nowMs}) async {
    if (!enabled) return true;
    if (!await verify(pin, nowMs: nowMs)) return false;
    await _prefs.remove(AppLockKeys.salt);
    await _prefs.remove(AppLockKeys.hash);
    await _prefs.setInt(AppLockKeys.failCount, 0);
    await _prefs.setInt(AppLockKeys.lockUntil, 0);
    await _prefs.setBool(AppLockKeys.enabled, false);
    sessionUnlocked = true;
    // 同步进程内的门控缓存：关锁后 `locked` 必须立刻为 false，
    // 否则下一次 `AppLockGate.load()` 之前任何一次路由重定向都可能把用户
    // 推回锁屏（salt/hash 已删，输什么都进不去）。放在这里而不是只放在
    // 调用方，是为了「任何调用路径都不可能忘」。
    AppLockGate.locked = false;
    return true;
  }

  /// 清掉全部锁状态（仅供测试与「恢复出厂」使用；**不擦除任何业务数据**）。
  Future<void> wipe() async {
    for (final k in const [
      AppLockKeys.enabled,
      AppLockKeys.salt,
      AppLockKeys.hash,
      AppLockKeys.failCount,
      AppLockKeys.lockUntil,
    ]) {
      await _prefs.remove(k);
    }
    sessionUnlocked = false;
  }
}

/// 校验 PIN 形态：6 位纯数字。
void validatePin(String pin) {
  if (pin.length != kPinLength || int.tryParse(pin) == null) {
    throw ArgumentError('PIN 必须是 $kPinLength 位数字');
  }
}

/// 计算 PIN 哈希（十六进制）；[saltHex] 为随机盐。
String hashPin(String pin, String saltHex, {int iterations = kPinIterations}) {
  final salt = hexToBytes(saltHex);
  if (salt == null) throw ArgumentError('盐格式损坏');
  final out = pbkdf2HmacSha256(
    password: utf8.encode(pin),
    salt: salt,
    iterations: iterations,
    length: 32,
  );
  final sb = StringBuffer();
  for (final b in out) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// 常量时间比对（存储哈希 vs 现算哈希）。
bool matchesPin(String pin, String saltHex, String storedHash,
    {int iterations = kPinIterations}) {
  final stored = hexToBytes(storedHash);
  if (stored == null) return false; // 锁数据损坏 → 视为不匹配（不放行）
  return constantTimeEqualsBytes(stored, hexToBytes(hashPin(pin, saltHex, iterations: iterations))!);
}

/// 冷启动锁门控。
///
/// `GoRouter` 的 redirect 需要**同步**判断，因此这里用静态缓存承载
/// 「是否锁定」这一位状态。`load()` 在 `main()` 里于 `runApp` 之前调用
/// （V2.9.0 起唯一就绪时机）——深链冷启动（应用链接 / 浏览器 URL 直落
/// `/s/:token`、`/invite`）不经过开屏页，若依赖开屏页加载，redirect 会因
/// `ready == false` 放行，锁被整体绕过。开屏页仍保留一次幂等重读，
/// 供自愈重启整树 remount 后再武装。
abstract final class AppLockGate {
  static bool ready = false;
  static bool locked = false;

  /// 被锁拦截前的目的地（深链回跳用；解锁后由锁屏取出）。
  static String? _pendingLocation;

  /// 记录被锁打断的目的地；只接受应用内路径（`/` 开头且非 `/lock` 自身）。
  static void capturePendingLocation(String uri) {
    if (uri.isEmpty || !uri.startsWith('/') || uri.startsWith('/lock')) return;
    _pendingLocation = uri;
  }

  /// 取出并清除被锁打断的目的地（null = 没有记录，落回默认首页）。
  static String? takePendingLocation() {
    final v = _pendingLocation;
    _pendingLocation = null;
    return v;
  }

  /// 读取锁状态；任何平台异常（例如测试环境无插件）一律视为「不锁」。
  /// 2s 超时兜底：prefs 挂起时不能拖死首帧。
  static Future<bool> load({int? nowMs}) async {
    try {
      final svc =
          await AppLockService.cached().timeout(const Duration(seconds: 2));
      locked = svc.enabled && !AppLockService.sessionUnlocked;
    } catch (_) {
      locked = false;
    }
    ready = true;
    return locked;
  }

  /// 解锁成功（进入 App）。
  static void markUnlocked() {
    locked = false;
    AppLockService.sessionUnlocked = true;
  }

  /// 重新武装（关闭锁、退出登录等场景）：下次冷启动按最新配置判断。
  static void rearm() {
    locked = false;
    AppLockService.sessionUnlocked = false;
  }

  /// 测试复位。
  static void reset() {
    ready = false;
    locked = false;
    _pendingLocation = null;
    AppLockService.sessionUnlocked = false;
    AppLockService.resetCache();
  }
}
