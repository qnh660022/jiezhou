/// 桌面 Web 外壳：顶部工具栏 + 左侧常驻导航栏（可拖拽调整宽度）+ 右侧内容区。
/// 仅 Web 大屏由 HomeShell 接入（见 router.dart）；安卓/窄屏沿用移动底栏。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/floating_capsule_nav_bar.dart' show CapsuleTabItem;
import '../../theme/theme_provider.dart';
import '../../theme/tokens.dart';
import '../ledger/screens/expense_edit_screen.dart';
import '../trips/screens/trip_edit_screen.dart';
import 'command_palette.dart';
import 'desktop_utils.dart';
import 'sync/desktop_sync_center.dart';

class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key, required this.shell, required this.tabs});

  final StatefulNavigationShell shell;
  final List<CapsuleTabItem> tabs;

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  double _sidebarWidth = DesktopLayout.sidebarWidth;
  bool _hoveringResize = false;
  bool _showWarn = true; // 数据安全提醒横幅（关闭后本次会话不再显示）

  int get _index => widget.shell.currentIndex;

  void _quickNew() {
    switch (_index) {
      case 1: // 行程
        openAsDialog(context, const TripEditScreen(initialId: null), width: 680);
      case 2: // 账本
        openAsDialog(context, const ExpenseEditScreen(initialId: null), width: 800);
      default:
        showCommandPalette(context);
    }
  }

  void _cycleTheme() {
    final current = ref.read(themeProvider);
    final idx = ThemeKeys.all.indexOf(current);
    final next = ThemeKeys.all[(idx + 1) % ThemeKeys.all.length];
    ref.read(themeProvider.notifier).setTheme(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopBar(
            branchEmoji: widget.tabs[_index].emoji,
            branchLabel: widget.tabs[_index].label,
            onSearch: () => showCommandPalette(context),
            onQuick: _quickNew,
            quickLabel: _index == 1 ? '新建行程' : (_index == 2 ? '记一笔' : null),
            onSync: () => showSyncCenter(context),
            onTheme: _cycleTheme,
          ),
          // 数据安全提醒：内联横幅（不使用 MaterialBanner，嵌套 Scaffold 下不渲染），
          // 关闭后本次会话隐藏；再次冷启动仍会显示。
          if (_showWarn)
            _DataWarnBar(onClose: () => setState(() => _showWarn = false)),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                SingleActivator(LogicalKeyboardKey.keyN, control: true): _quickNew,
                SingleActivator(LogicalKeyboardKey.keyK, control: true): () => showCommandPalette(context),
                SingleActivator(LogicalKeyboardKey.keyF, control: true): () => showCommandPalette(context),
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Sidebar(
                    width: _sidebarWidth,
                    shell: widget.shell,
                    tabs: widget.tabs,
                    onSync: () => showSyncCenter(context),
                  ),
                  // 拖拽调整宽度手柄
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    onEnter: (_) => setState(() => _hoveringResize = true),
                    onExit: (_) => setState(() => _hoveringResize = false),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) => setState(() {
                        _sidebarWidth =
                            (_sidebarWidth + d.delta.dx).clamp(160.0, 360.0);
                      }),
                      onHorizontalDragEnd: (_) => setState(() {}),
                      child: Container(
                        width: 6,
                        color: _hoveringResize
                            ? scheme.primary.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  Container(width: 1, color: scheme.outlineVariant),
                  // 占满剩余宽度：工作台（主从分栏）直接铺满，避免居中留隙/裁切。
                  Expanded(child: widget.shell),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部工具栏：分支名 + 全局搜索 + 快捷动作 + 同步 + 主题。
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.branchEmoji,
    required this.branchLabel,
    required this.onSearch,
    required this.onQuick,
    required this.quickLabel,
    required this.onSync,
    required this.onTheme,
  });

  final String branchEmoji;
  final String branchLabel;
  final VoidCallback onSearch;
  final VoidCallback onQuick;
  final String? quickLabel;
  final VoidCallback onSync;
  final VoidCallback onTheme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          Text('$branchEmoji  $branchLabel',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(width: Spacing.xl),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 17, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('搜索或输入命令…',
                            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                      ),
                      Text('Ctrl K',
                          style: TextStyle(fontSize: 10.5, color: scheme.outline)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (quickLabel != null) ...[
            FilledButton.icon(
              onPressed: onQuick,
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  textStyle: const TextStyle(fontSize: 12.5)),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: Text(quickLabel!),
            ),
            const SizedBox(width: Spacing.sm),
          ],
          IconButton(
            tooltip: '与手机同步',
            visualDensity: VisualDensity.compact,
            onPressed: onSync,
            icon: const Icon(Icons.sync_rounded, size: 19),
          ),
          IconButton(
            tooltip: '切换主题',
            visualDensity: VisualDensity.compact,
            onPressed: onTheme,
            icon: const Icon(Icons.palette_outlined, size: 19),
          ),
        ],
      ),
    );
  }
}

/// 数据安全提醒横幅（内联渲染在顶部工具栏正下方，任何嵌套 Scaffold 下都可见）。
class _DataWarnBar extends StatelessWidget {
  const _DataWarnBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Web 版数据仅保存在本浏览器，无后端同步，关闭页面或清除缓存可能导致数据丢失。'
              '建议定期通过顶部「同步」图标将数据备份到手机端。',
              style: TextStyle(
                  fontSize: 12.5, height: 1.35, color: scheme.onErrorContainer),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '关闭提醒（本次会话）',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, size: 18, color: scheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.width,
    required this.shell,
    required this.tabs,
    required this.onSync,
  });

  final double width;
  final StatefulNavigationShell shell;
  final List<CapsuleTabItem> tabs;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.lg, Spacing.lg, Spacing.md),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: CoverGradients.forest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('🧳', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Flexible(
                    child: Text('旅途助手',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface)),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.6)),
            const SizedBox(height: Spacing.sm),
            for (var i = 0; i < tabs.length; i++)
              _NavItem(
                emoji: tabs[i].emoji,
                label: tabs[i].label,
                selected: i == shell.currentIndex,
                onTap: () =>
                    shell.goBranch(i, initialLocation: i == shell.currentIndex),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
              child: Material(
                color: scheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onSync,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.md),
                    child: Row(
                      children: [
                        Icon(Icons.sync_rounded, size: 18, color: scheme.onPrimaryContainer),
                        const SizedBox(width: Spacing.md),
                        Flexible(
                          child: Text('与手机同步',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onPrimaryContainer)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text('桌面 Web 版 · v2.1',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 2),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.7)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onHover: (_) {},
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: Spacing.md),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
