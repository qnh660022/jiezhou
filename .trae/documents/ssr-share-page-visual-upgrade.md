# /s/<token> SSR 分享页视觉升级（渐变 Hero 封面风 · 纯视觉精修）

## Summary

现有 SSR 分享页（`api/share.ts`）按方案 B 规格「完全对齐 App 版」渲染，而 App 版分享页本身只是极简 ListTile 卡片，导致页面观感简陋。本次升级**仅重写渲染层（模板 + CSS）**，采用「品牌绿渐变 Hero 封面 + 白卡上浮 + 时间线分组」的现代视觉，内容数据与渲染规则（§3.3 语义、转义、og、页脚、错误文案）保持不变。

已确认决策（用户 2026-09-13 三问定案）：

1. **纯视觉精修**：不新增任何统计数字（不做总花费/人均/条目数），不加 og:image；
2. **保持固定浅色**（决策 #7 不变）；
3. **渐变 Hero 封面风**：头部品牌绿渐变、白卡上浮、行程按日分组+时间线轴、圆角对齐 App 令牌（24/16/14）、微动画淡入。

约束不变：零 npm 依赖、TypeScript 单文件、全部动态文本 HTML 转义、`Cache-Control: no-store`、og 规则 §5.6、页脚品牌位+推广位、口令/防爆破/cookie 逻辑零改动。

## Current State Analysis

