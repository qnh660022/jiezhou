/// 旅途哲理文案：仅在 UI 展示（我的页底部 / AI 思考中），绝不作为上下文喂给模型。
library;

final List<({String text, String by})> travelQuotes = [
  (text: '真正的旅程，在回程那天才开始。那些路上的念头，会在生活里悄悄开花。', by: '随记'),
  (text: '你走过的路，终会成为你看世界的眼神。', by: '随记'),
  (text: '旅途不是逃离，而是换个地方，重新学会生活。', by: '随记'),
  (text: '风景是借来的，回忆才真正属于自己。', by: '随记'),
  (text: '出发的人未必勇敢，但回来的人多半温柔。', by: '随记'),
  (text: '世界是本书，不旅行的人只读了其中一页。', by: '奥古斯丁'),
  (text: '愿你看过山海，仍能为一碗热汤停留。', by: '随记'),
  (text: '脚步丈量过的地方，心也就宽了几寸。', by: '随记'),
  (text: '去远方，是为了看清身边一直存在的美好。', by: '随记'),
  (text: '人生最好的状态，是在路上，也在回家的路上。', by: '随记'),
  (text: '把日常过成诗的人，走到哪里都是远方。', by: '随记'),
  (text: '地图的边界，是欲望的起点，也是勇气的终点。', by: '随记'),
  (text: '有些风景看了就忘，有些路标却跟一辈子。', by: '随记'),
  (text: '别让目的地，夺走沿途所有的可能性。', by: '随记'),
  (text: '旅行的意义，是学会与自己久别重逢。', by: '随记'),
];

/// 随机取一条旅途文案（每次调用不同，配合 UI 刷新即可“每次都不一样”）。
({String text, String by}) randomTravelQuote() {
  final q = travelQuotes[_rand.nextInt(travelQuotes.length)];
  return (text: q.text, by: q.by);
}

final _rand = _Rand();
/// 轻量自给自足随机源（避免对 dart:math 做全局单例依赖，保持纯文本可测试）。
class _Rand {
  int _x = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  int nextInt(int n) {
    _x = (_x * 1103515245 + 12345) & 0x7fffffff;
    return _x % n;
  }
}