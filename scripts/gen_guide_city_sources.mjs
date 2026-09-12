#!/usr/bin/env node
/**
 * 生成 lib/data/guide/guide_city_sources.dart（城市 → 去哪儿攻略城市 ID 表）。
 *
 * ## 为什么需要这份表
 * `travel.qunar.com` 是实测唯一「robots 对通用 UA 放行 + 服务端直出中文攻略正文」的
 * 国内源，而且只有**主城市页**可用：`-zhinan` / `-meishi` / `-jingdian` / `p-oi*` /
 * `-gaikuang-1-1-N` 分页实测全部 404 或空壳。所以「一城 = 一个确定 URL」是唯一可行
 * 路线，不能靠搜索引擎现找（会引入外站依赖与外文结果）。
 *
 * ## 关键坑（务必保留本注释）
 * URL 里的 **ID 才是权威**，slug 只是装饰：
 *   `p-cs300022-changsha` → 服务端按 ID 300022 渲染，返回**长沙**（杭州页等显示
 *   300022 对应长沙）。反之若 ID 与 slug 不匹配，会静默返回**另一个城市**的正文——
 *   这类错误不会被 HTTP 状态码暴露。
 * 因此本生成器：
 *   ① 只从页面里**带城市名的链接**（`>城市名</a>`）收集 `(cityId, 城市名)`，按 slug
 *      配对的一律不用（台州/泰州同 slug 会撞车）；
 *   ② 对每一行都**抓一次页面并用 `<h1>` 标题校验城市名**，不匹配就丢弃并告警；
 *   ③ 生成物带 `kQunarCityNames`，运行时再校验一次（见 guide_crawler.dart）。
 *
 * 用法：node scripts/gen_guide_city_sources.mjs [--offline] [--no-verify]
 *   --offline   只用内置锚点，不发任何请求（表会很小）
 *   --no-verify 跳过逐城校验（速度快，但可能写入错城 ID——仅调试用）
 */
import { writeFileSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const argv = process.argv.slice(2);
const offline = argv.includes('--offline');
const skipVerify = argv.includes('--no-verify');

/** 已知城市页锚点（城市页之间会互相链接，用它做横向扩散）。 */
const ANCHORS = [
  '299914-beijing', '299878-shanghai', '299861-nanjing', '299782-xiamen',
  '300195-hangzhou', '299941-yangzhou', '300085-chengdu', '299979-chongqing',
  '300118-shenzhen', '300132-guangzhou', '300188-sanya', '300100-xian',
  '299801-guilin', '300079-lijiang', '300064-zhangjiajie', '299808-xishuangbanna',
  '300148-haikou', '299789-beihai', '299783-qingdao', '300090-dali',
  // 覆盖精品 50 城所需的额外锚点（哈尔滨/济南/黄山/沈阳等热门页）
  '300022-changsha', '299937-suzhou', '299940-wuxi', '300194-ningbo',
  '300181-shaoxing', '299779-quanzhou', '300096-shantou', '300129-foshan',
  '299787-chaozhou', '299892-leshan', '299856-guiyang', '299852-anshun',
  '300113-qinhuangdao', '300082-chengde', '299799-zhuhai', '299933-nantong',
];

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

const sleep = (ms) => new Promise((s) => setTimeout(s, ms));

async function fetchText(url, tries = 2) {
  for (let i = 0; i < tries; i++) {
    try {
      const r = await fetch(url, {
        headers: { 'User-Agent': UA, 'Accept-Language': 'zh-CN,zh;q=0.9' },
        signal: AbortSignal.timeout(20000),
      });
      if (r.status === 200) return await r.text();
    } catch {
      /* 重试 */
    }
    await sleep(800);
  }
  return null;
}

/** 从城市名链接里抽 `(cityId, 城市名)`：`.../p-cs123-slug" title="杭州"` 或 `>杭州</a>`。 */
function cityLinks(html) {
  const out = [];
  for (const m of html.matchAll(/p-cs(\d{4,7})-([a-z0-9]{2,24})([\s\S]{0,160}?)<\/a>/g)) {
    const id = Number(m[1]);
    const tail = m[3];
    const title = /title="([^"]{2,12})"/.exec(tail);
    const text = /^[^>]*>([^<]{2,12})$/.exec(tail);
    const name = (title?.[1] ?? text?.[1] ?? '').replace(/(旅游攻略|攻略|旅游)$/g, '').trim();
    if (/^[\u4e00-\u9fa5]{2,8}$/.test(name)) out.push({ id, name });
  }
  return out;
}

/** 页面自身城市名：`<h1>` 或 `<title>` 前缀。 */
function pageCityName(html) {
  const h1 = /<h1[^>]*>([\s\S]{0,60}?)<\/h1>/.exec(html);
  if (h1) {
    const t = h1[1].replace(/<[^>]+>/g, '').replace(/旅游攻略|攻略/g, '').trim();
    if (/^[\u4e00-\u9fa5]{2,8}$/.test(t)) return t;
  }
  const title = /<title[^>]*>([^<]{2,40})/.exec(html);
  if (title) {
    const t = title[1].replace(/(旅游攻略|自助游|.*)$/g, '').trim();
    if (/^[\u4e00-\u9fa5]{2,8}$/.test(t)) return t;
  }
  return null;
}

