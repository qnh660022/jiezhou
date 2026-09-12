#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""攻略种子契约校验（docs/攻略种子数据契约.md 的可执行版本）。

用法：
  python scripts/check_guide_seed.py                 # 校验内置种子
  python scripts/check_guide_seed.py --json a.json   # 校验外部 AI 交付的单城 JSON
  python scripts/check_guide_seed.py --json-dir docs/_import   # 批量校验目录里的 *.json
  python scripts/check_guide_seed.py --strict        # 把「精品 50 城 5500 字」升为硬失败

退出码：0 = 全通过；1 = 有失败项（适合接进发布前检查）。
"""
import argparse
import glob
import io
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED = os.path.join(ROOT, "assets", "data", "guide_seed_v1.json")

SECTION_KEYS = ["prep", "spots", "food", "transport", "tips", "budget"]
SECTION_LABELS = {
    "prep": "行前准备", "spots": "景点推荐", "food": "美食",
    "transport": "交通", "tips": "避坑注意", "budget": "预算参考",
}
SECTION_FIELDS = {
    "prep": ["title", "detail"],
    "spots": ["name", "addr", "tag", "timeText", "note"],
    "food": ["name", "area", "note"],
    "transport": ["mode", "line", "note"],
    "tips": ["title", "detail"],
    "budget": ["item", "rangeText"],
}
SPOT_TAGS = {"必去", "经典", "小众", "亲子"}
# 存量种子里还带着这些标签（旧版内容），UI 会照常渲染成筛选 chip。
# 新生成的内容**只允许**上面四个标准标签；这里只放行存量，不鼓励新增。
# 完整性检查：把新标签加进来之前先确认它确实该长期存在，否则应改写成四个标准标签之一。
SPOT_TAGS_LEGACY = {"周边", "网红", "户外", "教育", "夜游", "秘境", "演出", "文艺"}
AREAS = {"直辖市", "华东", "华南", "华中", "西南", "西北", "华北", "东北", "港澳台"}

# 精品 50 城（与 docs/攻略生成提示词模板.md 第三节一致）
PREMIUM_50 = [
    "beijing", "shanghai",
    "hangzhou", "suzhou", "nanjing", "xiamen", "huangshan", "wuxi", "yangzhou",
    "shaoxing", "ningbo", "quanzhou", "wuyuan", "jinan", "jingdezhen",
    "guangzhou", "shenzhen", "guilin", "sanya", "shantou", "foshan", "chaozhou",
    "haikou", "beihai",
    "chengdu", "chongqing", "kunming", "dali", "lijiang", "zhangjiajie",
    "guiyang", "luoyang", "xishuangbanna", "shangrila", "leshan",
    "xian", "dunhuang", "zhangye", "xining",
    "harbin", "dalian", "qingdao", "tianjin", "shenyang", "changchun",
    "hongkong", "macau", "taibei",
    "weihai", "yanji",
]

# 每栏条数下限（契约里的「目标」条数打了折，避免误伤合理取舍）
MIN_ITEMS = {
    "prep": 6, "spots": 10, "food": 8,
    "transport": 5, "tips": 6, "budget": 5,
}
MAX_ITEMS = 24  # 种子结构测试的硬上限，超过会挂测试

MIN_CHARS_PREMIUM = 5500   # 15 分钟阅读
MIN_CHARS_OTHER = 300
MAX_CITY_BYTES = 64 * 1024
MAX_PACK_BYTES = 8 * 1024 * 1024


def cjk_count(s):
    return sum(1 for ch in s if "\u4e00" <= ch <= "\u9fff")


def city_chars(city):
    total = 0
    for k in SECTION_KEYS:
        for it in city.get("sections", {}).get(k) or []:
            if isinstance(it, dict):
                for v in it.values():
                    if isinstance(v, str):
                        total += cjk_count(v)
    return total


def check_city(city, *, premium=False, strict=False, errors=None, warns=None):
    errors = errors if errors is not None else []
    warns = warns if warns is not None else []
    key = city.get("key")
    name = city.get("name")

    def err(msg):
        errors.append("[%s] %s" % (key or "?", msg))

    def warn(msg):
        warns.append("[%s] %s" % (key or "?", msg))

    if not isinstance(key, str) or not key:
        err("key 缺失或非法")
        return errors, warns
    if not isinstance(name, str) or not name:
        err("name 缺失或非法")

    area = city.get("area", "")
    if area and area not in AREAS:
        err("area 非法：%s（允许 %s）" % (area, "/".join(sorted(AREAS))))
    if premium and not area:
        warn("精品城市缺 area 字段（攻略页换城市分组会落到「其他」）")

    sections = city.get("sections")
    if not isinstance(sections, dict):
        err("sections 不是对象")
        return errors, warns

    for k in SECTION_KEYS:
        if k not in sections:
            err("缺栏目 %s（%s）" % (k, SECTION_LABELS[k]))
            continue
        items = sections[k]
        if not isinstance(items, list):
            err("%s 不是数组" % k)
            continue
        if len(items) > MAX_ITEMS:
            err("%s 有 %d 条，超过上限 %d" % (k, len(items), MAX_ITEMS))
        if len(items) < MIN_ITEMS[k]:
            (err if (premium and strict) else warn)(
                "%s 只有 %d 条，建议 ≥%d 条" % (k, len(items), MIN_ITEMS[k]))
        for idx, it in enumerate(items):
            if not isinstance(it, dict):
                err("%s[%d] 不是对象" % (k, idx))
                continue
            for f in SECTION_FIELDS[k]:
                v = it.get(f)
                if v is None or (isinstance(v, str) and not v.strip()):
                    warn("%s[%d] 缺字段 %s" % (k, idx, f))
            if k == "spots":
                tag = it.get("tag")
                if tag not in SPOT_TAGS:
                    if tag in SPOT_TAGS_LEGACY:
                        warn("spots[%d] tag=%r 是存量旧标签，新内容请用 %s"
                             % (idx, tag, "/".join(sorted(SPOT_TAGS))))
                    else:
                        err("spots[%d] tag=%r 不在 %s"
                            % (idx, tag, "/".join(sorted(SPOT_TAGS))))
            if k == "budget":
                rt = it.get("rangeText") or ""
                if "参考" not in rt:
                    err("budget[%d] rangeText 必须含「（参考）」：%r" % (idx, rt))
            for f in SECTION_FIELDS[k]:
                v = it.get(f)
                if isinstance(v, str) and "TODO" in v.upper():
                    err("%s[%d].%s 里有占位符 TODO" % (k, idx, f))

    chars = city_chars(city)
    need = MIN_CHARS_PREMIUM if premium else MIN_CHARS_OTHER
    if chars < need:
        (err if (premium and strict) else warn)(
            "正文 %d 字，低于%s %d 字（约 %d 分钟阅读）"
            % (chars, "精品线" if premium else "底线", need, chars // 350))
    size = len(json.dumps(city, ensure_ascii=False).encode("utf-8"))
    if size > MAX_CITY_BYTES:
        err("单城 JSON %d 字节，超过 %d" % (size, MAX_CITY_BYTES))
    return errors, warns


def report(title, errors, warns, strict):
    print("=" * 64)
    print(title)
    print("-" * 64)
    for w in warns:
        print("  ⚠ %s" % w)
    for e in errors:
        print("  ✗ %s" % e)
    ok = not errors and (not strict or not warns)
    print("  → %s（错误 %d / 提示 %d）" % ("通过" if ok else "失败", len(errors), len(warns)))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", help="校验单个城 JSON 文件")
    ap.add_argument("--json-dir", help="批量校验目录下 *.json")
    ap.add_argument("--strict", action="store_true", help="精品 50 城的条数/字数为硬失败")
    args = ap.parse_args()

    all_ok = True

    if args.json or args.json_dir:
        files = []
        if args.json:
            files.append(args.json)
        if args.json_dir:
            files.extend(sorted(glob.glob(os.path.join(args.json_dir, "*.json"))))
        if not files:
            print("没有找到要校验的 JSON")
            return 1
        for path in files:
            with io.open(path, encoding="utf-8") as f:
                data = json.load(f)
            # 允许「单城对象」或「{cities:[...]}」两种形态
            cities = data.get("cities") if isinstance(data, dict) and "cities" in data else [data]
            for c in cities:
                errors, warns = check_city(
                    c, premium=c.get("key") in PREMIUM_50, strict=args.strict)
                all_ok &= report("%s :: %s" % (os.path.basename(path), c.get("name")), errors, warns, args.strict)
        return 0 if all_ok else 1

    with io.open(SEED, encoding="utf-8") as f:
        seed = json.load(f)
    cities = seed.get("cities") or []
    keys = [c.get("key") for c in cities]
    if len(keys) != len(set(keys)):
        print("✗ key 有重复")
        all_ok = False
    if not seed.get("version"):
        print("✗ version 为空")
        all_ok = False

    total_chars = 0
    premium_seen = []
    premium_ready = []   # 已达 5500 字的精品城
    premium_short = []   # 还差的精品城（内容加厚进度）
    for c in cities:
        premium = c.get("key") in PREMIUM_50
        if premium:
            premium_seen.append(c.get("key"))
            chars = city_chars(c)
            if chars >= MIN_CHARS_PREMIUM:
                premium_ready.append(c.get("key"))
            else:
                premium_short.append((c.get("key"), chars))
        total_chars += city_chars(c)
        errors, warns = check_city(c, premium=premium, strict=args.strict)
        if errors or (args.strict and warns):
            all_ok &= report("%s（%s）" % (c.get("name"), c.get("key")), errors, warns, args.strict)

    missing = [k for k in PREMIUM_50 if k not in premium_seen]
    print("=" * 64)
    print("种子总览")
    print("-" * 64)
    print("  城市数：%d" % len(cities))
    print("  精品 50 城：命中 %d / %d" % (len(premium_seen), len(PREMIUM_50)))
    if missing:
        print("  缺精品城：%s" % " ".join(missing))
        all_ok = False
    print("  正文合计：%d 字（平均 %d 字/城）"
          % (total_chars, total_chars // max(1, len(cities))))
    print("  精品线（≥%d 字/城，约 15 分钟阅读）：达标 %d / %d"
          % (MIN_CHARS_PREMIUM, len(premium_ready), len(PREMIUM_50)))
    if premium_short:
        short = " ".join("%s(%d)" % (k, v) for k, v in
                         sorted(premium_short, key=lambda x: x[1]))
        print("  待加厚（字数为当前值）：")
        for line in _wrap(short, 96):
            print("    %s" % line)
    pack = os.path.getsize(SEED)
    print("  种子体积：%.2f MB（上限 %.0f MB）" % (pack / 1048576.0, MAX_PACK_BYTES / 1048576.0))
    if pack > MAX_PACK_BYTES:
        print("  ✗ 超上限")
        all_ok = False
    print("=" * 64)
    print("结果：%s" % ("全部通过" if all_ok else "有失败项"))
    return 0 if all_ok else 1


def _wrap(s, width):
    out, line = [], ""
    for tok in s.split(" "):
        if line and len(line) + len(tok) + 1 > width:
            out.append(line)
            line = tok
        else:
            line = (line + " " + tok).strip()
    if line:
        out.append(line)
    return out


if __name__ == "__main__":
    sys.exit(main())
