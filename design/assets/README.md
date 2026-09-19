# design/assets — 品牌图形素材与历史留档

本目录是设计素材（**只放素材，不放代码**）。所有 PNG 均随仓库入库，供未来重做图标时直接取用，不必再翻 git 历史。

---

## 当前生效的 Logo（V2.8.3.5 起 —— **按位置分两套**）

2026-09-19 16:30 裁定：**仅 Android 图标用旧版，其余位置全部用新版。**

### ① Android 图标 → 旧版「深蓝山峰」

深蓝山峰 + 回折箭头，`#B9C0CD` 灰蓝底 + 白色圆角方块，山峰**居中留白**。满版不透明。

| 文件 | 尺寸 | 说明 |
|---|---|---|
| `legacy/legacy_android_foreground_432.png` | 432² | **高清源** —— 比 192 那张清晰一倍多，与它 RMSE 3.59 属同构图 |
| `legacy/legacy_android_icon_192.png` | 192² | 与原 APK 图标字节一致（md5 `0a56ec0a`） |

落点：

```
android/.../mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png   48~192  不透明
android/.../mipmap-xxxhdpi/ic_launcher_foreground.png       432    自适应前景
```

`ic_launcher_background` = `#B9C0CD`（该图标自身底色，与前景无缝）。

### ② 应用内 / Web / PWA / 宣发站 → 新版「满版青山」

透明底圆角方形，**山脉延伸到左右边缘**，比旧版更满。

| 文件 | 尺寸 | 说明 |
|---|---|---|
| `user_logo_source.png` | 1246×1250 | **高清源**（用户 2026-09-19 提供） |

落点：

```
assets/img/logo.png                          512  开屏页 / 关于页 / 桌面 shell（透明留白）
web/icons/Icon-{192,512}.png                 192/512  PWA（浅底 #E9EEF2）
web/icons/Icon-maskable-{192,512}.png        192/512  PWA maskable（图形缩到 80% 安全区）
web/logo.png / web/favicon.png               192 / 64
website/assets/logo.png                      512  宣发站（透明留白）
```

### 两套构图的关系

像素级实测 **RMSE = 42.6** → **同一套设计的两个版本，不是同一张图**。差异集中在圆角半径与山体缩放：

| | 旧版（安卓） | 新版（其余） |
|---|---|---|
| 圆角 | 大圆角（近超椭圆） | 小圆角，更方 |
| 山体 | 居中**留白**，四周空 | **延伸到左右边缘**（被裁切） |
| 观感 | 收敛，像嵌在卡片里 | 满版，更大气 |

核对图：`final_logo_split_check.png`（本文件描述的分配结果）。

---

## 历史版本（`legacy/`，已停止使用）

仓库历史上一共存过 **3 套不同的设计**：

| 设计 | md5 | 曾用位置 | 文件 |
|---|---|---|---|
| ① 深蓝山峰 + 回折箭头 | `0a56ec0a` | 安卓图标 / web logo / 宣发站 | `legacy_android_icon_192.png`、`legacy_android_foreground_432.png`、`legacy_web_logo_192.png` |
| ② 蓝金渐变方块 + 金色舟形 | `6464a6ae` | 「关于」页 | `legacy_about_icon_256.png` |
| ③ 另一版（构图同 ① 但更满） | `085caba1` | 宣发站某一版 | `legacy_website_logo_2492.png` |

**`legacy_favicon_16.png`** 是 16px 的历史小图，已废弃（现用 64px 版）。

---

## 曾经的候选（未采用，仅备查）

| 文件 | 说明 |
|---|---|
| `mountain_logo_2048.png` | 原始设计母版：**深蓝外底 + 白圆角方块 + 满版山峰**（山河构图比现用版更满） |
| `mountain_logo_body_2048.png` | 上者裁掉深蓝外底后的方正版 |
| `mountain_logo_transparent_2048.png` | 上者的透明底圆角方形版 |
| `user_logo_source.png` | 用户 2026-09-19 提供的一版（1246×1250，山峰延伸到左右边缘）；**与现用版是同一设计的两版构图，RMSE=42.6** |
| `logo_old_bluegold_256.png` | 同历史版本 ② |
| `logo_current_icon_192.png` | 同历史版本 ①（192） |
| `preview_round_*.png` / `preview_square_192.png` | 当时做圆形/方形裁切预览用的中间产物 |

对照图：`old_vs_new_compare.png`（现用版 vs 用户 9-19 提供版）、`legacy_logo_compare.png`（各历史版本）、`pwa_icons_before.png`（换装前 PWA 目录里竟是 Flutter 模板图标）。

---

## 重做图标的注意事项

1. **源图择大**：能拿到 432 就别用 192 —— 192 → 512 是 2.67 倍放大，边缘会糊。
2. **legacy 图标必须不透明**：`ic_launcher.png`（五档）四角透明会在老启动器上露黑/白块，用底色填充。
3. **只有 `ic_launcher_foreground.png` 用透明底**，且图形要缩到 432 的约 66%（≈285）安全区。
4. **maskable 图标留 10% 安全边距**：图形缩到 80%，四周铺底色，被裁成圆形/水滴后边缘才连续。
5. **换完要卸载重装**：安卓桌面图标有缓存，直接覆盖安装通常看不到变化（或需清启动器缓存）。
6. 本项目已装 Pillow（隔离 venv `~/.workbuddy/binaries/python/envs/default`），派生脚本见 `~/.workbuddy/outputs/_v2835_*.py`。
