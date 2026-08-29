# 芥舟 · 旅途助手（Purser Travel Assistant）

> 以芥为舟，行万水千山。

**芥舟**是一款纯本地离线运行的个人旅途工具，围绕出行三大主线：**行程规划 · 出行清单 · AA 记账**。所有数据只保存在你设备上，不上传任何服务器，无广告、无账号、无追踪。

跨平台：**Android（原生 App）+ Web（浏览器即用，桌面端专属布局）**。

## 功能一览

### 🗺️ 行程规划
- 行程编辑：日期范围、目的地、往返交通、同行成员
- 城市/景点离线库与在线 POI 补充（高德/QQ 地图可选，未配置自动降级离线+免费源）
- 行程地图、导出图片海报 / PDF / 格式备份（.tat/.tav）
- 机场库、国家/城市时区与天气信息（行程累计透明）

### ✅ 出行清单
- 按行程管理清单，内置常用场景模板（证件、衣物、数码…）与智能推荐
- 拖拽排序、快捷标记、进度卡片

### 💰 AA 记账
- 团购分摊：明细账、账单（正/负口径统一）、成员榜只看未结清
- 一键结算引擎（Settle），支持多成员最优债务清算
- 收支统计图表、预算预警、CSV 导入导出
- 局域网协同同步（移动端），无网络也能多端汇总

### 🔐 隐私与数据
- 数据全部存储在本地 SQLite（Android）或浏览器 IndexedDB（Web）
- 备份/恢复：跨端交换使用 `.tat` / `.tav` 文件
- 全程无任何后端服务

## 在线体验

| | 地址 |
| --- | --- |
| 官网 | <https://jiezhou.22006.dpdns.org/> |
| Web 应用（芥舟） | <https://purser.22006.dpdns.org/> |
| 源码仓库 | <https://github.com/qnh660022/jiezhou> |

> Web 端暂不支持手机端访问。


## 技术栈

- **框架**：Flutter（Material 3 设计系统 + 自研 tokens 主题令牌）
- **状态管理**：flutter_riverpod
- **本地数据库**：drift（SQLite）+ sqlite3-WASM（Web）/ IndexedDB
- **路由**：go_router（Web 端支持深链 & 桌面布局分流）
- **其他**：dio、flutter_map、fl_chart、pdf、share_plus 等
- **金额口径**：一律 int 分存储，仅展示层格式化；退款统一负数冲减

## 目录结构

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
