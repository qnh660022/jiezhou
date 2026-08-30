# Web 桌面版改造方案：左侧导航栏 + 主从式分栏工作台

## 摘要

当前 Web 版只是把安卓的手机界面按原样渲染到浏览器大屏：底部胶囊导航、单列卡片、底部抽屉、左右滑手势，完全没有利用电脑的宽屏、鼠标悬浮与键盘效率，也缺乏"快速改行程/记账"的工作台体验。

本次改造为 **Web 端（大屏）新增一套桌面布局**：左侧常驻导航栏 + 右侧主工作区；「行程」与「账本」两个分支采用 **主从式分栏**（左列表 → 右详情/快速编辑，免整页跳转）。**安卓端保持现有移动布局完全不变**，不引入回归风险。

## 现状分析（已核对代码）

* 外壳导航：[router.dart](file:///d:/AI/money2.0/lib/router.dart) 的 `HomeShell` 用 `FloatingCapsuleNavBar` 底部胶囊栏 + `StatefulNavigationShell`；Web 端 AI 分支已移除，分支顺序为 **清单(0)/行程(1)/账本(2)/我的(3)**，`_tabs` 也是这一顺序。

* 行程页：[trips\_home\_screen.dart](file:///d:/AI/money2.0/lib/features/trips/screens/trips_home_screen.dart) 单列渐变封面大卡按"进行中/即将/规划/已结束/归档"分组；长按走 `showDraggableSheet` 底部抽屉；「新建」跳 `/trips/edit`；详情跳 `/trips/detail`（经 `state.extra` 传 tripId）。

* 账本页：[ledger\_home\_screen.dart](file:///d:/AI/money2.0/lib/features/ledger/screens/ledger_home_screen.dart) 单列卡片流（当前团卡/预算/快捷入口/余额榜/最近账单）；`_BillTile` 用 `Dismissible` 左右滑编辑/删除、点开 `BillDetailSheet` 底部抽屉；有 `_openGroupSwitcher` 团切换抽屉。

* 账单流：[expenses\_screen.dart](file:///d:/AI/money2.0/lib/features/ledger/screens/expenses_screen.dart) 有分类/成员/搜索筛选 + 粘性日期分组 + 合计栏 + CSV 导出（可直接复用其排序/筛选逻辑）。

* 数据层：所有流/操作都在 repo/provider（`watchTrips` / `expensesProvider` / `membersProvider` / `groupsProvider` / `activateGroup` 等），**桌面化只改 UI，不改数据层**。

* 设计令牌：[tokens.dart](file:///d:/AI/money2.0/lib/theme/tokens.dart) 为移动 4px 网格 + 固定字号；桌面需要追加少量布局令牌。

## 变更方案（文件级）

### 1) 平台判定与布局令牌

* `lib/features/desktop/desktop_utils.dart`（新）

  * `bool isDesktopWeb(BuildContext) => kIsWeb && MediaQuery.sizeOf(context).width >= 1024;`

  * `void openAsDialog(BuildContext, Widget child, {double width = 900})`：把现有全屏页面/编辑屏以居中全尺寸 Dialog 打开（`showDialog`，近似尺寸宽度、高度 max(80vh,600)），供工作台复用。

  * 说明：桌面眼于 Web 大屏；窄浏览器窗口仍走原移动布局。

* `lib/theme/tokens.dart`（改）：新增 `abstract final class DesktopLayout { static const double sidebarWidth = 232; static const double contentMaxWidth = 1080; static const double masterPanelWidth = 340; }`

### 2) 桌面外壳（左侧导航栏）

* `lib/features/desktop/desktop_shell.dart`（新）：`DesktopShell({shell, tabs})`

  * 布局：`Row [ 左侧边栏 DesktopSidebar , Expanded(内容区) ]`；内容区居中约束 `contentMaxWidth`。

  * `DesktopSidebar`：顶部品牌（🧳 旅途助手）+ 纵向导航项（由 `tabs` 的 emoji+label 生成，含悬浮高亮、选中态 `primaryContainer`）；激活项 `onTap → shell.goBranch(index)`；底部放「设置/主题」等常驻入口。

  * 内容区顶部一条细操作栏（显示当前分支名 + 右上常驻「快速记一笔 ＋」与「搜索」按钮位）。

  * 全局键盘快捷键（`CallbackShortcuts` 包住内容区，`Esc` 置首响应）：`Esc` 关闭弹层/取消选中；`Ctrl/Cmd+N` 按当前分支新建行程或记一笔；`Ctrl/Cmd+F` 聚焦搜索框；`↑/↓` 切换列表选中；`Enter` 打开选中；`Delete` 删除选中（带确认）。

* `lib/router.dart`（改）：`HomeShell.build` 内判断

  * `isDesktopWeb` → `DesktopShell(shell, tabs: _tabs)`；

  * 否则 → 现有 `Scaffold(extendBody) + FloatingCapsuleNavBar`（安卓/窄屏不变）。

  * 分支与 tab 顺序不变，`_tabs`（清单/行程/账本/我的）直接复用。

### 3) 行程工作台（主从式）

* `lib/features/trips/desktop_trips_workbench.dart`（新）：行程分支在桌面态渲染本组件。

  * 左 Master 面板（宽 `masterPanelWidth`）：顶部搜索 + 状态筛选 Chip + 「新建行程」按钮；下方密集列表（复用 `watchTrips`、`classifyTrip`）：每行 = emoji + 名称 + 目的地·日期 + 状态小标 + 右侧操作（归档/删除）；点击行 → 选中（`StateProvider<String?>` 存 selectedTripId）。归档默认折叠。

  * 右 Detail 面板（`Expanded`）：未选中 → 空态引导"选择左侧行程"；选中 → `DesktopTripDetailPane`。

* `lib/features/trips/desktop_trip_detail_pane.dart`（新）：

  * 顶部行程摘要卡（名称/emoji/日期/目的地）+ 行内快捷编辑按钮（改名/改日期 → Dialog 复用 `TripEditScreen`）。

  * 按天时间轴（复用 `watchTripItems`）：每条 = 时间 + 名称 + 类型图标 + 悬浮/解锁操作（编辑/删除，编辑小屏 → Dialog 复用 `ItemEditScreen`）；「添加安排」→ Dialog。

  * 快捷入口：打开完整「行程时间轴 / 地图 / 相册 / 导出」→ `openAsDialog` 复用 `TripDetailScreen`/`TripMapScreen`/`TripAlbumScreen`/`TripExportScreen`。

* 新建/编辑统一走 `openAsDialog(TripEditScreen / ItemEditScreen)`，替代移动端整页跳转。

### 4) 账本工作台（主从式）

* `lib/features/ledger/desktop_ledger_workbench.dart`（新）：账本分支在桌面态渲染。

  * 左 Master 面板：顶部**团切换下拉**（复用 `groupsProvider` + `activateGroup`，当前团 Name 置顶）+ 搜索/分类/成员筛选（复用 `expenses_screen` 的 `_applyFilters` 思路）+ 顶部 Tab 快捷入口（账单 / 结算 / 成员 / 预算 / 统计，`.pushImportant` 由 `openAsDialog` 打开对应页面）；下方密集账单表（每行 = 分类图标 + 标题 + 记账人 + 日期 + 金额 + 类型徽标），点击选中（`StateProvider<String?>` 存 selectedExpenseId）。

  * 右 Detail 面板：未选中 → 空态；选中 → `DesktopExpenseDetailPane` + 顶部右侧「记一笔」按钮（→ Dialog 复用 `ExpenseEditScreen`）。

* `lib/features/ledger/desktop_expense_detail_pane.dart`（新）：复用 `BillDetailSheet` 的展示内容做右侧详情面板；提供「编辑 / 删除」（编辑 → Dialog 复用 `ExpenseEditScreen`，删除 → `deleteExpense` 二次确认）。

* 全部账单 / 结算 / 成员 / 预算 / 统计等整页，桌面态经 `openAsDialog` 打开，复用现有页面，仅做宽度适配。

### 5) 其余分支（清单/我的）

* 桌面态下置于内容区并居中约束 `contentMaxWidth`；小块适配（悬浮按钮上移成顶栏按钮、`showDraggableSheet` 关键弹层在桌面可退化为中心 Dialog）。范围控制：首期只保证其可用与不拉伸，不重做交互。

### 6) 桌面效率化功能

* **右键上下文菜单**：`lib/features/desktop/desktop_context_menu.dart`（新）`showDesktopContextMenu`（`showMenu` 定位于鼠标）。行程行 & 账单行 `onSecondaryTapDown` → 菜单：打开 / 编辑 / 复制 / 导出备份 / 归档 / 删除（复用现有 repo 操作），替代移动端长按抽屉。

* **行内快改**：行程列表与详情中双击名称 → 行内 `TextField` 直接改名（回车保存、Esc 取消）；日期以桌面日期选择控件（`showDatePicker`）行内快速改，不再整页/抽屉。

* **批量操作**：行程与账单列表支持多选（左上角"多选"开关 + 行首 Checkbox）→ 底部操作条批量「归档 / 删除」（带汇总确认）。

* **密集表格化列表**：左 Master 面板默认每行高度紧凑，行内信息一屏可见；桌面宽屏下账单表启用可点击排序（日期/金额），减少滚动查找。

* **双击打开 + 悬浮操作**：行双击打开详情/编辑；行悬浮显示操作图标（编辑/删除），鼠标效率优先。

* 效率能力均只在 `isDesktopWeb` 分支启用，不侵入安卓路径。

### 7) 屏蔽浏览器受限项（电脑浏览器无法/不宜进行的操作一律隐藏或降级）

* **拍照**：相册添加与头像等不再暴露"相机拍照"入口（桌面浏览器多无摄像头或体验不一致），仅保留"选择图片/上传文件"（`image_picker` 的 `ImageSource.gallery`）。

* **局域网同步**：桌面 Web 隐藏「局域网同步」入口；空位改为「与手机同步」→ 提示使用备份文件（.tav/.tat）导入导出互传（该能力已跨端可用）。

* **系统通知**：Web 已是空实现；桌面不显示任何"通知权限"类按钮/提示。

* **触觉/长按手势**：`HapticFeedback` 在桌面无效果，不改不再依赖；`Dismissible` 左右滑编辑/删除等手势在桌面由按钮/右键菜单替代（工作台内不复用手势删除）。

* **分享**：沿用浏览器下载/系统分享（已完成）；不出现"保存到相册"类无法完成的能力（海报保存改为浏览器下载）。

### 决策与假设

* **仅 Web 大屏启用桌面布局**（`kIsWeb && width>=1024`）；安卓及窄屏 Web 沿用移动外壳 → 不回归已测安卓。

* **只改 UI 层**：复用全部 repo/provider/模型/`trip_utils`/`ledger_providers`，不改数据库与业务逻辑。

* 复用现有编辑/详情页，通过 `openAsDialog` 嵌入 Dialog 工作区，避免大段重写。

* 主从选中用 `StateProvider<String?>`（纯前端状态）；顶层分支仍走 go\_router URL。

* 风格延续 emoji + 现有令牌与配色，不引入新视觉体系。

### 验证步骤

1. `flutter analyze` 0 错误（桌面态为 `kIsWeb` 分支，原生/安卓路径不受影响）。
2. `flutter test`：现有约 130 用例全绿；并新增 1 个 widget 测试：`DesktopShell` 渲染侧边栏四项、点击切换分支；`isDesktopWeb` 在窄/宽尺寸下返回正确。
3. `flutter build web --release` 构建成功，产物含 `sqlite3.wasm`/`drift_worker.dart.js`。
4. `node scripts/preview.mjs` 起本地预览（<http://localhost:8080），浏览器手动验证：>

   * 左侧导航四项切换正常；

   * 行程：列表选中 → 右侧详情；改行程名/日期、增删安排（Dialog）即时生效；双击名称行内改名；右键菜单与多选批量归档/删除可用；

   * 账本：切团 → 账单列表刷新；选中账单 → 右侧详情；记一笔/编辑/删除（Dialog）生效；结算/统计/预算/成员可打开；账单表排序可用；

   * 快捷键：Ctrl/Cmd+N 新建、Ctrl/Cmd+F 聚焦搜索、↑/↓ + Enter 选行、Delete 删除、Esc 关弹层；

   * 浏览器受限项：相册/头像无"拍照"入口、账本/行程无"局域网同步"入口（出现"与手机同步"提示）；

   * 收窄窗口 → 回退为移动底部导航布局；控制台无 JS error。
5. 可选（不阻塞）：`flutter build apk --debug` 确认安卓仍可打包。

