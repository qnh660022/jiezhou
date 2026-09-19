# 芥舟 · 旅途助手（JieZhou Travel Assistant）

[![版本](https://img.shields.io/badge/version-V2.8-informational)](https://github.com/qnh660022/jiezhou/releases)
[![协议](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![平台](https://img.shields.io/badge/platform-Android%20%7C%20Web-lightgrey)](#)
[![Flutter](https://img.shields.io/badge/Flutter-Material%203-02569B)](#)
[![测试](https://img.shields.io/badge/tests-passing-success)](#)
[![同步](https://img.shields.io/badge/sync-cloud%20%7C%20LAN-blueviolet)](#)

> 以芥为舟，行万水千山。（当前版本 **V2.8**）

**芥舟**（V2.8）是一款开源的个人旅途工具，围绕出行四大主线：**行程规划 · 城市攻略 · 出行清单 · AA 记账**。支持云端与局域网两种多端同步方式（Supabase 端点可自托管 / 换镜像），无广告、无追踪。

跨平台：**Android（原生 App）+ Web（浏览器即用，桌面端专属布局）**。

> **搜索关键词**：旅行 App · 行程规划 · 旅行攻略 · 城市攻略 · 出行清单 · AA 记账 · 旅行记账 · 多人分摊 · 结算 · 公款池 · 旅行基金 · Plan B · 旅伴共享 · 开源免费 · 安卓 · Flutter

**English** — JieZhou (Purser) Travel Assistant is an open-source travel app for Android and the web, written in Flutter. It bundles four modules: **trip planning** (multi-day timeline, drag & drop, outline round-trip editing), **city guides** (structured guidebooks with six sections per city), **packing checklists**, and **AA expense splitting** (group splitting, percentage mode, travel fund pool, optimal settlement, PDF export). Optional collaborative spaces with three role levels (owner / editor / viewer), invite links and read-only share links. Cloud (Supabase, self-hostable) and LAN sync. No ads, no tracking, Apache-2.0 licensed.

## 功能一览

### 🗺️ 行程规划
- 行程编辑：日期范围、目的地、往返交通、同行成员
- 多天时间线：交通 / 住宿 / 景点逐项码入同一条线，支持拖拽排序、跨天移动与多选批量
- 增减天数顺延引擎：插入或删除一天，后续安排自动平移（删天可选处理方式）
- 大纲双向编辑：整份行程可导出为纯文本，改完原样导回（确定性规则解析，非模型解析）
- 想去池与装配台：看中的条目先收进想去池，再按「一天的容量三档（松 / 标准 / 紧凑）」自动找空档落位
- Plan B 备胎：给某一天挂一位替补，可一键与主安排互换
- 行程模板：内置模板可就着改动，不必从零排起
- 展示与导出：行程 PDF（含总览页）、图片海报、`.tat` / `.tav` 格式备份

### 📖 城市攻略
- 覆盖主要旅行目的地，按大区归类，换城市即换册
- 每城六栏结构化内容：**行前准备 / 景点推荐 / 美食 / 交通 / 避坑注意 / 预算参考**
- 景点条目带类型标签（必去 / 经典 / 小众 / 亲子）与预估时长，正文含顺路与时段提示
- 双动作入行程：任一攻略条目可「直接排入某天」，或「先收进想去池」；安排卡与攻略条目双向互链
- 城市锦囊：把某城的行前准备、贴士、预算等挂进行程页，「行前准备」可一键转成出行清单
- 攻略随包内置，落地即翻

### ✅ 出行清单
- 按行程管理清单，内置常用场景模板（证件、衣物、数码…）
- 拖拽排序、快捷标记、进度卡片
- 可从攻略的「行前准备」一键生成

### 💰 AA 记账
- 团购分摊：明细账、账单（正 / 负口径统一）、成员榜只看未结清
- 分摊模式：人头制与**百分比制**（余数自动归一，不出现分不平）
- **公款池（旅行基金）**：一池一管理人，先充后花，池余额纳入结算口径
- **记账收件箱**：来不及归类先记进暂存区，回头再分；独立表且参与云同步
- **结算策略可选**：最少笔数 / 最少人参与；一键最优债务清算
- 个人账本：与团账互相独立，单独成册
- 统计与预算：收支趋势折线、时间范围筛选、分类子预算（自选，上限 5）
- 支付方式标记；变更记录（管理角色可见）
- 导出：PDF 账本、结算单分享卡、CSV 快照

### 🤝 旅伴协作与权限
- 旅伴空间：以「空间」组织一次同行，成员、账本与行程随之共享
- 三级角色：**owner（管理者）/ editor（编辑者）/ viewer（观察者）**。邀请时即定角色；viewer 全链路只读，写入口不渲染
- 邀请码入团：`/invite?c=<code>`，对方登录后自动加入该空间
- 只读分享链接：`/s/<token>`，可加访问口令；未登录也能查看，但只能读、不能写
- 局域网协作：同一网络下设备间直接合并记录，传输带 HMAC-SHA256 完整性校验
- 云端同步：Supabase，端点可自托管 / 换镜像

### 🔐 数据、同步与隐私
- 数据库：drift（SQLite，Android）/ IndexedDB（Web）
- 多端同步：云端（Supabase，端点可自托管 / 换镜像）与局域网直连两种方式
- 备份 / 迁移：跨端交换使用 `.tat` / `.tav` 文件，另可导出 PDF / CSV 快照
- 启动锁：6 位数字 PIN（不做生物识别）
- 无广告、无追踪，不采集行程与账单用于商业用途

## 目录结构

- `lib/` Flutter 源码（features 业务、data 仓储与同步、theme 主题、platform 平台门面）
- `web/` Web 壳与 drift worker；`website/` 官网静态页
- `docs/` 规格书与验收文档（`db_v26.sql` 为云端建库脚本）
- `scripts/` 构建/环境脚本；`release/` APK 产物（历史版本在 `release/archive/`）
- 根目录 `vercel.json` 是 **Web 应用**（purser 站点，Flutter 构建产物）的 Vercel 部署配置；`website/vercel.json` 属**官网静态站**，二者归属不同站点，故并存

## 在线体验

| | 地址 |
| --- | --- |
| 官网 | <https://jiezhou.22006.dpdns.org/> |
| Web 应用（芥舟） | <https://purser.22006.dpdns.org/> |
| 源码仓库 | <https://github.com/qnh660022/jiezhou> |
| 更新日志 / 历史版本 | <https://github.com/qnh660022/jiezhou/releases> |

> Web 端暂不支持手机端访问。
> 只读分享链接形如 `https://purser.22006.dpdns.org/s/<token>`，邀请链接形如 `https://purser.22006.dpdns.org/invite?c=<code>`。

## 技术栈

- **框架**：Flutter（Material 3 设计系统 + 自研 tokens 主题令牌 + 自研图标字体 `JieZhouIcons`）
- **状态管理**：flutter_riverpod
- **数据库**：drift（SQLite）+ sqlite3-WASM（Web）/ IndexedDB
- **路由**：go_router（Web 端支持深链、只读分享页 `/s/<token>` 与桌面布局分流）
- **云端（可选）**：supabase_flutter（可自托管 / 换镜像）
- **其他**：dio、fl_chart、pdf、share_plus、qr_flutter / zxing2（扫码）、crypto（HMAC-SHA256 与 PBKDF2）、archive、image_picker
- **Web 端**：桌面专属布局（多列工作台、命令面板、上下文菜单、同步中心）
- **金额口径**：一律 int 分存储，仅展示层格式化；退款统一负数冲减
- **设计约定**：模态分四层（轻提示 / 确认 / 操作抽屉 / 表单抽屉）；功能图标只走 `AppIcons.*` 或 `Icons.*_rounded` 两族

## 本地构建

需要 Flutter SDK（Dart 3.13+）。

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 生成 drift 代码
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 \
  --dart-define=SUPABASE_URL=<你的端点> \
  --dart-define=SUPABASE_ANON_KEY=<你的 anon key>
```

- Web 端：`flutter build web`，产物在 `build/web/`（部署配置见 `vercel.json`）。
- 构建时可用 `--dart-define` 注入你自己的 Supabase 端点；不注入也能构建。
- 首次运行需初始化数据库：云端建库脚本见 `docs/`（`db_v26.sql` 起，逐版增量）。

## 代码组织

```
lib/
  main.dart / app.dart / router.dart   # 入口 / 根组件 / 路由（移动+桌面分流）
  core/                                # 金额、日期、UID、错误恢复等基础能力
  data/
    db/                                # drift 表结构与 DAO
    repo/                              # 访问仓储
    seed/                              # 离线种子数据（机场、城市、货币、清单模板…）
    services/                          # POI / 天气 / 航班 / 汇率（可配置密钥，含免费降级）
  domain/                              # 结算引擎、统计、备份、CSV、分摊等纯逻辑
  export/                              # 海报 / PDF / 备份格式与平台分享
  features/
    trips/ checklist/ ledger/          # 三大主线（移动 + 桌面 Workbench）
    desktop/                           # 桌面壳、命令面板、上下文菜单、同步中心
    settings/                          # 主题、隐私、关于等
  platform/                            # Web/IO 平台适配（db/fs/gzip/通知/右键守卫…）
website/                               # 官网静态站（独立 Vercel 项目，见 README 下文）
scripts/                               # 构建与本地预览脚本
test/                                  # 单元 + Widget 测试
```

## 开源协议

本项目基于 [Apache License 2.0](LICENSE)。Copyright © 2026 芥舟（JieZhou Travel Assistant）。

### 贡献

欢迎提 Issue 或 PR！
