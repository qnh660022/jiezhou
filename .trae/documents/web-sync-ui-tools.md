# Web 端三期增强：多端同步 + 桌面 UI 优化 + 效率化工具

## 摘要

在已完成的桌面 Web 版（左侧导航 + 行程/账本主从工作台）基础上，做三期增强：

- **A. 多端同步**：① 全量备份/恢复（一键导出「全部团 + 全部行程」）；② 二维码/口令码快照同步（Web↔手机，无后端）；③ 局域网同步经评估**不实现**（浏览器限制，见 A3）。
- **B. 桌面 UI 优化**：顶部工具栏、清单/我的页桌面化、账本表格化增强、行程时间轴可视化。
- **C. 效率化工具**：全局搜索 + 命令面板（Ctrl+K）、CSV 批量导入账单（含付款人/分账人补充）、桌面快捷键完善、CSV 导出增强（分账人/分摊明细）。

完成后执行 `flutter analyze`（0 错误）、`flutter test`（全绿）、`flutter build web --release` + `node scripts/preview.mjs` 挂载本地预览（http://localhost:8080）。

---

## 现状分析（已核对代码）

- 桌面壳：[desktop_shell.dart](file:///d:/AI/money2.0/lib/features/desktop/desktop_shell.dart) 左侧导航（可拖宽）+ 内容区；**无顶部工具栏、无全局快捷键、无命令面板**。
- 工作台：[desktop_ledger_workbench.dart](file:///d:/AI/money2.0/lib/features/ledger/desktop_ledger_workbench.dart)、[desktop_trips_workbench.dart](file:///d:/AI/money2.0/lib/features/trips/desktop_trips_workbench.dart) 已实现主从分栏、右键菜单、行内改名/改日期、批量操作（行程）。
- 同步现状：Web 仅能通过 `.tav`（单团）/ `.tat`（单行程）备份文件与手机互传；局域网同步 [lan_sync_service_web.dart](file:///d:/AI/money2.0/lib/features/ledger/lan_sync_service_web.dart) 为占位抛错。**无全量备份、无二维码、无云同步**。
- 导出层：[ledger_repo.dart](file:///d:/AI/money2.0/lib/data/repo/ledger_repo.dart#L397-L462) 已有单团整包（`_buildFullGroupMap` 稳定 id）+ 局域网快照（额外带全机行程）与 `mergeGroupSnapshotJson`（按稳定 id LWW upsert，已含团/成员/账单/结算/行程/安排/分类）。`trips_repo.dart` 有单行程 `.tat` 导出/导入（换发新 id）。
- CSV 导出：[csv_builder.dart](file:///d:/AI/money2.0/lib/domain/csv_builder.dart) 已 15 列（含「付款人」姓名列），**缺「分账人名单/分摊明细」列**；无 CSV 导入。
- 清单页：[checklist_screen.dart](file:///d:/AI/money2.0/lib/features/checklist/screens/checklist_screen.dart) 仍为手机单列（分段控件 + 列表）；「我的」页 [profile_screen.dart](file:///d:/AI/money2.0/lib/features/settings/screens/profile_screen.dart) 单列 ListView。
- 快捷键：全局 `CallbackShortcuts` **未实现**（仅计划文档提及）。
- 依赖：[pubspec.yaml](file:///d:/AI/money2.0/pubspec.yaml) 已有 file_picker / image_picker / share_plus / web / archive。

---

## 关键决策与假设

1. **局域网同步不实现**（用户已同意「不行就算了」）：
   - 浏览器无法绑定 UDP、无法作为主机监听；Web 仅能作为「加入方」访问 `http://<LAN-IP>:45681/snapshot`。
   - 生产部署在 Vercel（HTTPS）时，请求 `http://` 局域网地址被浏览器**混合内容 + Private Network Access（PNA）**拦截；且手机端主机需加 CORS 头并改动手机端协议。仅本地 http 预览可用，生产价值低。
   - 结论：不做。Web 端「局域网同步」入口一律替换为「与手机同步」（备份文件 / 二维码 / 口令码）。
2. **允许新增依赖**（用户已确认）：`qr_flutter`（Web 渲染二维码）+ `zxing2`（纯 Dart 二维码解码，安卓拍照/相册解码）。均为纯 Flutter/Dart，无原生代码，不影响 Vercel 挂载。
3. **只改 UI + 少量数据层新增**：复用全部 repo/provider/模型；新增全量备份与 CSV 批量导入的数据层方法，不破坏既有行为。
4. **安卓零回归**：所有桌面分支以 `isDesktopWeb` 隔离；安卓仅新增「扫码/口令同步」入口（新增 UI + 新屏幕），不动既有页面逻辑。
5. **不动 web/ 构建产物**：`web/drift_worker.dart*`、`web/sqlite3.wasm`、`out.js*` 由既有构建管线生成，本任务不做手工修改；本地预览用 `flutter build web --release` + `node scripts/preview.mjs`。

---

## Part A：多端同步方案

### A1 全量备份 / 恢复（增强文件互传）

**目标**：一键把「全部团（成员/账单/结算/行程及安排/自定义分类）+ 未绑团行程」打包为一个文件，手机/Web 均可导入，覆盖「换机迁移 / 双端互通」场景。

**数据层**（`lib/data/repo/ledger_repo.dart` 改）：
- 新增魔数 `kFullBackupMagic = [0x54,0x41,0x31,0x41]`（"TA1A"，`lib/export/backup_format.dart` 改）。
- `Future<Uint8List> exportFullBackupBytes()`：
  - 遍历全部团，每团复用 `_buildFullGroupMap(gid)`（稳定 id）；
  - 收集 `groupId == null` 的未绑团行程（含 items）；
  - 组装根结构 `{app:'travel-assistant-v2', version:2, kind:'full', groups:[{...fullGroupMap}], standaloneTrips:[{...trip,'items':[...]}]}` → `encodeBackup(kFullBackupMagic, root)`。
- `Future<FullImportReport> importFullBackupBytes(Uint8List bytes, {required bool replace})`：
  - `replace=true`：按外键顺序清空（expenses → settlements → tripItems → checklistItems → albumPhotos → trips → members → categories → groups）后导入，作为「恢复」；
  - `replace=false`：逐团复用现有 `mergeGroupSnapshotJson`（单团根结构包一层），未绑团行程新增 `trips_repo.upsertTripSnapshot(...)`（按稳定 id upsert 行程+安排+清单，新增方法，`lib/data/repo/trips_repo.dart` 改）；
  - 返回人类可读摘要（团数/成员/账单/行程/安排/分类复用数）。

**UI**：新增 `lib/features/desktop/sync/desktop_sync_center.dart`（新，桌面「与手机同步」中心，Dialog）：
- ① 导出全量备份（下载 `.tavA`）；② 导入全量备份（FilePicker，选择合并/覆盖）；③ 导入单团 `.tav` / 单行程 `.tat`（复用现有 import 路径，已存在于 group_list / trips_home，集中入口）。
- ④ 二维码导出（见 A2）；⑤ 口令码粘贴导入（见 A2）。
- 底部操作指引：手机端「账本→团管理→导入」/「行程→菜单→导入」步骤说明。

### A2 二维码 / 口令码快照同步（无后端）

**思路**：快照 JSON（稳定 id）→ gzip → base64url 同步码。体积小→渲染二维码；体积超限→自动提示改用文件互传；反向（手机→Web）走「口令码粘贴」。

**通用工具** `lib/features/desktop/sync/sync_code.dart`（新，纯 Dart 可单测）：
- `String encodeSyncCode(String json)`：gzip + base64url（raw）。
- `String decodeSyncCode(String code)`：base64url 解码 + gunzip，非法抛 `FormatException`。
- 分块：`List<String> chunkCode(String code, {int chunkLen = 800})`；块头格式 `TSQ1|<total>|<index>|<chunk>`（总块数≤12，超出提示改用文件）。

**Web 端（导出方）**：`desktop_sync_center.dart` 内「二维码导出」：
- 选择范围：当前团 / 指定行程 / 全量；
- 取对应快照 → `encodeSyncCode` → 若 `base64 长度 ≤ 800*12` → 用 `qr_flutter`（`QrImageView`）逐块渲染，翻页/序号显示；否则提示改用文件互传。
- 「口令码」页签：展示完整同步码，复制按钮（`Clipboard`）+ 浏览器下载 `.tsync` 文本。

**安卓端（导入方）** `lib/features/ledger/screens/qr_scan_screen.dart`（新）：
- 入口：`group_list_screen.dart` 与 `trips_home_screen.dart` 工具栏新增「扫码同步」（Android 分支；Web 端隐藏）。
- 交互：`image_picker` 拍照/相册 → `zxing2`（`ZXingDecoder().decodeImage`）逐块解码 → 按块头组装 → `decodeSyncCode` → 是团快照则 `mergeGroupSnapshot`（已有），是 `.tat` 单行程结构则复用 `trips_repo.importTripBackupBytes`；给出合并摘要。
- 另提供「粘贴同步码」输入框（反向兜底：Web 显示码 → 手机粘贴；或手机显示码 → Web 粘贴导入）。
- 加载态/错误态齐全；不阻塞 Web 构建（`zxing2` 纯 Dart，`image_picker` 已有）。

**反向（手机 → Web）**：手机端复用「口令码」能力（新增从 `desktop_sync_center` 复用的 `sync_code.dart` 导出码 + 复制/分享），Web 端在同步中心「粘贴同步码导入」。

### A3 局域网同步：结论（不实现）

见「关键决策 1」。桌面同步中心不出现「局域网同步」入口，统一为「与手机同步」。

---

## Part B：桌面 UI 优化

### B1 顶部工具栏（`lib/features/desktop/desktop_shell.dart` 改）

在 `DesktopShell` 内容区上方加一条**全局工具栏**（高度约 44，桌面态专属）：
- 左：当前分支 emoji + 名称（随 `shell.currentIndex` 联动 `_tabs`）。
- 中：全局搜索输入框（只读样式，点击或 Ctrl+K 呼出命令面板；Ctrl+F 聚焦）。
- 右：按分支的快捷动作（账本→「记一笔」；行程→「新建行程」）+ 「与手机同步」按钮（打开 `desktop_sync_center`）+ 主题切换图标（复用 `themeProvider`）。
- 底：细字快捷键提示条（`Ctrl+N 新建 · Ctrl+K 命令 · Ctrl+F 搜索 · Esc 关闭`）。

### B2 清单页桌面化（`lib/features/checklist/desktop_checklist_workbench.dart` 新）

- 仅 `isDesktopWeb` 分支由 [router.dart](file:///d:/AI/money2.0/lib/router.dart#L78-L91) 改用本工作台（`/checklist`）。
- 布局：左列 = 清单类型分段（行李/待办）+ 行程选择 + 搜索 + 模板按钮（复用 `smart_template_sheet`、`trip_chip_selector`）；右列 = 当前清单条目（复用 `ChecklistProgressCard`、`ChecklistItemTile`）+ 进度总览。
- 复用 `checklistRepoProvider` 流与既有条目增删改，只改布局，不改数据逻辑。

### B3 我的页桌面化（`lib/features/settings/screens/profile_screen.dart` 改）

- `isDesktopWeb` 时：入口列表改为响应式两列网格（`LayoutBuilder` + `Wrap`，卡片定宽），外容器限宽 `DesktopLayout.contentMaxWidth`，去除底部大留白；保持手机端单列不变。

### B4 账本表格化增强（`lib/features/ledger/desktop_ledger_workbench.dart` 改）

- **可排序列头**：`_BillColumnHeader` 的「日期」「金额」点击切换升/降序（新增排序状态），其余列按标题排序。
- **行悬浮操作**：`_ExpenseRow` 用 `MouseRegion` 悬浮显示编辑/删除图标按钮（保留双击/右键）。
- **多选批量删除**：左上角「多选」开关 → 行首 Checkbox → 底部操作条「删除所选 N 笔」（带确认，复用 `deleteExpense`）。
- 列宽可调暂不做（避免过度工程），以排序 + 悬浮 + 多选覆盖主要效率点。

### B5 行程时间轴可视化（`lib/features/trips/desktop_trips_workbench.dart` 改）

- `_DesktopTripPane` 右上新增「列表 / 时间轴」切换（`SegmentedButton`）。
- 时间轴视图：按天分组，每天一条横向时间轴（0-24 时），安排以等比例色块渲染（类型图标 + 名称 + 时间）；横向拖拽色块调整 `startTimeMin`（clamp 到当天，跨天拖到相邻日则改 `dateEpochDay`）；双击色块打开 `ItemEditScreen`。
- 当天色块按 `startTimeMin` 排序；无时间安排归入「全天」区块。
- 拖拽改动走现有 `tripsRepoProvider.updateItem`，复用数据层，零逻辑改动。

### B6 桌面一致性打磨（贯穿各桌面文件）

- 侧边栏（`desktop_shell.dart`）新增常驻「与手机同步」入口按钮（打开同步中心）+ 版本号展示。
- 各工作台 Master 面板顶部加**概览条**：行程面板显示「共 N 个 · 进行中 M 个」；账本面板显示「本月支出 ¥X · 未结算 Y 笔」（复用 `expensesProvider`/`classifyTrip`，只读统计）。
- 对话框统一宽度、空态/加载态一致（复用 `EmptyState` / `SkeletonBox`）。

---

## Part C：效率化工具

### C1 全局搜索 + 命令面板（`lib/features/desktop/command_palette.dart` 新）

- 快捷键 `Ctrl/Cmd+K` 打开（`DesktopShell` 用 `CallbackShortcuts` 接入）。
- 内容：顶部搜索框 + 结果分组：
  - 行程（名称/目的地）→ 跳 `context.push('/trips/detail', extra:id)` 或选中工作台；
  - 账单（标题/备注）→ 选中账本工作台该笔；
  - 清单条目（名称）→ 跳清单；
  - 成员 / 团 → 切换团。
- 命令动作（输入 `/` 或固定列表）：新建行程、记一笔、切团、打开结算/统计/预算/成员、导出备份、与手机同步、切换主题。
- 数据来自既有 provider（`watchTrips`、`expensesProvider`、`checklistRepoProvider`、`membersProvider`、`groupsProvider`），纯前端查询。

### C2 CSV 批量导入账单（含付款人/分账人补充）

**解析**：`lib/domain/csv_parser.dart`（新）`List<List<String>> parseCsv(String text)`（BOM、引号、CRLF 兼容）。

**导入屏** `lib/features/ledger/screens/expense_csv_import_screen.dart`（新，桌面 Dialog + 手机可 push）：
1. FilePicker 选 `.csv` → 解析 → 预览前 10 行。
2. 列映射：每列下拉选择 日期/标题/金额/分类/币种/备注/**付款人**/**分账人**（可多列分账人）/**分摊方式**；无付款人/分账人列时提供「统一付款人」「均分」默认值并允许用户手动补充（即用户要求「让用户补充付款人和分账人信息」）。
3. 校验：缺标题/金额的行标红，可勾选跳过；金额按 `money.dart` 口径（分，负数=退款）。
4. 导入：新增 `ledger_repo.bulkImportExpenses(...)`（成员按姓名自动建/复用，缺失成员自动创建，账单批量落库到当前团），返回摘要。

**入口**：账本工作台工具栏「导入」按钮 + `expenses_screen` 顶部（全端）。

### C3 桌面快捷键完善

- `DesktopShell`（`CallbackShortcuts` 包内容区）：
  - `Ctrl/Cmd+N`：账本→记一笔；行程→新建行程；其它分支→命令面板。
  - `Ctrl/Cmd+F`：聚焦全局搜索/呼出命令面板。
  - `Ctrl/Cmd+K`：命令面板。
- 工作台内（`Focus` + `onKeyEvent`）：`Esc` 清空选中/退出多选；`↑/↓` 切换列表选中；`Enter` 打开选中；`Delete` 删除选中（带确认）。
- 仅 `isDesktopWeb` 生效，不侵入安卓。

### C4 CSV 导出增强（`lib/domain/csv_builder.dart` 改）

- 表头新增两列：`分账人`（分摊成员姓名，顿号分隔）、`分摊明细`（`姓名:金额` 逐条），列数 15 → 17；「分摊人数」仍保留。
- `buildExpensesCsv` 已接收 `memberNames`，补齐分账人/明细渲染。
- 同步更新 `test/domain/csv_snapshot_test.dart`（断言新列）。

### C5 账本行内快速编辑（`lib/features/ledger/desktop_ledger_workbench.dart` 改）

- 双击账单标题/金额 → 行内 `TextField` 直接改标题/金额（回车保存、Esc 取消、失焦取消），复用 `saveExpense`。
- 金额输入按分校验（负数=退款），非法输入红框提示不落库。
- 保留双击弹窗编辑；行内快改用于小改动，弹窗用于复杂编辑。

### C6 常用操作速查（效率面板）

- 命令面板内「常用命令」固定区：新建行程、记一笔、切团、打开结算/统计/预算/成员、导出备份、与手机同步、切换主题、清除缓存。
- 行程工作台行内悬浮「克隆/导出/归档」图标（现为右键菜单，桌面悬浮直达更顺手）。

---

## 依赖变更

`pubspec.yaml`（用户已确认可改）：
- `qr_flutter: ^4.x`（Web/安卓二维码渲染）
- `zxing2: ^0.2.x`（纯 Dart 二维码解码，仅安卓扫码用）
- 均无原生代码，不影响 Vercel 挂载。

---

## 文件清单总表

| 文件 | 动作 | 说明 |
|---|---|---|
| pubspec.yaml | 改 | +qr_flutter +zxing2 |
| lib/export/backup_format.dart | 改 | +TA1A 魔数 |
| lib/data/repo/ledger_repo.dart | 改 | 全量备份导出/导入、CSV 批量导入、抽取单团 merge 复用 |
| lib/data/repo/trips_repo.dart | 改 | +upsertTripSnapshot（稳定 id） |
| lib/domain/full_backup.dart | 新 | 全量备份根结构 build/parse/导入统计 |
| lib/domain/csv_parser.dart | 新 | CSV 解析器 |
| lib/domain/csv_builder.dart | 改 | +分账人/分摊明细列 |
| lib/features/ledger/ledger_providers.dart | 改 | 全量备份/同步码 provider 桥接 |
| lib/features/desktop/sync/sync_code.dart | 新 | gzip/base64 同步码 + 分块 |
| lib/features/desktop/sync/desktop_sync_center.dart | 新 | 同步中心 Dialog |
| lib/features/ledger/screens/qr_scan_screen.dart | 新 | 安卓扫码/口令导入 |
| lib/features/ledger/screens/expense_csv_import_screen.dart | 新 | CSV 导入（列映射/付款人/分账人） |
| lib/features/ledger/screens/group_list_screen.dart | 改 | 安卓入口：扫码同步、CSV 导入 |
| lib/features/trips/screens/trips_home_screen.dart | 改 | 安卓入口：扫码同步 |
| lib/features/ledger/screens/expenses_screen.dart | 改 | CSV 导出传 memberNames + 导入入口 |
| lib/features/desktop/desktop_shell.dart | 改 | 顶部工具栏 + 快捷键 + 命令面板接入 |
| lib/features/desktop/command_palette.dart | 新 | 全局搜索 + 命令面板 |
| lib/features/checklist/desktop_checklist_workbench.dart | 新 | 清单双栏 |
| lib/features/settings/screens/profile_screen.dart | 改 | 我的页桌面两列 |
| lib/features/ledger/desktop_ledger_workbench.dart | 改 | 排序列头/行悬浮/多选 |
| lib/features/trips/desktop_trips_workbench.dart | 改 | 时间轴视图 |
| lib/router.dart | 改 | /checklist 桌面分支接入 |
| test/domain/csv_snapshot_test.dart | 改 | 新列断言 |

---

## 验证步骤

1. `flutter pub get` → `flutter analyze`：0 error（桌面分支 `isDesktopWeb` 隔离，安卓/窄屏不回归）。
2. `flutter test`：现有约 130 用例全绿；新增单测：`sync_code_test`（编解码/分块）、`full_backup` build/parse、`csv_parser`、`csv_snapshot` 新列。
3. `flutter build web --release` 成功（产物含 `sqlite3.wasm`/`drift_worker.dart.js`）。
4. `node scripts/preview.mjs` → 本地预览 http://localhost:8080，浏览器手动验证：
   - **同步中心**：导出全量 `.tavA`、导入合并/覆盖、二维码（小数据）显示与翻页、口令码复制/粘贴导入；
   - **桌面 UI**：顶部工具栏（分支名/搜索/记一笔/同步/主题）、清单双栏、我的页两列、账本列头排序 + 行悬浮 + 多选删除、行程列表/时间轴切换与拖拽调时；
   - **命令面板**：Ctrl+K 全局搜索跳转、命令执行；
   - **快捷键**：Ctrl+N / Ctrl+F / Ctrl+K / Esc / ↑↓ / Delete；
   - **CSV**：导出含分账人/明细列；导入（列映射、补充付款人/分账人）到指定团；
   - 窄窗口 → 回退移动布局；控制台无 JS error。
5. 可选（不阻塞）：`flutter build apk --debug` 确认安卓可打包（含新依赖）。

## 执行顺序（建议）

A1（全量备份，含数据层+同步中心）→ A2（同步码/二维码/扫码，依赖变更）→ C4（CSV 导出）→ C2（CSV 导入）→ C1+C3（命令面板+快捷键，接入 DesktopShell）→ B1（顶部工具栏）→ B2/B3（清单/我的桌面化）→ B4/B5（账本表格/行程时间轴）→ 全量验证 + 预览。
