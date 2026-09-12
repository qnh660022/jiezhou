/**
 * 方案 B：/s/<token> SSR 轻量分享页（Vercel Edge Function · 零依赖单文件）
 *
 * - 路由：vercel.json 将 `/s/:token` rewrite 到 `/api/share?token=:token`。
 * - 零 npm 依赖：只用 Web 标准 API（fetch / URL / Request / Response / formData），
 *   不引入 Supabase SDK（一次 RPC POST 足矣）。
 * - SUPABASE_URL / SUPABASE_ANON_KEY 只从服务端环境变量读取，
 *   硬性要求：任何情况下不得把这两个值写入 HTML 响应体、错误信息或日志。
 * - 文案为简体中文硬编码（与 App 一致），不做 i18n。
 *
 * 分节：token 校验 / RPC 调用 / cookie / 防爆破 / 渲染 / 模板。
 */

export const config = { runtime: 'edge' };

// ============================================================================
// 常量
// ============================================================================

/** App 推广落地页（决策 #12：代码内常量） */
const PROMO_URL = 'https://jiezhou.22006.dpdns.org';

const PASS_COOKIE = 'share_pass';
const COOKIE_MAX_AGE = 1800; // 30 分钟（决策 #3）

const TOKEN_RE =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
const PASS_RE = /^\d{4}$/;

/** 主色对齐 App 默认绿（决策 #7：固定浅色，不响应系统深色模式） */
const COLOR_PRIMARY = '#00A878';
const COLOR_INCOME = '#1E9E6A';

const NEUTRAL_TITLE = '芥舟 · 只读分享';
const NEUTRAL_DESC = '来自芥舟 · 旅途助手的分享';

// ============================================================================
// RPC 调用
// ============================================================================

type RpcOutcome =
  | { kind: 'ok'; shareKind: 'trip' | 'group'; data: SnapshotData }
  | { kind: 'not_found' | 'need_pass' | 'bad_pass' | 'env_error' | 'rpc_error' };

/** RPC 返回数据（宽松可选，渲染函数内部判空兜底） */
interface SnapshotData {
  trip?: { name?: string; destination?: string; emoji?: string; groupName?: string;
           startEpochDay?: number | null; endEpochDay?: number | null };
  items?: { dateEpochDay?: number | null; name?: string; address?: string | null;
            costCents?: number | null }[];
  group?: { name?: string; icon?: string };
  members?: { name?: string }[];
  expenses?: { title?: string; categoryKey?: string; amountCents?: number }[];
  settlements?: { transfersJson?: string; roundNo?: number }[];
}

/**
 * 调用 get_share_snapshot（security definer，匿名可调）。
 * 失败时 HTTP 仍为 200，看 body 里的 ok / error 字段。
 */
async function callSnapshotRpc(token: string, pass: string | null): Promise<RpcOutcome> {
  const supabaseUrl = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  // 缺失时只 WARN，绝不输出变量值本身
  if (!supabaseUrl || !anonKey) {
    console.warn('share: SUPABASE_URL / SUPABASE_ANON_KEY env missing');
    return { kind: 'env_error' };
  }
  try {
    const res = await fetch(`${supabaseUrl}/rest/v1/rpc/get_share_snapshot`, {
      method: 'POST',
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ token, pass }),
    });
    if (!res.ok) return { kind: 'rpc_error' };
    const body = await res.json();
    if (body && body.ok === true) {
      return {
        kind: 'ok',
        shareKind: body.kind === 'group' ? 'group' : 'trip',
        data: body.data ?? {},
      };
    }
    const err = body && typeof body.error === 'string' ? body.error : '';
    if (err === 'not_found') return { kind: 'not_found' };
    if (err === 'need_pass') return { kind: 'need_pass' };
    if (err === 'bad_pass') return { kind: 'bad_pass' };
    return { kind: 'rpc_error' };
  } catch {
    return { kind: 'rpc_error' };
  }
}

// ============================================================================
// token 校验
// ============================================================================

function isValidToken(token: string): boolean {
  return TOKEN_RE.test(token);
}

// ============================================================================
// cookie（口令短期记忆）
// ============================================================================

