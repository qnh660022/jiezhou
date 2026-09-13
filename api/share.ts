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

/** 主色对齐 App 默认绿（决策 #7：固定浅色，不响应系统深色模式）；收入绿见 CSS --income */
const COLOR_PRIMARY = '#00A878';

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

/** 行程条目右侧金额：¥ + 整数，绿色胶囊；null 不显示 */
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
    return `<span class="amt income">-¥${(Math.abs(cents) / 100).toFixed(2)}</span>`;
  }
  return `<span class="amt">¥${(cents / 100).toFixed(2)}</span>`;
}

/** 周X（按 UTC，纯展示）；hero 日期胶囊 / 日分组头部共用 */
const WEEKDAYS = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

function dayChipHtml(epochDay: number): string {
  const d = new Date(epochDay * 86400000);
  return `<div class="day-chip">${esc(fmtDay(epochDay))} ${WEEKDAYS[d.getUTCDay()]}</div>`;
}

/** 类别图标（仅视觉映射，categoryKey 原文仍照常展示，未知回退 🧾） */
const CATEGORY_ICONS: Record<string, string> = {
  food: '🍜', transport: '🚌', hotel: '🏨', ticket: '🎫', shopping: '🛍️',
  play: '🎮', medical: '💊', flight: '✈️', train: '🚄', living: '🏠', other: '🧾',
};

function catIcon(key: unknown): string {
  return CATEGORY_ICONS[String(key ?? '').trim().toLowerCase()] ?? '🧾';
}

/** 成员头像色板（与 App 主题种子色同源，按下标循环取用） */
const MEMBER_COLORS = ['#00A878', '#2F80ED', '#F2994A', '#F06B9C', '#7B61FF', '#E0B14B'];

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
  let hero = '<header class="hero">';
  if (t.emoji) hero += `<div class="badge">${esc(t.emoji)}</div>`;
  hero += `<h1>${esc(t.name)}</h1>`;
  if (t.destination) hero += `<p class="dest">📍 ${esc(t.destination)}</p>`;
  // 日期胶囊：start/end 均有效才显示（既有字段纯展示，不新增数据）
  const s = t.startEpochDay;
  const e = t.endEpochDay;
  if (typeof s === 'number' && typeof e === 'number') {
    hero += `<div class="pill">${esc(fmtDay(s))} – ${esc(fmtDay(e))}</div>`;
  }
  if (t.groupName) hero += `<p class="with">与「${esc(t.groupName)}」同行</p>`;
  hero += '</header>';

  const items = Array.isArray(data.items) ? data.items : [];
  let inner = '';
  if (!items.length) {
    inner = '<div class="empty"><div class="ico">🗺️</div><p>暂无行程安排</p></div>';
  } else {
    // 按日期分组（items 已按 dateEpochDay, sortOrder 排序，相邻同日即同组；null 归「日期待定」）
    type Item = NonNullable<SnapshotData['items']>[number];
    const groups: { day: number | null; items: Item[] }[] = [];
    for (const it of items) {
      const day = typeof it.dateEpochDay === 'number' ? it.dateEpochDay : null;
      const last = groups[groups.length - 1];
      if (last && last.day === day) last.items.push(it);
      else groups.push({ day, items: [it] });
    }
    for (const g of groups) {
      inner += g.day == null ? '<div class="day-chip">日期待定</div>' : dayChipHtml(g.day);
      inner += '<div class="tl">';
      for (const it of g.items) {
        // 副标：地址（日期上移到分组胶囊；空段跳过）
        const sub = it.address ? `<div class="s">${esc(it.address)}</div>` : '';
        inner += `<div class="item"><div class="main"><div class="t">${esc(it.name)}</div>${sub}</div>${costHtml(it.costCents)}</div>`;
      }
      inner += '</div>';
    }
  }
  return `${hero}<main class="wrap"><div class="sheet">${inner}</div></main>`;
}

