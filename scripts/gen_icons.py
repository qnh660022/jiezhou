# -*- coding: utf-8 -*-
"""生成 Android 全套启动图标，杜绝“白标”。见顶部注释。"""
from PIL import Image
from collections import deque
import os

SRC = r'D:\CBJ\桌面\未命名的设计.png'
RES = r'd:\AI\money2.0\android\app\src\main\res'

def tight_bbox_rgba(im, thr=200):
    """alpha>=thr 的紧致包围盒。"""
    px = im.load()
    w, h = im.size
    xs, ys, xe, ye = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            if px[x, y][3] >= thr:
                if x < xs: xs = x
                if x > xe: xe = x
                if y < ys: ys = y
                if y > ye: ye = y
    return xs, ys, xe + 1, ye + 1

def edge_color(im, bbox):
    """包围盒一圈的不透明像素平均颜色(用于自适应背景与旧版底色)。"""
    px = im.load()
    xs, ys, xe, ye = bbox
    tot = [0, 0, 0]; n = 0
    for x in range(xs, xe, max(1, (xe - xs) // 200)):
        for y in (ys, ye - 1):
            c = px[x, y]
            if c[3] >= 200:
                tot[0] += c[0]; tot[1] += c[1]; tot[2] += c[2]; n += 1
    for y in range(ys, ye, max(1, (ye - ys) // 200)):
        for x in (xs, xe - 1):
            c = px[x, y]
            if c[3] >= 200:
                tot[0] += c[0]; tot[1] += c[1]; tot[2] += c[2]; n += 1
    if n == 0:
        # 退化为采样整个 bbox 的非透明像素
        for y in range(ys, ye, max(1, (ye - ys) // 120)):
            for x in range(xs, xe, max(1, (xe - xs) // 120)):
                c = px[x, y]
                if c[3] >= 200:
                    tot[0] += c[0]; tot[1] += c[1]; tot[2] += c[2]; n += 1
    if n == 0:
        return (240, 243, 247)
    return tuple(t // n for t in tot)

im = Image.open(SRC).convert('RGBA')
w, h = im.size
thr = 200
tight = tight_bbox_rgba(im, thr)
print('opaque bbox', tight, 'size', (tight[2] - tight[0], tight[3] - tight[1]))
art = im.crop(tight)
bg = edge_color(im, tight)
hexbg = '#%02X%02X%02X' % bg
print('edge bg (rgb)', bg, hexbg)

# ---- 旧版图标：设计与底融为一体，全出血、整体不透明 ----
sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for folder, size in sizes.items():
    d = os.path.join(RES, f'mipmap-{folder}')
    os.makedirs(d, exist_ok=True)
    icon = Image.new('RGBA', (size, size), bg + (255,))
    a2 = art.resize((size, size), Image.LANCZOS)
    # 全不透明合成：以设计为主体，透明残留角用底色补齐 => 绝不露白
    icon.alpha_composite(a2, (0, 0))
    icon = icon.convert('RGB')
    icon.save(os.path.join(d, 'ic_launcher.png'), 'PNG')
    print('wrote legacy', folder, size)

# ---- 自适应前景：108dp*4=432；设计全出血铺满，四角交给背景色 ----
target = 432
a2 = art.resize((target, target), Image.LANCZOS)
fg = Image.new('RGBA', (target, target), bg + (255,))
fg.alpha_composite(a2, (0, 0))
os.makedirs(os.path.join(RES, 'mipmap-xxxhdpi'), exist_ok=True)
fg.save(os.path.join(RES, 'mipmap-xxxhdpi', 'ic_launcher_foreground.png'), 'PNG')
print('wrote adaptive foreground', target)

# ---- 背景色资源 + 自适应定义 ----
os.makedirs(os.path.join(RES, 'values'), exist_ok=True)
with open(os.path.join(RES, 'values', 'colors_ic_launcher.xml'), 'w', encoding='utf-8') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            f'    <color name="ic_launcher_background">{hexbg}</color>\n</resources>\n')
os.makedirs(os.path.join(RES, 'mipmap-anydpi-v26'), exist_ok=True)
for name in ('ic_launcher.xml', 'ic_launcher_round.xml'):
    with open(os.path.join(RES, 'mipmap-anydpi-v26', name), 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
print('DONE')