#!/usr/bin/env python3
"""芥舟图标字体构建工具（V2.8.1 S4 · 构建期工具链，不入 pubspec 依赖树）。

用法：python design/icons/build_font.py
输入：design/icons/*.svg + design/icons/codepoints.json（提交后冻结）
输出：assets/fonts/JieZhouIcons.ttf

管线：SVG(stroke) --picosvg.topicosvg--> 填充轮廓 --TransformPen(缩放+Y翻转)-->
TTGlyphPen --> fontTools.FontBuilder --> TTF。
24×24 SVG 网格映射到 1000 upm（ascent 800 / descent -200）。
"""
import json
import sys
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen
from fontTools.misc.transform import Transform
from fontTools.svgLib.path import parse_path
from picosvg.svg import SVG

ROOT = Path(__file__).resolve().parent.parent.parent
ICON_DIR = ROOT / "design" / "icons"
OUT_TTF = ROOT / "assets" / "fonts" / "JieZhouIcons.ttf"

UPEM = 1000
GRID = 24.0
ASCENT = 800
DESCENT = -200
SCALE = UPEM / GRID  # 1000/24


def glyph_from_svg(svg_path: Path):
    """SVG → (TTGlyphPen 轮廓, 是否成功)。stroke 先拍平为填充。"""
    svg = SVG.fromstring(svg_path.read_text(encoding="utf-8"))
    pico = svg.topicosvg()  # stroke→fill、嵌套变换展开
    pen = TTGlyphPen(None)
    # x' = s·x ; y' = 24s − s·y（SVG y 向下 → 字体 y 向上）
    tpen = TransformPen(pen, Transform(SCALE, 0, 0, -SCALE, 0, GRID * SCALE))
    for shape in pico.shapes():
        parse_path(shape.d, tpen)
    return pen.glyph()


def main() -> int:
    codepoints = json.loads((ICON_DIR / "codepoints.json").read_text(encoding="utf-8"))
    names = sorted(codepoints)
    glyphs, cmap, metrics = {}, {}, {}
    for name in names:
        cp = int(codepoints[name], 16)
        try:
            glyph = glyph_from_svg(ICON_DIR / f"{name}.svg")
        except Exception as e:  # noqa: BLE001 — 构建工具要给出明确失败位
            print(f"[FAIL] {name}: {e}", file=sys.stderr)
            return 1
        glyphs[name] = glyph
        cmap[cp] = name
        metrics[name] = (UPEM, 0)  # 全部等宽方格

    glyph_order = [".notdef"] + names
    glyphs[".notdef"] = TTGlyphPen(None).glyph()
    metrics[".notdef"] = (UPEM, 0)

    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT)
    fb.setupNameTable({
        "familyName": "JieZhouIcons",
        "styleName": "Regular",
        "fullName": "JieZhouIcons",
        "psName": "JieZhouIcons",
        "version": "Version 1.000",
        "copyright": "© 2026 芥舟 · 原创绘制",
    })
    fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=DESCENT,
                usWinAscent=ASCENT, usWinDescent=-DESCENT,
                sCapHeight=700, sxHeight=500)
    fb.setupPost()
    OUT_TTF.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(OUT_TTF))
    print(f"OK: {OUT_TTF} ({len(names)} glyphs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