/** 种子城市中文名 → guide key（与 assets/data/guide_seed_v1.json 的 key 对齐）。 */
const seedCities = JSON.parse(
  readFileSync(join(root, 'assets/data/guide_seed_v1.json'), 'utf8'),
).cities;
const keyByName = new Map(seedCities.map((c) => [c.name, c.key]));
const nameByKey = new Map(seedCities.map((c) => [c.key, c.name]));

// ---------- 1) 扩散收集 (cityId → 城市名) ----------
/** cityId → 出现过的城市名集合（取出现次数最多者）。 */
const namesById = new Map();
function record(id, name) {
  if (!namesById.has(id)) namesById.set(id, new Map());
  const m = namesById.get(id);
  m.set(name, (m.get(name) ?? 0) + 1);
}

if (!offline) {
  const seen = new Set();
  // 锚点 = 显式锚点 + 第一遍发现的「已知有城市名」的 id（BFS）。
  // `--no-verify` 时**不做 BFS**：那只是为了快速拿到候选表，跑几百个页面不值。
  const queue = [...ANCHORS];
  let round = 0;
  while (queue.length && round < 320) {
    const a = queue.shift();
    const idPart = a.includes('-') ? a : `${a}-x`;
    if (seen.has(idPart)) continue;
    seen.add(idPart);
    round++;
    const html = await fetchText(`https://travel.qunar.com/p-cs${a}`);
    await sleep(900); // 限速：≥1s/域名
    if (!html) continue;
    const self = pageCityName(html);
    const id = Number(String(a).split('-')[0]);
    if (self) record(id, self);
    for (const { id: cid, name } of cityLinks(html)) {
      record(cid, name);
      if (skipVerify || round > 24) continue; // 只在前 24 个锚点后做横向扩散
      const slug = String(a).split('-')[1] ?? 'x';
      const next = `${cid}-${slug}`;
      if (!seen.has(next) && seen.size < 320) queue.push(next);
    }
    process.stderr.write(`harvest #${round} ${a} → ids=${namesById.size}\n`);
  }
}

// ---------- 2) 收敛为 guide key → (id, 城市名) ----------
const byKey = new Map();
for (const [id, nameCounts] of namesById) {
  let best = null;
  for (const [name, n] of nameCounts) {
    if (!keyByName.has(name)) continue;
    if (!best || n > best.n) best = { name, n };
  }
  if (!best) continue;
  const key = keyByName.get(best.name);
  if (byKey.has(key) && byKey.get(key).id !== id) {
    process.stderr.write(`⚠ ${best.name} 命中多个 ID：${byKey.get(key).id} / ${id}，保留先到\n`);
    continue;
  }
  byKey.set(key, { id, name: best.name });
}

// ---------- 3) 逐城校验（抓页面必须返回同名城市） ----------
const verified = new Map();
if (skipVerify) {
  for (const [k, v] of byKey) verified.set(k, v);
} else {
  for (const [key, v] of [...byKey].sort((a, b) => a[0].localeCompare(b[0]))) {
    const html = await fetchText(`https://travel.qunar.com/p-cs${v.id}-${key}`);
    await sleep(900);
    if (!html) {
      process.stderr.write(`✗ ${key}(${v.name}) 抓取失败，丢弃\n`);
      continue;
    }
    const got = pageCityName(html);
    if (got !== v.name) {
      process.stderr.write(`✗ ${key}(${v.name}) ID ${v.id} 实际返回「${got}」，丢弃\n`);
      continue;
    }
    verified.set(key, v);
    process.stderr.write(`✓ ${key}(${v.name}) = ${v.id}\n`);
  }
}

// ---------- 4) 写 Dart ----------
const rows = [...verified.entries()].sort((a, b) => a[0].localeCompare(b[0]));
const missing = seedCities.map((c) => c.name).filter((n) => !verified.has(keyByName.get(n)));

const dart = `/// 去哪儿攻略「城市 key → 城市 ID」映射 + 城市名校验表（生成物，勿手改）。
///
/// 生成命令：\`node scripts/gen_guide_city_sources.mjs\`
///
/// 只收录**逐城抓页面用 <h1> 校验过**的城市：去哪儿 URL 里 ID 才是权威，ID 与 slug
/// 不匹配时会静默返回另一个城市的正文（HTTP 仍是 200）。所以抓取层拿到正文后必须
/// 再用 [kQunarCityNames] 复核一次，对不上就丢弃、只用内置种子。
///
/// 表内没有的城市 → 抓取层直接跳过在线层，**不猜 URL、不猜 ID**。
library;

/// cityKey(\`assets/data/guide_seed_v1.json\` 的 key) → 去哪儿城市 ID。
const Map<String, int> kQunarCityIds = {
${rows.map(([k, v]) => `  '${k}': ${v.id}, // ${v.name}`).join('\n')}
};

/// cityKey → 期望的城市中文名（运行时复核抓回来的页面是不是这座城）。
const Map<String, String> kQunarCityNames = {
${rows.map(([k, v]) => `  '${k}': '${v.name}',`).join('\n')}
};

/// 已收录城市数（测试断言用）。
int get qunarCityCount => kQunarCityIds.length;
`;

writeFileSync(join(root, 'lib/data/guide/guide_city_sources.dart'), dart, 'utf8');
console.log(`wrote lib/data/guide/guide_city_sources.dart  cities=${rows.length}`);
if (missing.length) console.log(`未收录(${missing.length})：${missing.join(' ')}`);
