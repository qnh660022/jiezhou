# 旅途助手 2.0（travel_assistant）

Flutter 安卓原生 App：**行程规划 + 出行清单 + AA 记账**三大主线，纯本地离线运行，Material3 + 苹果级质感 UI。

- 应用名：旅途助手
- 包名：com.travel.assistant.v2
- 技术栈：flutter_riverpod / go_router / drift(SQLite) / dio / flutter_map / fl_chart / pdf 等（金额一律 int 分存储，仅展示层格式化）

## 构建三步

> 前提：Windows + Git Bash / PowerShell。全部工具链落在 D:\AI\env ，不污染系统。

1. **安装工具链**（首次一次即可，全程国内镜像）
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup_env.ps1
   ```
   进度看 D:\AI\env\setup.log ，出现 DONE 工具链全部就绪 即完成。

2. **一键构建**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_apk.ps1
   ```
   脚本幂等：自动加载环境、gradle wrapper 换腾讯镜像（保持生成版本）、settings.gradle 注入阿里云镜像置顶（google()/mavenCentral() 保留回退）、pub get、build_runner、analyze(0 error)、test(全绿)、打包。

3. **取产物**
   build/app/outputs/flutter-apk/app-debug.apk

## 工具链与清理

- 位置：D:\AI\env （jdk / android-sdk / flutter / gradle-home / pub-cache）
- 环境注入：每次构建前由脚本 source scripts/env.local.ps1（JAVA_HOME / ANDROID_HOME / PUB 镜像等）
- 完全卸载：直接删除 D:\AI\env 整目录（不改系统 PATH、不写注册表）

## 目录速览

```
lib/
  main.dart app.dart router.dart      # 入口 / 根组件 / 路由+5Tab 底栏
  theme/                              # tokens.dart 设计令牌 + theme_provider.dart 主题持久化
  shared/widgets/                     # GlassAppBar/悬浮胶囊底栏/底部抽屉/金额文本/骨架屏等通用件
  features/
    trips/ checklist/ ledger/ settings/   # 各业务线屏幕
scripts/
  setup_env.ps1                       # 工具链安装（幂等）
  build_apk.ps1                       # 一键构建（幂等）
test/widget_test.dart                  # 冒烟测试
```

## 团队分工

| 成员 | 负责 |
| --- | --- |
| scaffolder | 工程骨架 / 设计系统 tokens / 路由底栏 / 通用组件 / 构建脚本 |
| data-engineer | drift 表结构 / repository / 领域模型（lib/core、lib/data、lib/domain） |
| trips-ui | 行程规划主线 UI |
| checklist-ui | 清单主线 UI |
| ledger-ui | 记账主线 UI |
| integrator | 数据接线 / 联调 / 地图导出分享集成 |
| qa-reviewer | 代码评审 / 测试把关 |

> 规范提醒：颜色一律取自 lib/theme/tokens.dart 语义角色；模态用 showDraggableSheet；空状态用 EmptyState；加载用 SkeletonBox。
