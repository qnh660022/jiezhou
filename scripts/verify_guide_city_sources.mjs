#!/usr/bin/env node
/**
 * 校验 lib/data/guide/guide_city_sources.dart 里每一条「城市 key → 去哪儿 ID」
 * 是否真的指向那座城市。
 *
 * 为什么必须校验：去哪儿 URL 里 **ID 才是权威**，ID 与 slug 不匹配时服务端
 * 会静默返回**另一座城市**的正文（HTTP 仍是 200）。生成脚本的 BFS 扩散会记录
 * 页面上出现的 (id, 城市名) 对，个别站点侧的重定向足以让某个 ID 挂到错城市上。
 *
 * 用法：node scripts/verify_guide_city_sources.mjs [--fix]
 *   --fix  校验不通过的行直接从源文件里删掉（保留注释头）
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const file = join(root, 'lib/data/guide/guide_city_sources.dart');
const src = readFileSync(file, 'utf8');
const fix = process.argv.includes('--fix');

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

const rows = [...src.matchAll(/^ {2}'([a-z0-9_]+)': (\d+), \/\/ (.+)$/gm)].map((m) => ({
  key: m[1],
  id: Number(m[2]),
  name: m[3].trim(),
  raw: m[0],
}));

const sleep = (ms) => new Promise((s) => setTimeout(s, ms));

function pageCityName(html) {
  const h = /<h1[^>]*>([\s\S]{0,80}?)<\/h1>/i.exec(html);
  if (h) {
    const t = h[1]
      .replace(/<[^>]+>/g, '')
      .replace(/\s+/g, '')
      .replace(/(旅游攻略|自助游|攻略)$/g, '')
      .trim();
    if (t && t.length <= 8) return t;
  }
  const ti = /<title[^>]*>([^<]{2,60})/i.exec(html);
  if (!ti) return null;
  const t = ti[1].replace(/(旅游攻略|自助游|旅游|攻略).*$/g, '').trim();
  return t && t.length <= 8 ? t : null;
}

async function check(row) {
  const url = `https://travel.qunar.com/p-cs${row.id}-${row.key}`;
  try {
    const r = await fetch(url, {
      headers: { 'User-Agent': UA, 'Accept-Language': 'zh-CN,zh;q=0.9' },
      signal: AbortSignal.timeout(15000),
    });
    if (r.status !== 200) return { ok: false, got: `HTTP ${r.status}` };
    const got = pageCityName(await r.text());
    return { ok: got === row.name, got: got ?? '(未识别)' };
  } catch (e) {
    return { ok: false, got: `ERR ${e.name}` };
  }
}

const bad = [];
for (const row of rows) {
  const res = await check(row);
  if (res.ok) {
    console.log(`✓ ${row.key} = ${row.id} (${row.name})`);
  } else {
    console.log(`✗ ${row.key} = ${row.id} 期望「${row.name}」实际「${res.got}」`);
    bad.push(row);
  }
  await sleep(1000); // 限速 ≥1s/域名
}

console.log(`\n共 ${rows.length} 条，异常 ${bad.length} 条`);
if (bad.length && fix) {
  let out = src;
  for (const row of bad) out = out.replace(`${row.raw}\n`, '');
  for (const row of bad) {
    out = out.replace(
      new RegExp(`^ {2}'${row.key}': '${row.name}',\\n`, 'm'),
      '',
    );
  }
  writeFileSync(file, out, 'utf8');
  console.log('--fix：已从 guide_city_sources.dart 删除异常行');
}