* [api/share.ts](file:///d:/AI/money2.0/api/share.ts)（467 行）：逻辑层（RPC/cookie/防爆破/流程分派）与渲染层（STYLE 常量 + tripBody/groupBody/passBody/noticeBody/htmlPage + esc/fmtDay/costHtml/amountHtml/metaFor）耦合在同一文件。

* 现视觉：灰底 + 左侧绿竖条封面 + 白卡描边直排，无封面层次、无分组、无动画。

* 数据契约：行程 items 已按 `dateEpochDay, sortOrder` 排序（可直接分组）；members 含 `colorIndex`（现未渲染，可用于头像圆点配色，属既有字段纯视觉利用）；`startEpochDay/endEpochDay` 仅用于 og，可复用做 Hero 日期胶囊（不新增数据）。

* 本地已部署方案 A/B；`vercel.json` 本次**零改动**；Flutter 侧**零改动**。

## Proposed Changes

**唯一改动文件：`api/share.ts`**（其余文件除文档外一律不动）。

### 1. 设计令牌（STYLE 重写，CSS 变量）

```
--brand:#00A878  --brand-deep:#007F5C  渐变:linear-gradient(135deg,#00B386,#007F5C)
--bg:#F2F6F4  --card:#FFF  --line:#E6EDE9
--ink:#1C2B26  --ink2:#66756E  --ink3:#8A9992
--income:#1E9E6A(不变)  --err:#D05A4E
圆角: hero 卡 24 / 条目卡 16 / 按钮·输入 14 / 胶囊 999
字号: 34(hero 名) 26(hero 备用) 15/17(标题) 13(辅文) 12(页脚)
```

### 2. 渲染层重写（函数签名与逻辑层接口不变）

* **新增** **`heroHtml()`** **公共构建器**：满宽渐变区（`padding: 40px 20px 72px`），内容含：

  * emoji 徽章：64px 圆 `rgba(255,255,255,.22)`，字号 34；

  * 大标题（白、700、26px，`word-break:break-all`）；

  * 行程：📍destination（白 85%，非空才显示）+ 日期胶囊 `M月d日 – M月d日`（start/end 均有效才显示，`rgba(255,255,255,.2)` 胶囊）+ 「与「groupName」同行」白 75% 小字（非空才显示）；

  * 账本：成员头像行（36px 圆，背景色按 `colorIndex` 从 6 色板取值 `#00A878/#2F80ED/#F2994A/#F06B9C/#7B61FF/#E0B14B`，白色首字，溢出显示 `+N`），名称白 85%。

* **内容容器**：`max-width:640px; margin:-48px auto 0`，白卡浮在渐变上（radius 24、`box-shadow:0 8px 24px rgba(0,60,40,.10)`）。

* **行程页**：条目按 `dateEpochDay` 分组（null 归入「日期待定」组），每组头部日期胶囊（`M月d日 周X`，周X 由既有日期按 UTC 派生，纯展示）；组内时间线轴：左侧 10px 圆点 + 竖线 `#DFE9E4` 连接；条目卡（白、radius 16）：标题 15/600、副标「地址」13 灰、右侧金额绿色胶囊（`#E6F7F1` 底 + brand 字），`costCents` 为 null 不显示（规则不变）。

* **账本页**：小节标题「账单明细/近期结算」用 13px 灰 600 + 上间距节奏；账单卡左侧加类别图标（仅视觉映射，`food:🍜 transport:🚌 hotel:🏨 ticket:🎫 shopping:🛍️ play:🎮 medical:💊 flight:✈️ train:🚄 living:🏠 other:🧾`，未知回退 🧾）+ `categoryKey` 原文 13 灰（原文展示规则不变）；金额右侧规则**原样保留**（正数黑、负数 `-`+收入绿）；结算卡 🤝 + `第 N 轮 · transfersJson 转义原文`（等宽字体 12px）。

* **口令页**：居中白卡上浮，渐变圆徽章内 🔒，输入框 160px、字距 8、聚焦变 brand，按钮渐变胶囊；错误行 `--err`；文案不变（「输入 4 位口令/验证/口令不正确/请输入 4 位数字口令」）。

* **错误/锁定页**：渐变 Hero 不出现；居中 64px 浅绿圆 `#E6F7F1` + 内联 SVG 波浪线（保留现有 SVG），文案不变。

* **页脚**：推广位改白色胶囊按钮（brand 字、brand 30% 描边、轻投影），品牌行 12px 灰；仍置于品牌行上方、`target="_blank" rel="noopener"`、`PROMO_URL` 常量不变。

* **空态**：行程「🗺️ 暂无行程安排」、账本「💤 暂无账单」，图标 40px + 居中灰字。

* **微动画**：`.wrap` 直接子元素 `fade-up .4s ease both` + `nth-child` 阶梯延迟（上限 8 个，40ms 步进）；`@media (prefers-reduced-motion: reduce)` 全部禁用。

### 3. 硬性不变项（回归红线）

* 所有动态文本仍经 `esc()`；`transfersJson` 转义原文、不解析；`costCents` 整数、账单金额两位小数、负数 `-` 前缀收入绿；日期按 UTC；token/口令校验、RPC 调用、cookie、防爆破、303 PRG、`no-store`、og 中性文案规则**零改动**；`<title>` 与 og:title 同值；`twitter:card` 保留。

## Assumptions & Decisions

* 行程日期胶囊与「周X」、成员彩色头像、类别图标均为**既有契约字段的纯视觉呈现**，不属于「新增统计数字」，符合用户「纯视觉精修」的范围界定。

* 预期行数 \~650（现 467），超出规格 250\~400 的偏差已在部署说明实现注记登记，本次继续登记更新。

* 文档：`docs/方案B部署说明.md` 追加「V2 视觉升级」小节（改了什么、验收不变项）。规格文档本身不改。

* 交付后 **git commit（不 push）**；`vercel.json`/Flutter/APK 均不涉及（Vercel 部署在你 push 后自动生效，届时按部署说明第 5 节复验即可）。

## Verification

1. **重建本地自测 harness**（仓库根 `_test_share.mjs`，测后即删）：Node 24 直调函数，mock fetch + 真实 Supabase RPC（nil UUID）双路。

   * 逻辑断言组全部保留：非法 token 不调 RPC / need\_pass 表单与中性 og / 错误口令计数与 5 次锁定 / 303+Set-Cookie 属性 / 带 cookie 直进内容页 / Max-Age=0 清除 / 表单本地校验 / env 缺失「加载失败」/ RPC 500 / 真实 not\_found / 全响应体 grep anon key = 0；

   * 新增视觉断言：渐变 hero 存在、行程日分组胶囊、类别图标与原文共存、成员头像色、结算等宽字体、转义仍生效（hero 内 `&lt;b&gt;`、`&quot;`）、`prefers-reduced-motion` 块存在；

   * 目标 0 FAIL。
2. `vercel.json` diff 为空、`git status` 仅 `api/share.ts` 与文档变更。
3. 手工抽查渲染 HTML（保存一份样例输出人工过目布局）。