/**
 * 口令 cookie 取舍说明：get_share_snapshot RPC 每次调用都必须携带 pass，
 * 无法用独立的「已验证凭据」替代；口令本身是低敏感的 4 位数字，
 * HttpOnly + Secure + SameSite=Lax + 30 分钟 + Path 限定到单条链接已足够。
 * Path=/s/<token> 天然按链接隔离，多个分享链接互不串。
 */
function passCookieHeader(token: string, pass: string): string {
  return (
    `${PASS_COOKIE}=${pass}; HttpOnly; Secure; SameSite=Lax; ` +
    `Path=/s/${token}; Max-Age=${COOKIE_MAX_AGE}`
  );
}

function clearPassCookieHeader(token: string): string {
  return `${PASS_COOKIE}=; HttpOnly; Secure; SameSite=Lax; Path=/s/${token}; Max-Age=0`;
}

/** 读 Path 匹配的 share_pass cookie（浏览器只会带上路径匹配的cookie） */
function readPassCookie(request: Request): string | null {
  const raw = request.headers.get('cookie');
  if (!raw) return null;
  for (const part of raw.split(';')) {
    const i = part.indexOf('=');
    if (i < 0) continue;
    if (part.slice(0, i).trim() === PASS_COOKIE) {
      const v = part.slice(i + 1).trim();
      return v || null;
    }
  }
  return null;
}

// ============================================================================
// 口令防爆破（内存级，尽力而为）
// ============================================================================

/**
 * 认知声明：Edge Function 多实例不共享内存，此防护是「尽力而为」，
 * 可拦住绝大多数脚本化尝试，不承诺绝对防爆破；
 * 最终兜底是服务端口令校验成本与 Supabase 自身限流。
 */
const bruteMap = new Map<string, { fails: number; lockUntil: number }>();
const FAIL_LIMIT = 5; // 同 token+IP 连续错 5 次
const LOCK_MS = 10 * 60 * 1000; // 锁 10 分钟
const BRUTE_MAX_ENTRIES = 1000;

/** IP 取 x-forwarded-for 首段，取不到用 x-real-ip，再取不到用 unknown */
function clientIp(request: Request): string {
  const xff = request.headers.get('x-forwarded-for');
  if (xff) {
    const first = xff.split(',')[0].trim();
    if (first) return first;
  }
  return request.headers.get('x-real-ip')?.trim() || 'unknown';
}

function bruteKey(request: Request, token: string): string {
  return `${token}|${clientIp(request)}`;
}

function isLocked(key: string): boolean {
  const e = bruteMap.get(key);
  return !!e && e.lockUntil > Date.now();
}

function recordFail(key: string): void {
  shrinkBruteMap();
  const e = bruteMap.get(key) ?? { fails: 0, lockUntil: 0 };
  e.fails += 1;
  if (e.fails >= FAIL_LIMIT) {
    e.lockUntil = Date.now() + LOCK_MS;
    e.fails = 0; // 锁定后重新计数，解锁后重新累计
  }
  bruteMap.set(key, e);
}

function clearFails(key: string): void {
  bruteMap.delete(key);
}

/** Map 防膨胀：条目数超过 1000 时先清已过期项，仍超则删最旧 */
function shrinkBruteMap(): void {
  if (bruteMap.size <= BRUTE_MAX_ENTRIES) return;
  const now = Date.now();
  for (const [k, v] of bruteMap) {
    if (v.lockUntil <= now) bruteMap.delete(k);
  }
  while (bruteMap.size > BRUTE_MAX_ENTRIES) {
    const oldest = bruteMap.keys().next().value;
    if (oldest === undefined) break;
    bruteMap.delete(oldest);
  }
}

// ============================================================================
// 渲染
// ============================================================================

