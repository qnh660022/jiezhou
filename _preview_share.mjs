/**
 * 临时预览服务：本地模拟 Vercel rewrite（/s/:token → handler?token=），直接调 api/share.ts。
 * 运行：node _preview_share.mjs  （预览结束后删除本文件）
 * 端口 8123；mock RPC 数据：
 *   /s/11111111-... 行程   /s/22222222-... 账本
 *   /s/33333333-... 口令(正确口令 1234)   其他 token → 分享不存在
 */
process.env.SUPABASE_URL = 'https://mock.supabase.example';
process.env.SUPABASE_ANON_KEY = 'preview-only';

const TRIP = {
  ok: true, kind: 'trip',
  data: { trip: { name: '成都 5 日行程', destination: '四川 · 成都', emoji: '✈️', startEpochDay: 20646, endEpochDay: 20650, groupName: '家庭游' },
    items: [
      { dateEpochDay: 20646, name: '宽窄巷子', address: '青羊区金河路口', costCents: 12000 },
      { dateEpochDay: 20646, name: '人民公园 · 鹤鸣茶社', address: '青羊区少城路', costCents: 8000 },
      { dateEpochDay: 20647, name: '大熊猫繁育基地', address: '成华区外北熊猫大道', costCents: 5500 },
      { dateEpochDay: 20648, name: '都江堰半日游', address: '都江堰市公园路', costCents: null },
      { dateEpochDay: 20650, name: '返程', address: '天府机场', costCents: 0 },
    ] },
};
const GROUP = {
  ok: true, kind: 'group',
  data: { group: { name: '新疆自驾', icon: '🚗' },
    members: [{ name: '阿明' }, { name: '小周' }, { name: '老王' }, { name: '莉莉' }, { name: '大熊' }, { name: '阿宅' }, { name: '七号' }],
    expenses: [
      { title: '晚饭 · 大盘鸡', categoryKey: 'food', amountCents: -5800 },
      { title: '赛里木湖门票', categoryKey: 'ticket', amountCents: 12345 },
      { title: '油费 AA', categoryKey: 'transport', amountCents: 30000 },
      { title: '民宿退款', categoryKey: 'hotel', amountCents: -15600 },
      { title: '零食补给', categoryKey: 'shopping', amountCents: 9200 },
    ],
    settlements: [
      { transfersJson: '[{"from":"阿明","to":"小周","amountCents":12000},{"from":"老王","to":"莉莉","amountCents":5400}]', roundNo: 3, createdMs: 1757400000000 },
      { transfersJson: '[{"from":"大熊","to":"阿明","amountCents":8800}]', roundNo: 2, createdMs: 1757300000000 },
    ] },
};
const T1 = '11111111-1111-1111-1111-111111111111';
const T2 = '22222222-2222-2222-2222-222222222222';
const T3 = '33333333-3333-3333-3333-333333333333';

globalThis.fetch = async (_url, init) => {
  const body = JSON.parse(init?.body ?? '{}');
  let payload;
  if (body.token === T1) payload = TRIP;
  else if (body.token === T2) payload = GROUP;
  else if (body.token === T3) payload = body.pass == null ? { ok: false, error: 'need_pass' }
    : body.pass === '1234' ? { ok: true, kind: 'trip', data: TRIP.data } : { ok: false, error: 'bad_pass' };
  else payload = { ok: false, error: 'not_found' };
  return new Response(JSON.stringify(payload), { status: 200 });
};

const { default: handler } = await import('./api/share.ts');
const http = await import('node:http');

http.createServer(async (req, res) => {
  try {
    const u = new URL(req.url, 'http://localhost:8123');
    const m = /^\/s\/([0-9a-fA-F-]{36})$/.exec(u.pathname);
    if (!m) { res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' }); res.end('try /s/11111111-1111-1111-1111-111111111111'); return; }
    // 模拟 vercel.json rewrite：/s/:token → /api/share?token=:token
    const url = `http://localhost:8123/s/${m[1]}?token=${m[1]}`;
    const headers = { ...req.headers, host: 'localhost:8123' };
    delete headers.connection;
    const body = req.method === 'POST'
      ? await new Promise((resolve) => { let d = ''; req.on('data', (c) => (d += c)); req.on('end', () => resolve(d)); })
      : undefined;
    const request = new Request(url, { method: req.method, headers, body, redirect: 'manual' });
    const response = await handler(request);
    const out = { ...Object.fromEntries(response.headers) };
    for (const c of response.headers.getSetCookie?.() ?? []) res.setHeader('set-cookie', c);
    res.writeHead(response.status, out);
    res.end(await response.text());
  } catch (e) {
    res.writeHead(500, { 'content-type': 'text/plain; charset=utf-8' });
    res.end('preview error: ' + e.message);
  }
}).listen(8123, () => console.log('preview ready on http://localhost:8123'));
