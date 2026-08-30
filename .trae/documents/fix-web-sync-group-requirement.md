# 修复：Web 桌面同步中心不要求先建团再同步

## 问题

Web 桌面「与手机同步」中心的**二维码生成**和**导出同步码**两个按钮要求必须先有活跃团（`activeGroupIdProvider` 非空），否则提示"请先到账本选择一个旅行团"。

用户本意是把手机端所有内容同步到 Web，Web 端却要求先建团才能操作——这与"手机→Web 同步"的方向矛盾，因为同步的目的就是让 Web 端接收手机端的数据（含团），不应要求 Web 端预先有团。

## 现状分析

* `mergeGroupSnapshotJson`（[ledger\_repo.dart](file:///d:/AI/money2.0/lib/data/repo/ledger_repo.dart#L469-L482)）已正确处理"团不存在"的场景：**团不在本地时自动创建**，无需预建。

* 口令码**粘贴导入**（`_pasteImport`）和**备份文件导入**（`_importFile`）都不要求先有团，正常工作。

* 但**二维码生成**（`_buildQr`）和**导出同步码**（`_exportCurrentCode`）两个按钮硬性要求 `activeGroupIdProvider` 非空，不符合一致性。

* 手机端已修复（见 `_resolveGroupId` 模式），Web 端也应同样处理。

## 改动方案

### 1. 修复 `_buildQr()` — 二维码生成

**文件：** [desktop\_sync\_center.dart](file:///d:/AI/money2.0/lib/features/desktop/sync/desktop_sync_center.dart)

**改动：** 将 `_buildQr()` 开头的 group 检查从只读 `activeGroupIdProvider` 改为通过 `groupsProvider` 降级：

```dart
// 改前：
final gid = ref.read(activeGroupIdProvider).value;
if (gid == null) {
  _toast('请先到「账本」选择一个旅行团');
  return;
}

// 改后：
final gid = _resolveGroupId();
if (gid == null) {
  _toast('暂无账本可导出，请先在手机端同步数据');
  return;
}
```

新增 `_resolveGroupId()` 方法（与手机端 `lan_sync_screen.dart` 相同的模式）：

```dart
String? _resolveGroupId() {
  final active = ref.read(activeGroupIdProvider).value;
  if (active != null) return active;
  final groups = ref.read(groupsProvider).valueOrNull ?? [];
  if (groups.isNotEmpty) return groups.first.id;
  return null;
}
```

### 2. 修复 `_exportCurrentCode()` — 导出同步码（口令码 Tab）

**文件：** [desktop\_sync\_center.dart](file:///d:/AI/money2.0/lib/features/desktop/sync/desktop_sync_center.dart)

**改动：** 与 `_buildQr()` 同样的逻辑替换，使用 `_resolveGroupId()` 替代 `activeGroupIdProvider`。

```dart
// 改前：
final gid = ref.read(activeGroupIdProvider).value;
if (gid == null) {
  _toast('请先到「账本」选择一个旅行团');
  return;
}

// 改后：
final gid = _resolveGroupId();
if (gid == null) {
  _toast('暂无账本可导出，请先在手机端同步数据');
  return;
}
```

### 3. 按钮文案调整（可选，为清晰）

* 二维码 Tab 按钮：`"生成二维码（当前团 + 全部行程快照）"` → `"生成二维码（全部账本 + 行程快照）"`

* 口令码 Tab 导出按钮：`"导出当前团同步码"` → `"导出同步码"`

## 一致性说明

该方案与手机端 `lan_sync_screen.dart` 的 `_resolveGroupId()` 模式完全一致：优先活跃团，没有则取第一个可用团，真无团时提示"暂无账本可导出"而非"请先到账本选择"。

## 验证步骤

1. `flutter analyze` 无报错
2. 在 Web 端无团状态下，打开同步中心 → 二维码 Tab → 点击"生成二维码"：不应要求选团，应提示"暂无账本可导出"
3. 在 Web 端存在至少一个团（但无活跃团）时，同操作：应能正常生成二维码
4. 口令码 Tab 的"导出同步码"按钮同理

<br />