/** HTML 转义（硬性安全要求：所有动态文本来自用户输入） */
function esc(v: unknown): string {
  return String(v ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** epochDay → 「M月d日」，按 UTC 取年月日（与 App 的 isUtc: true 一致） */
function fmtDay(epochDay: number): string {
  const d = new Date(epochDay * 86400000);
  return `${d.getUTCMonth() + 1}月${d.getUTCDate()}日`;
}

/** 行程条目右侧金额：¥ + 整数；null 不显示 */
function costHtml(cents: unknown): string {
  if (typeof cents !== 'number') return '';
  return `<span class="cost">¥${(cents / 100).toFixed(0)}</span>`;
}

/**
 * 账单金额：支出为正（黑色 ¥xx.xx）、收入为负
 * （前缀「-」+ 收入绿 #1E9E6A，abs/100 保留两位小数）
 */
function amountHtml(cents: unknown): string {
  if (typeof cents !== 'number') return '';
  if (cents < 0) {
    return `<span class="cost income">-¥${(Math.abs(cents) / 100).toFixed(2)}</span>`;
  }
  return `<span class="cost">¥${(cents / 100).toFixed(2)}</span>`;
}

/** 内容页动态 og/title（内容页才输出动态摘要） */
function metaFor(shareKind: 'trip' | 'group', data: SnapshotData): { title: string; desc: string } {
  if (shareKind === 'trip') {
    const t = data.trip ?? {};
    let title = [t.emoji, t.name].filter(Boolean).map((x) => String(x)).join(' ');
    if (t.destination) title += ` · ${t.destination}`;
    const s = t.startEpochDay;
    const e = t.endEpochDay;
    // start/end 均有效才拼日期段
    const desc =
      typeof s === 'number' && typeof e === 'number'
        ? `${e - s + 1}日行程 ${fmtDay(s)}–${fmtDay(e)}`
        : NEUTRAL_DESC;
    return { title, desc };
  }
  const g = data.group ?? {};
  const title = [g.icon, g.name].filter(Boolean).map((x) => String(x)).join(' ') + ' · 共享账本';
  const memberCount = Array.isArray(data.members) ? data.members.length : 0;
  const billCount = Array.isArray(data.expenses) ? data.expenses.length : 0;
  return { title, desc: `${memberCount}位成员 · 共${billCount}笔账单` };
}

function tripBody(data: SnapshotData): string {
  const t = data.trip ?? {};
  let html = `<section class="cover"><h1>${esc(
    [t.emoji, t.name].filter(Boolean).join(' ')
  )}</h1>`;
  if (t.destination) html += `<p class="dest">${esc(t.destination)}</p>`;
  if (t.groupName) html += `<p class="group">与「${esc(t.groupName)}」同行</p>`;
  html += '</section>';

  const items = Array.isArray(data.items) ? data.items : [];
  if (!items.length) {
    html += '<div class="empty">暂无行程安排</div>';
  }
  for (const it of items) {
    // 副标：{M月d日} · {address}，空段跳过，分隔符「 · 」
    const segs: string[] = [];
    if (typeof it.dateEpochDay === 'number') segs.push(fmtDay(it.dateEpochDay));
    if (it.address) segs.push(String(it.address));
    const sub = segs.map((x) => esc(x)).join(' · ');
    html += `<div class="card"><div class="main"><div class="t">${esc(it.name)}</div>${
      sub ? `<div class="s">${sub}</div>` : ''
    }</div>${costHtml(it.costCents)}</div>`;
  }
  return html;
}

function groupBody(data: SnapshotData): string {
  const g = data.group ?? {};
  let html = `<section class="cover"><h1>${esc(
    [g.icon, g.name].filter(Boolean).join(' ')
  )}</h1></section>`;

  const members = Array.isArray(data.members) ? data.members : [];
  if (members.length) {
    html += `<p class="members">成员：${members.map((m) => esc(m?.name)).join('、')}</p>`;
  }

  html += '<div class="sec">账单明细</div>';
  const expenses = Array.isArray(data.expenses) ? data.expenses : [];
  if (!expenses.length) {
    html += '<div class="empty">暂无账单</div>';
  }
  for (const ex of expenses) {
    html += `<div class="card"><div class="main"><div class="t">${esc(ex.title)}</div>${
      ex.categoryKey ? `<div class="s">${esc(ex.categoryKey)}</div>` : ''
    }</div>${amountHtml(ex.amountCents)}</div>`;
  }

  // settlements 已是最近 10 条；transfersJson 转义后原样展示，不解析、不美化
  const settlements = Array.isArray(data.settlements) ? data.settlements : [];
  if (settlements.length) {
    html += '<div class="sec">近期结算</div>';
    for (const st of settlements) {
      html += `<div class="card"><div class="s">${esc(`第 ${st.roundNo} 轮 · ${st.transfersJson}`)}</div></div>`;
    }
  }
  return html;
}

function passBody(path: string, error = ''): string {
  // 口令页不得暴露任何内容信息：无行程/账本名称，og 用中性文案
  return `<section class="pass">
<h1>输入 4 位口令</h1>
<form method="post" action="${esc(path)}">
<input type="password" name="pass" inputmode="numeric" maxlength="4" autocomplete="off" autofocus>
<p class="err-line">${esc(error)}</p>
<button type="submit">验证</button>
</form>
</section>`;
}

/** 错误 / 锁定页：居中内联 SVG 图标（无外部图片资源）+ 一行文案 */
function noticeBody(text: string): string {
  return `<section class="err">
<svg width="52" height="52" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><circle cx="12" cy="12" r="10" stroke="${COLOR_PRIMARY}" stroke-width="1.6"/><path d="M6.5 12c1.6-2.4 2.9-2.4 4.5 0s2.9 2.4 4.5 0" stroke="${COLOR_PRIMARY}" stroke-width="1.6" stroke-linecap="round"/></svg>
<p>${esc(text)}</p>
</section>`;
}

/** 页脚：推广位（品牌行上方）+ 品牌行，所有页面统一 */
function footerHtml(): string {
  return `<footer>
<a class="promo" href="${esc(PROMO_URL)}" target="_blank" rel="noopener">用芥舟 App，旅行记账更轻松 →</a>
<p class="brand">由芥舟 · 旅途助手生成，内容来自分享者</p>
</footer>`;
}

// ============================================================================
// 模板
// ============================================================================

const STYLE = `
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,'PingFang SC','Microsoft YaHei',sans-serif;background:#f4f6f5;color:#1f2d28;line-height:1.55}
.wrap{max-width:640px;margin:0 auto;padding:22px 16px 10px}
.cover{border-left:4px solid ${COLOR_PRIMARY};padding-left:12px;margin-bottom:6px}
.cover h1{font-size:21px;font-weight:700;word-break:break-all}
.cover .dest{color:#6b7a74;font-size:15px;margin-top:2px}
.cover .group{color:#8a9993;font-size:13px;margin-top:4px}
.members{color:#7c8a84;font-size:13px;margin:2px 0 0 16px}
.sec{margin:20px 4px 0;font-size:13px;color:#7c8a84;font-weight:600}
.card{background:#fff;border:1px solid #e3e9e6;border-radius:12px;padding:12px 14px;margin-top:10px;display:flex;justify-content:space-between;gap:12px;align-items:baseline}
.card .main{min-width:0}
.card .t{font-size:15px;font-weight:600;word-break:break-all}
.card .s{color:#7c8a84;font-size:13px;margin-top:3px;word-break:break-all}
.cost{font-weight:600;white-space:nowrap;color:#1f2d28}
.cost.income{color:${COLOR_INCOME}}
.empty{text-align:center;color:#8a9993;padding:36px 0;font-size:14px}
.err{text-align:center;padding:64px 0}
.err p{margin-top:12px;color:#5b6b64;font-size:15px}
.pass{background:#fff;border:1px solid #e3e9e6;border-radius:12px;padding:24px 18px;margin-top:14px;text-align:center}
.pass h1{font-size:18px}
.pass input{margin:16px auto 4px;display:block;width:150px;text-align:center;font-size:22px;letter-spacing:8px;border:1px solid #d6ded9;border-radius:10px;padding:10px 8px;outline:none;color:#1f2d28}
.pass input:focus{border-color:${COLOR_PRIMARY}}
.pass button{margin-top:12px;background:${COLOR_PRIMARY};color:#fff;border:0;border-radius:10px;padding:10px 34px;font-size:15px;cursor:pointer}
.err-line{color:#d05a4e;font-size:13px;min-height:18px;margin-top:6px}
footer{max-width:640px;margin:0 auto;padding:6px 16px 28px;text-align:center}
.promo{display:block;margin-bottom:10px;font-size:14px;color:${COLOR_PRIMARY};text-decoration:none;background:#f0faf6;border:1px solid #cde9df;border-radius:999px;padding:8px 14px}
.brand{font-size:12px;color:#9aa8a2}
`;

function htmlPage(
  bodyHtml: string,
  meta: { title: string; desc: string },
  extraHeaders: Record<string, string> = {}
): Response {
  const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(meta.title)}</title>
<meta property="og:title" content="${esc(meta.title)}">
<meta property="og:description" content="${esc(meta.desc)}">
<meta name="twitter:card" content="summary">
<style>${STYLE}</style>
</head>
<body>
<main class="wrap">
${bodyHtml}
</main>
${footerHtml()}
</body>
</html>`;
  return new Response(html, {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
      ...extraHeaders,
    },
  });
}

// ============================================================================
// 请求处理
// ============================================================================

export default async function handler(request: Request): Promise<Response> {
  const token = new URL(request.url).searchParams.get('token') ?? '';
  const path = `/s/${token}`;

  // ---------- GET ----------
  if (request.method === 'GET') {
    // 1) token UUID 格式校验，不合规直接按 not_found 处理（不调 RPC）
    if (!isValidToken(token)) {
      return htmlPage(noticeBody('分享不存在或已被撤销'), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
    }
    // 2) 防爆破锁定期内一律渲染锁定提示，不调 RPC
    const key = bruteKey(request, token);
    if (isLocked(key)) {
      return htmlPage(noticeBody('尝试次数过多，请 10 分钟后再试'), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
    }
    // 3) 读 cookie → 用它作 pass 调 RPC；无 cookie 则 pass 传 null
    const cookiePass = readPassCookie(request);
    const outcome = await callSnapshotRpc(token, cookiePass);
    if (outcome.kind === 'ok') {
      if (cookiePass) clearFails(key); // 带 cookie GET ok → 口令验证成功，清零
      const meta = metaFor(outcome.shareKind, outcome.data);
      const body =
        outcome.shareKind === 'group' ? groupBody(outcome.data) : tripBody(outcome.data);
      return htmlPage(body, meta);
    }
    if (outcome.kind === 'bad_pass') {
      // cookie 里的口令已失效/错误 → 清 cookie + 表单页
      return htmlPage(passBody(path, '口令不正确'), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC }, {
        'Set-Cookie': clearPassCookieHeader(token),
      });
    }
    if (outcome.kind === 'need_pass') {
      return htmlPage(passBody(path), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
    }
    if (outcome.kind === 'not_found') {
      return htmlPage(noticeBody('分享不存在或已被撤销'), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
    }
    // env_error / rpc_error（网络异常 / RPC 非 200）
    return htmlPage(noticeBody('加载失败，请稍后重试'), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
  }

  // ---------- POST（口令表单提交） ----------
  if (request.method === 'POST') {
    if (!isValidToken(token)) {
      return htmlPage(noticeBody('分享不存在或已被撤销'), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
    }
    const key = bruteKey(request, token);
    if (isLocked(key)) {
      return htmlPage(noticeBody('尝试次数过多，请 10 分钟后再试'), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
    }
    // 1) 本地校验 ^\d{4}$，不合规直接回表单页（不调 RPC）
    let pass = '';
    try {
      const form = await request.formData();
      pass = String(form.get('pass') ?? '').trim();
    } catch {
      pass = '';
    }
    if (!PASS_RE.test(pass)) {
      return htmlPage(passBody(path, '请输入 4 位数字口令'), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
    }
    // 2) 调 RPC 校验
    const outcome = await callSnapshotRpc(token, pass);
    if (outcome.kind === 'ok') {
      // PRG 模式：下发口令 cookie + 303 See Other，防刷新重复提交
      clearFails(key);
      return new Response(null, {
        status: 303,
        headers: {
          Location: path,
          'Set-Cookie': passCookieHeader(token, pass),
          'Cache-Control': 'no-store',
        },
      });
    }
    if (outcome.kind === 'bad_pass') {
      recordFail(key);
      return htmlPage(passBody(path, '口令不正确'), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
    }
    if (outcome.kind === 'need_pass') {
      return htmlPage(passBody(path), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
    }
    if (outcome.kind === 'not_found') {
      return htmlPage(noticeBody('分享不存在或已被撤销'), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
    }
    return htmlPage(noticeBody('加载失败，请稍后重试'), { title: NEUTRAL_TITLE, desc: NEUTRAL_DESC });
  }

  // 其他方法不接受
  return new Response(null, {
    status: 405,
    headers: { Allow: 'GET, POST', 'Cache-Control': 'no-store' },
  });
}
