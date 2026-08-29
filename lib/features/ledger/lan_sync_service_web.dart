/// Web：局域网同步占位实现。浏览器无法绑定 UDP 广播/端口，此处所有能力
/// 均标记为不支持，调用时抛 [UnsupportedError]，界面捕获后提示用户改用
/// 备份文件（.tav/.tat）与手机端互传同步。
library;

class LanPeer {
  const LanPeer({required this.ip, required this.port});
  final String ip;
  final int port;
}

class LanSyncManager {
  Future<String> Function()? snapshotProvider;
  Future<String> Function(String raw)? snapshotMerger;

  Future<(String, int, List<String>)> startHost({
    required Future<String> Function() snapshotProvider,
    required Future<String> Function(String) snapshotMerger,
    int httpPort = 45681,
  }) async {
    throw UnsupportedError('网页版不支持局域网同步，请改用备份文件互传');
  }

  Future<void> dispose() async {}

  Future<LanPeer> discoverHost(
    String code, {
    String? manualIp,
    int manualPort = 45681,
  }) async {
    throw UnsupportedError('网页版不支持局域网同步，请改用备份文件互传');
  }

  Future<String> pullSnapshot(LanPeer peer) async {
    throw UnsupportedError('网页版不支持局域网同步，请改用备份文件互传');
  }

  Future<String> pushSnapshot(LanPeer peer, String snapshotJson) async {
    throw UnsupportedError('网页版不支持局域网同步，请改用备份文件互传');
  }
}