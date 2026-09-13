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

# ---- v4 内容等级（docs/攻略种子数据契约.md 第 4 节；等级只影响编写投入与校验线，不对用户展示）----
LEVEL_A_PLUS_KEYS = {"zhangzhou"}   # 漳州：A+ 特例城，需先在 _gen_guide_seed.py 注册城市记录
LEVEL_A_KEYS = {
    "beijing", "shanghai", "tianjin",
    "hangzhou", "suzhou", "nanjing", "xiamen", "qingdao",
    "guangzhou", "foshan", "guilin",
    "chengdu", "chongqing",
    "xian",
    "dalian", "harbin",
    "luoyang",
    "hongkong",
}
LEVEL_C_KEYS = {
    "yantai", "zhoushan", "liuzhou", "wanning", "libo",
    "yining", "linzhi", "kashi", "zhongwei", "dandong",
}   # 均为种子外全新城市（v4），与漳州一样需先在 _gen_guide_seed.py 注册城市记录
LEVEL_B_KEYS = set(PREMIUM_50) - LEVEL_A_KEYS
LEVEL_MIN_CHARS = {"A+": 7000, "A": 5500, "B": 3000, "C": 800}
LEVEL_LABELS = {"A+": "A+（7000 字，精品中的精品）", "A": "A（5500 字，重点城）",
                "B": "B（3000 字硬线，建议多写）", "C": "C（800 字硬线，建议 1000 左右）"}
# 漳州 A+ 特例栏目（契约 v4 第 2 节；其他城市出现会告警；客户端按未知栏目忽略）
EXTRA_SECTIONS = {"routes": ("主题路线", 4, 6), "calendar": ("季节日历", 4, 6)}
EXTRA_FIELDS = {"title", "detail"}

# 每栏条数下限（契约里的「目标」条数打了折，避免误伤合理取舍；A/A+ 级用）
MIN_ITEMS = {
    "prep": 6, "spots": 10, "food": 8,
    "transport": 5, "tips": 6, "budget": 5,
}
# B 级条数下限（覆盖面优先，单城投入相应减少）
MIN_ITEMS_BASIC = {
    "prep": 4, "spots": 6, "food": 4,
    "transport": 3, "tips": 4, "budget": 3,
}
# C 级条数下限（800~1000 字轻量覆盖）
MIN_ITEMS_C = {
    "prep": 3, "spots": 4, "food": 3,
    "transport": 2, "tips": 3, "budget": 3,
}
MAX_ITEMS = 24  # 种子结构测试的硬上限，超过会挂测试

MIN_CHARS_PREMIUM = 5500   # A 级硬线（保留旧常量名兼容）
MIN_CHARS_OTHER = 300
MAX_CITY_BYTES = 64 * 1024
MAX_PACK_BYTES = 8 * 1024 * 1024


def city_level(key):
    if key in LEVEL_A_PLUS_KEYS:
        return "A+"
    if key in LEVEL_A_KEYS:
        return "A"
    if key in LEVEL_B_KEYS:
        return "B"
    if key in LEVEL_C_KEYS:
        return "C"
    return None


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