function groupBody(data: SnapshotData): string {
  const g = data.group ?? {};
  let hero = '<header class="hero">';
  if (g.icon) hero += `<div class="badge">${esc(g.icon)}</div>`;
  hero += `<h1>${esc(g.name)}</h1>`;

  const members = Array.isArray(data.members) ? data.members : [];
  if (members.length) {
    // 头像圆点：背景色按 colorIndex 从色板取值（纯视觉），白色首字，最多显示 5 个
    hero += '<div class="avatars">';
    const shown = members.slice(0, 5);
    for (let i = 0; i < shown.length; i++) {
      const name = String(shown[i]?.name ?? '').trim();
      const color = MEMBER_COLORS[i % MEMBER_COLORS.length];
      hero += `<div class="ava" style="background:${color}">${esc(name.slice(0, 1) || '·')}</div>`;
    }
    if (members.length > 5) {
      hero += `<div class="ava more">+${members.length - 5}</div>`;
    }
    hero += '</div>';
    hero += `<p class="ava-names">成员：${members.map((m) => esc(m?.name)).join('、')}</p>`;
  }
  hero += '</header>';

  let inner = '<div class="sec">账单明细</div>';
  const expenses = Array.isArray(data.expenses) ? data.expenses : [];
  if (!expenses.length) {
    inner += '<div class="empty"><div class="ico">💤</div><p>暂无账单</p></div>';
  }
  for (const ex of expenses) {
    // categoryKey 原文展示不变；左侧图标仅视觉映射
    inner += `<div class="bill"><div class="ico">${catIcon(ex.categoryKey)}</div><div class="main"><div class="t">${esc(ex.title)}</div>${
      ex.categoryKey ? `<div class="s">${esc(ex.categoryKey)}</div>` : ''
    }</div>${amountHtml(ex.amountCents)}</div>`;
  }

  // settlements 已是最近 10 条；transfersJson 美化为「A → B ¥xx.xx」转账行，
  // 解析失败 / 结构异常时回退转义原文（不丢兜底）；from/to 均为用户输入，全部转义
  const settlements = Array.isArray(data.settlements) ? data.settlements : [];
  if (settlements.length) {
    inner += '<div class="sec">近期结算</div>';
    for (const st of settlements) {
      let rows = '';
      try {
        const v = JSON.parse(String(st.transfersJson ?? ''));
        if (Array.isArray(v) && v.length && v.every((x) => x && typeof x === 'object')) {
          rows = v
            .map((tr) => {
              const cents = typeof tr.amountCents === 'number' ? tr.amountCents : 0;
              return `<div class="tr-row"><span class="tr-people">${esc(tr.from)} <i>→</i> ${esc(tr.to)}</span><span class="tr-amt">¥${(cents / 100).toFixed(2)}</span></div>`;
            })
            .join('');
        }
      } catch {
        rows = '';
      }
      inner += `<div class="settle"><div class="ico">🤝</div><div class="main"><div class="round">${esc(`第 ${st.roundNo} 轮`)}</div>${
        rows || `<div class="txt">${esc(st.transfersJson)}</div>`
      }</div></div>`;
    }
  }
  return `${hero}<main class="wrap"><div class="sheet">${inner}</div></main>`;
}

function passBody(path: string, error = ''): string {
  // 口令页不得暴露任何内容信息：无行程/账本名称，og 用中性文案
  return `<main class="narrow"><section class="pass">
<div class="lock">🔒</div>
<h1>输入 4 位口令</h1>
<form method="post" action="${esc(path)}">
<input type="password" name="pass" inputmode="numeric" maxlength="4" autocomplete="off" autofocus>
<p class="err-line">${esc(error)}</p>
<button type="submit">验证</button>
</form>
</section></main>`;
}

