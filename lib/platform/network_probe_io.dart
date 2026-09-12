/// 原生 / 桌面：按网络接口名启发式判定网络类型。
///
/// 判定口径（明确是**启发式**，不是权威结论）：
/// - 出现 Wi-Fi 类接口（`wlan*` / `wifi*` / iOS 的 `en0`）→ `wifi`；
/// - 否则出现蜂窝类接口（`rmnet*` / `ccmni*` / `pdp*` / `wwan*`）→ `mobile`；
/// - 其余（有线、命名异常、无接口、探测抛错）→ `unknown`，由门面 fail-open。
///
/// 先判 Wi-Fi 的原因：手机开热点/双栈时蜂窝接口往往仍挂载但非默认路由，
/// 若先判蜂窝会误报 `mobile` 而错误地阻断自动同步。
library;
import 'dart:io';

Future<String> probeNetKindName() async {
  try {
    final ifaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
    );
    final names =
        ifaces.map((i) => i.name.toLowerCase()).toList(growable: false);
    bool any(List<String> prefixes) =>
        names.any((n) => prefixes.any(n.startsWith));
    if (any(const ['wlan', 'wifi', 'en0'])) return 'wifi';
    if (any(const ['rmnet', 'ccmni', 'pdp', 'wwan', 'seth'])) return 'mobile';
    return 'unknown';
  } catch (_) {
    return 'unknown';
  }
}
