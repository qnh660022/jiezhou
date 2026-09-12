/// Web：浏览器不暴露网络类型（NetworkInformation 非标准且普遍缺失），
/// 恒返回 `unknown` 交由门面 fail-open；同步中心也会在 Web 端隐藏该开关。
library;

Future<String> probeNetKindName() async => 'unknown';