def check_city(city, *, strict=False, errors=None, warns=None):
    errors = errors if errors is not None else []
    warns = warns if warns is not None else []
    key = city.get("key")
    name = city.get("name")
    level = city_level(key)

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
    if level and not area:
        warn("计划等级 %s 城缺 area 字段（攻略页换城市分组会落到「其他」）" % level)

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
        mins = MIN_ITEMS_C if level == "C" else (MIN_ITEMS_BASIC if level == "B" else MIN_ITEMS)
        if len(items) < mins[k]:
            (err if (level and strict) else warn)(
                "%s 只有 %d 条，%s级建议 ≥%d 条" % (k, len(items), level or "?", mins[k]))
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
    need = LEVEL_MIN_CHARS[level] if level else MIN_CHARS_OTHER
    if chars < need:
        (err if (level and strict) else warn)(
            "正文 %d 字，低于 %s 硬线 %d 字（约 %d 分钟阅读）"
            % (chars, LEVEL_LABELS.get(level, "底线"), need, chars // 350))
    size = len(json.dumps(city, ensure_ascii=False).encode("utf-8"))
    if size > MAX_CITY_BYTES:
        err("单城 JSON %d 字节，超过 %d" % (size, MAX_CITY_BYTES))
    # 漳州 A+ 特例栏目（契约 v4 第 2 节）：routes / calendar
    for ek, (label, lo, hi) in EXTRA_SECTIONS.items():
        if ek not in sections:
            if level == "A+":
                warn("缺特例栏目 %s（%s），A+ 城应包含" % (ek, label))
            continue
        if level != "A+":
            warn("非 A+ 城出现特例栏目 %s（仅漳州允许）" % ek)
        eitems = sections[ek]
        if not isinstance(eitems, list):
            err("%s 不是数组" % ek)
            continue
        if not (lo <= len(eitems) <= hi):
            warn("%s 有 %d 条，建议 %d~%d 条" % (ek, len(eitems), lo, hi))
        for idx, it in enumerate(eitems):
            if not isinstance(it, dict):
                err("%s[%d] 不是对象" % (ek, idx))
                continue
            for f in EXTRA_FIELDS:
                v = it.get(f)
                if v is None or (isinstance(v, str) and not v.strip()):
                    warn("%s[%d] 缺字段 %s" % (ek, idx, f))
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
    ap.add_argument("--strict", action="store_true", help="计划城（A+/A/B/C）的条数/字数为硬失败")
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
                lv = city_level(c.get("key"))
                errors, warns = check_city(c, strict=args.strict)
                all_ok &= report("%s :: %s%s" % (os.path.basename(path), c.get("name"),
                                                 "〔%s〕" % lv if lv else ""), errors, warns, args.strict)
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
    level_keys = {"A+": LEVEL_A_PLUS_KEYS, "A": LEVEL_A_KEYS,
                  "B": LEVEL_B_KEYS, "C": LEVEL_C_KEYS}
    level_seen = {lv: [] for lv in level_keys}
    level_ready = {lv: [] for lv in level_keys}
    level_short = {lv: [] for lv in level_keys}
    for c in cities:
        lv = city_level(c.get("key"))
        if lv:
            level_seen[lv].append(c.get("key"))
            chars = city_chars(c)
            if chars >= LEVEL_MIN_CHARS[lv]:
                level_ready[lv].append(c.get("key"))
            else:
                level_short[lv].append((c.get("key"), chars))
        total_chars += city_chars(c)
        errors, warns = check_city(c, strict=args.strict)
        if errors or (args.strict and warns):
            all_ok &= report("%s（%s）" % (c.get("name"), c.get("key")), errors, warns, args.strict)

    missing = {lv: sorted(k for k in keys_ if k not in level_seen[lv])
               for lv, keys_ in level_keys.items()}
    print("=" * 64)
    print("种子总览（v4 分级）")
    print("-" * 64)
    print("  城市数：%d（等级计划 %d 城：A+ 1 / A 18 / B 32 / C 10）" % (len(cities), 61))
    for lv in ("A+", "A", "B", "C"):
        print("  %s：命中 %d / %d，达标 %d / %d"
              % (LEVEL_LABELS[lv], len(level_seen[lv]), len(level_keys[lv]),
                 len(level_ready[lv]), len(level_keys[lv])))
    for lv in ("A+", "A", "B", "C"):
        if missing[lv]:
            tag = "待注册入种子" if lv in ("A+", "C") else "缺城"
            print("  %s %s：%s" % (lv, tag, " ".join(missing[lv])))
            if args.strict:
                all_ok = False
    print("  正文合计：%d 字（平均 %d 字/城）"
          % (total_chars, total_chars // max(1, len(cities))))
    shorts = []
    for lv in ("A+", "A", "B", "C"):
        for k, v in level_short[lv]:
            shorts.append((lv, k, v))
    if shorts:
        print("  待加厚（按等级 · 字数为当前值）：")
        for lv in ("A+", "A", "B", "C"):
            grp = sorted([s for s in shorts if s[0] == lv], key=lambda x: x[2])
            if grp:
                short = " ".join("%s(%d)" % (k, v) for _, k, v in grp)
                print("    〔%s〕" % lv)
                for line in _wrap(short, 96):
                    print("      %s" % line)
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
