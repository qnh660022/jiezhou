#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把外部 AI 交付的攻略内容导入种子覆盖层（唯一真相源仍是 _gen_guide_seed.py）。

用法：
  # 导入单城 JSON（外部 AI 按 docs/攻略生成提示词模板.md 产出）
  python scripts/import_guide_cities.py docs/_import/hangzhou.json

  # 批量导入一个目录（*.json 与 *_city.py 都认）
  python scripts/import_guide_cities.py docs/_import/*.json docs/_import/*.py

  # 只体检不落盘（看会覆盖哪些城、字数够不够）
  python scripts/import_guide_cities.py --dry-run docs/_import/*.json

处理流程：
  1. 读入并解析（JSON 直接解析；`*_city.py` 里 `city(...)` 片段用 AST 解析）；
  2. 结构校验（六栏齐、key 在白名单内、spots.tag 合法、budget 带「参考」）；
  3. 统计各栏条数与正文汉字数，低于精品线时给出提示（**不阻断**，
     因为可以分次加厚，check_guide_seed.py 会持续盯着）；
  4. 写 `scripts/guide_overrides/<key>.json`（整城覆盖，重跑幂等）；
  5. 提示接着跑 `_gen_guide_seed.py` 与 `check_guide_seed.py`。

为什么走覆盖层而不是直接改生成脚本：见 `_gen_guide_seed.py` 里的「覆盖层」注释。
"""
import argparse
import ast
import glob
import io
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED = os.path.join(ROOT, "assets", "data", "guide_seed_v1.json")
OV_DIR = os.path.join(ROOT, "scripts", "guide_overrides")

SECTION_KEYS = ["prep", "spots", "food", "transport", "tips", "budget"]
SECTION_FIELDS = {
    "prep": ["title", "detail"],
    "spots": ["name", "addr", "tag", "timeText", "note"],
    "food": ["name", "area", "note"],
    "transport": ["mode", "line", "note"],
    "tips": ["title", "detail"],
    "budget": ["item", "rangeText"],
}
SPOT_TAGS_OK = {"必去", "经典", "小众", "亲子"}
SPOT_TAGS_ACCEPT = SPOT_TAGS_OK | {"周边", "网红", "户外", "教育", "夜游", "秘境", "演出", "文艺"}
MIN_CHARS = 5500
MIN_ITEMS = {"prep": 8, "spots": 14, "food": 10, "transport": 7, "tips": 8, "budget": 6}


def cjk_count(s):
    return sum(1 for ch in s if "\u4e00" <= ch <= "\u9fff")


def city_chars(sections):
    total = 0
    for k in SECTION_KEYS:
        for it in sections.get(k) or []:
            if isinstance(it, dict):
                for v in it.values():
                    if isinstance(v, str):
                        total += cjk_count(v)
    return total


# --------------------------------------------------------------------------
# 解析输入
# --------------------------------------------------------------------------

def load_json_city(path):
    with io.open(path, encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict) and "cities" in data:
        # 允许多城包：只取第一个并在提示里说明
        cities = data.get("cities") or []
        if not cities:
            raise ValueError("cities 为空")
        return [cities[0]]
    if isinstance(data, list):
        return data
    return [data]


def _call_to_city(node):
    """把 `city(key, name, [P(...)], [S(...)], ...)` 的 AST 转成城对象。

    只做「字面量求值」：P/S/F/T/W/B 这些 helper 的参数都是常量，
    用 ast.literal_eval 逐层取值即可，不执行交付文件里的任何代码。
    """
    if not isinstance(node, ast.Call):
        return None
    fn = node.func
    fname = fn.id if isinstance(fn, ast.Name) else getattr(fn, "attr", None)
    if fname != "city":
        return None
    args = node.args
    if len(args) < 8:
        return None
    key = ast.literal_eval(args[0])
    name = ast.literal_eval(args[1])
    sections = {}
    for k, arg in zip(SECTION_KEYS, args[2:8]):
        items = []
        for item in ast.literal_eval(arg) if not isinstance(arg, ast.List) else arg.elts:
            if not isinstance(item, ast.Call):
                continue
            helper = item.func.id if isinstance(item.func, ast.Name) else ""
            vals = [ast.literal_eval(a) for a in item.args]
            if helper == "P":
                items.append({"title": vals[0], "detail": vals[1]})
            elif helper == "S":
                items.append({
                    "name": vals[0], "addr": vals[1], "tag": vals[2],
                    "timeText": vals[3], "note": vals[4] if len(vals) > 4 else "",
                })
            elif helper == "F":
                items.append({"name": vals[0], "area": vals[1],
                              "note": vals[2] if len(vals) > 2 else ""})
            elif helper == "T":
                items.append({"mode": vals[0], "line": vals[1],
                              "note": vals[2] if len(vals) > 2 else ""})
            elif helper == "W":
                items.append({"title": vals[0], "detail": vals[1]})
            elif helper == "B":
                r = vals[1]
                items.append({"item": vals[0],
                              "rangeText": r if "参考" in r else r + "（参考）"})
        sections[k] = items
    return {"key": key, "name": name, "sections": sections}


def load_py_cities(path):
    with io.open(path, encoding="utf-8") as f:
        src = f.read()
    tree = ast.parse(src, filename=path)
    out = []
    for node in ast.walk(tree):
        city = _call_to_city(node)
        if city:
            out.append(city)
    # 也允许直接给一个 JSON 字符串（AI 有时把 JSON 存成 .py）
    if not out:
        try:
            obj = json.loads(src)
            if isinstance(obj, dict):
                out.append(obj)
        except Exception:
            pass
    return out


# --------------------------------------------------------------------------
# 校验与落盘
# --------------------------------------------------------------------------

def validate(city, known_keys):
    errors = []
    warns = []
    key = city.get("key", "")
    if key not in known_keys:
        errors.append("key=%r 不在内置种子里（先在 _gen_guide_seed.py 登记城市）" % key)
    if not city.get("name"):
        errors.append("缺 name")
    sections = city.get("sections")
    if not isinstance(sections, dict):
        errors.append("缺 sections")
        return errors, warns, 0
    for k in SECTION_KEYS:
        items = sections.get(k)
        if not isinstance(items, list):
            errors.append("缺栏目 %s" % k)
            continue
        if not items:
            warns.append("%s 是空的（种子会保留原内容）" % k)
            continue
        if len(items) < MIN_ITEMS[k]:
            warns.append("%s 只有 %d 条，建议 ≥%d" % (k, len(items), MIN_ITEMS[k]))
        for idx, it in enumerate(items):
            if not isinstance(it, dict):
                errors.append("%s[%d] 不是对象" % (k, idx))
                continue
            for f in SECTION_FIELDS[k]:
                if not str(it.get(f, "")).strip():
                    warns.append("%s[%d] 缺字段 %s" % (k, idx, f))
            if k == "spots":
                tag = it.get("tag")
                if tag not in SPOT_TAGS_ACCEPT:
                    errors.append("spots[%d] tag=%r 非法" % (idx, tag))
                elif tag not in SPOT_TAGS_OK:
                    warns.append("spots[%d] tag=%r 是旧标签，建议用四标准标签" % (idx, tag))
            if k == "budget" and "参考" not in str(it.get("rangeText", "")):
                errors.append("budget[%d] rangeText 缺「（参考）」" % idx)
    chars = city_chars(sections)
    if chars < MIN_CHARS:
        warns.append("正文 %d 字（精品线 %d 字，约 %d 分钟）"
                     % (chars, MIN_CHARS, chars // 350))
    return errors, warns, chars


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+", help="JSON / *_city.py 文件（支持通配符）")
    ap.add_argument("--dry-run", action="store_true", help="只体检不写覆盖层")
    args = ap.parse_args()

    with io.open(SEED, encoding="utf-8") as f:
        seed = json.load(f)
    known = {c["key"]: c.get("name", "") for c in seed.get("cities", [])}

    files = []
    for p in args.paths:
        files.extend(sorted(glob.glob(p)) if any(ch in p for ch in "*?[") else [p])
    if not files:
        print("没有匹配到文件")
        return 1

    if not args.dry_run:
        os.makedirs(OV_DIR, exist_ok=True)

    total_ok, total_err = 0, 0
    for path in files:
        if not os.path.isfile(path):
            print("✗ 文件不存在：%s" % path)
            total_err += 1
            continue
        try:
            cities = (load_py_cities(path) if path.endswith(".py")
                      else load_json_city(path))
        except Exception as e:
            print("✗ %s 解析失败：%s" % (os.path.basename(path), e))
            total_err += 1
            continue
        if not cities:
            print("✗ %s 里没找到内容（JSON 对象或 city(...) 调用）"
                  % os.path.basename(path))
            total_err += 1
            continue

        for city in cities:
            errors, warns, chars = validate(city, set(known))
            key = city.get("key", "?")
            head = "%s :: %s(%s)" % (os.path.basename(path), known.get(key, ""), key)
            if errors:
                print("✗ %s" % head)
                for e in errors:
                    print("    ✗ %s" % e)
                for w in warns:
                    print("    ⚠ %s" % w)
                total_err += 1
                continue
            if not args.dry_run:
                out = os.path.join(OV_DIR, "%s.json" % key)
                with io.open(out, "w", encoding="utf-8") as f:
                    json.dump(city, f, ensure_ascii=False, separators=(",", ":"))
            print("✓ %s → %s（正文 %d 字 / 约 %d 分钟）%s"
                  % (head, "只体检" if args.dry_run else "scripts/guide_overrides/%s.json" % key,
                     chars, chars // 350, "" if not warns else "（%d 条提示）" % len(warns)))
            for w in warns:
                print("    ⚠ %s" % w)
            total_ok += 1

    print("-" * 64)
    print("导入 %d 城，失败 %d" % (total_ok, total_err))
    if total_ok and not args.dry_run:
        print("下一步：")
        print("  python scripts/_gen_guide_seed.py")
        print("  python scripts/check_guide_seed.py")
    return 0 if total_err == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