/** 错误 / 锁定页：浅绿圆徽章内联 SVG 波浪线（无外部图片资源）+ 一行文案 */
function noticeBody(text: string): string {
  return `<main class="notice-wrap"><section class="err">
<div class="err-ico"><svg width="34" height="34" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><circle cx="12" cy="12" r="10" stroke="${COLOR_PRIMARY}" stroke-width="1.6"/><path d="M6.5 12c1.6-2.4 2.9-2.4 4.5 0s2.9 2.4 4.5 0" stroke="${COLOR_PRIMARY}" stroke-width="1.6" stroke-linecap="round"/></svg></div>
<p>${esc(text)}</p>
</section></main>`;
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
:root{--brand:#00A878;--brand-deep:#007F5C;--grad:linear-gradient(135deg,#00B386,#007F5C);
--bg:#F2F6F4;--card:#fff;--line:#E6EDE9;--ink:#1C2B26;--ink2:#66756E;--ink3:#8A9992;
--income:#1E9E6A;--err:#D05A4E;--shadow:0 8px 24px rgba(0,60,40,.10)}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,'PingFang SC','Microsoft YaHei',sans-serif;background:var(--bg);color:var(--ink);line-height:1.55;-webkit-font-smoothing:antialiased}

/* ---- Hero 封面（满宽渐变，白卡上浮） ---- */
.hero{background:var(--grad);padding:40px 20px 72px;text-align:center;color:#fff}
.hero .badge{width:64px;height:64px;border-radius:999px;background:rgba(255,255,255,.22);display:flex;align-items:center;justify-content:center;font-size:34px;margin:0 auto 12px}
.hero h1{font-size:26px;font-weight:700;word-break:break-all;max-width:600px;margin:0 auto}
.hero .dest{color:rgba(255,255,255,.85);font-size:15px;margin-top:6px}
.hero .pill{display:inline-block;background:rgba(255,255,255,.2);border-radius:999px;padding:5px 14px;font-size:13px;margin-top:12px}
.hero .with{color:rgba(255,255,255,.75);font-size:13px;margin-top:10px}
.hero .avatars{display:flex;justify-content:center;align-items:center;margin-top:14px}
.hero .ava{width:36px;height:36px;border-radius:999px;color:#fff;font-size:14px;font-weight:600;display:flex;align-items:center;justify-content:center;border:2px solid rgba(255,255,255,.55);margin:0 -4px}
.hero .ava.more{background:rgba(255,255,255,.25)}
.hero .ava-names{color:rgba(255,255,255,.85);font-size:13px;margin-top:10px}

/* ---- 内容容器：白卡浮在渐变上 ---- */
.wrap{max-width:640px;margin:-48px auto 0;padding:0 16px;position:relative}
.sheet{background:var(--card);border-radius:24px;box-shadow:var(--shadow);padding:18px 16px 16px}
.narrow{max-width:400px;margin:12vh auto 0;padding:0 16px}
.notice-wrap{max-width:640px;margin:14vh auto 0;padding:0 16px;text-align:center}

/* ---- 行程：日分组 + 时间线 ---- */
.day-chip{display:inline-flex;align-items:center;gap:6px;background:#E6F7F1;color:var(--brand);border-radius:999px;padding:4px 12px;font-size:13px;font-weight:600;margin:14px 0 10px}
.sheet .day-chip:first-child{margin-top:2px}
.tl{position:relative;padding-left:18px}
.tl:before{content:'';position:absolute;left:4px;top:6px;bottom:6px;width:2px;background:#DFE9E4;border-radius:2px}
.item{position:relative;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:12px 14px;margin-bottom:10px;display:flex;justify-content:space-between;gap:12px;align-items:baseline}
.item:before{content:'';position:absolute;left:-18px;top:16px;width:10px;height:10px;border-radius:999px;background:var(--brand);box-shadow:0 0 0 3px #E6F7F1}
.item .main,.bill .main{min-width:0}
.item .t{font-size:15px;font-weight:600;word-break:break-all}
.item .s{color:var(--ink3);font-size:13px;margin-top:2px;word-break:break-all}

/* ---- 金额 ---- */
.cost{font-weight:600;white-space:nowrap;color:var(--brand);background:#E6F7F1;border-radius:999px;padding:3px 10px;font-size:14px}
.cost.income{color:var(--income);background:#E7F6EF}
.amt{font-weight:600;white-space:nowrap;font-size:15px}
.amt.income{color:var(--income)}

/* ---- 账本：小节 / 账单 / 结算 ---- */
.sec{margin:20px 4px 0;font-size:13px;color:var(--ink3);font-weight:600}
.bill{display:flex;align-items:center;gap:12px;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:12px 14px;margin-top:10px}
.bill .ico{width:38px;height:38px;border-radius:12px;background:#F0F7F4;display:flex;align-items:center;justify-content:center;font-size:20px;flex:none}
.bill .t{font-size:15px;font-weight:600;word-break:break-all}
.bill .s{color:var(--ink3);font-size:13px;margin-top:2px;word-break:break-all}
.settle{display:flex;gap:10px;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:12px 14px;margin-top:10px;align-items:flex-start}
.settle .ico{font-size:18px;flex:none}
.settle .main{min-width:0;flex:1}
.settle .round{font-size:13px;font-weight:600;color:var(--ink2)}
.tr-row{display:flex;justify-content:space-between;align-items:baseline;gap:12px;padding:7px 0;border-bottom:1px dashed #EDF3F0;font-size:14px}
.tr-row:last-child{border-bottom:0;padding-bottom:0}
.tr-people{word-break:break-all}
.tr-people i{font-style:normal;color:var(--brand);font-weight:600;margin:0 2px}
.tr-amt{font-weight:600;white-space:nowrap}
.settle .txt{font-size:12px;font-family:ui-monospace,Consolas,'Courier New',monospace;color:var(--ink2);word-break:break-all;line-height:1.6}

/* ---- 空态 ---- */
.empty{text-align:center;padding:40px 0}
.empty .ico{font-size:40px}
.empty p{color:var(--ink3);font-size:14px;margin-top:8px}

/* ---- 口令页 ---- */
.pass{background:var(--card);border-radius:24px;box-shadow:var(--shadow);padding:28px 22px;text-align:center}
.pass .lock{width:64px;height:64px;border-radius:999px;background:var(--grad);color:#fff;font-size:28px;display:flex;align-items:center;justify-content:center;margin:0 auto 12px}
.pass h1{font-size:18px}
.pass input{margin:16px auto 4px;display:block;width:160px;text-align:center;font-size:22px;letter-spacing:8px;border:1.5px solid var(--line);border-radius:14px;padding:10px 8px;outline:none;color:var(--ink)}
.pass input:focus{border-color:var(--brand);box-shadow:0 0 0 3px rgba(0,168,120,.15)}
.pass button{margin-top:14px;background:var(--grad);color:#fff;border:0;border-radius:14px;padding:11px 40px;font-size:15px;cursor:pointer;box-shadow:0 4px 12px rgba(0,127,92,.30)}
.err-line{color:var(--err);font-size:13px;min-height:18px;margin-top:6px}

/* ---- 错误 / 锁定页 ---- */
.err-ico{width:64px;height:64px;border-radius:999px;background:#E6F7F1;display:flex;align-items:center;justify-content:center;margin:0 auto 14px}
.notice-wrap p{color:#4B5B54;font-size:15px}

/* ---- 页脚 ---- */
footer{max-width:640px;margin:0 auto;padding:18px 16px 30px;text-align:center}
.promo{display:inline-block;font-size:14px;font-weight:600;color:var(--brand);text-decoration:none;background:var(--card);border:1px solid rgba(0,168,120,.30);border-radius:999px;padding:9px 18px;box-shadow:0 2px 10px rgba(0,60,40,.08)}
.brand{font-size:12px;color:var(--ink3);margin-top:10px}

/* ---- 微动画 ---- */
@keyframes fadeUp{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}
.hero,.sheet,.narrow>*,.notice-wrap>*{animation:fadeUp .4s ease both}
.sheet>*:nth-child(2){animation-delay:.06s}
.sheet>*:nth-child(3){animation-delay:.12s}
.sheet>*:nth-child(4){animation-delay:.18s}
.sheet>*:nth-child(n+5){animation-delay:.24s}
@media (prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
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
${bodyHtml}
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
