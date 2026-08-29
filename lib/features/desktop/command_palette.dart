/// 全局命令面板（Ctrl+K）：搜索行程/账单/清单/成员/团 + 常用命令。
/// 纯前端查询，跳转复用既有路由/对话框。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/date_utils.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../features/ledger/ledger_models.dart';
import '../../features/ledger/ledger_providers.dart';
import '../../features/ledger/screens/expense_edit_screen.dart';
import '../../features/ledger/screens/settle_screen.dart';
import '../../features/ledger/screens/stats_screen.dart';
import '../../features/ledger/screens/budget_screen.dart';
import '../../features/ledger/screens/members_screen.dart';
import '../../features/trips/screens/trip_edit_screen.dart';
import '../../theme/tokens.dart';
import 'desktop_utils.dart';

/// 打开命令面板（桌面态专用）。
Future<void> showCommandPalette(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _PaletteDialog(),
  );
}

class _PaletteDialog extends ConsumerStatefulWidget {
  const _PaletteDialog();

  @override
  ConsumerState<_PaletteDialog> createState() => _PaletteDialogState();
}

class _PaletteEntry {
  const _PaletteEntry(this.emoji, this.title, this.subtitle, this.onRun);
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onRun;
}

class _PaletteDialogState extends ConsumerState<_PaletteDialog> {
  final _ctl = TextEditingController();
  List<_PaletteEntry> _entries = const [];
  bool _loading = true;
  int _sel = 0;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
    _buildIndex();
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _run(_PaletteEntry e) {
    e.onRun();
    _close();
  }

  Future<void> _buildIndex() async {
    final ref = this.ref;
    final commands = <_PaletteEntry>[
      _PaletteEntry('🧳', '新建行程', '命令 · Ctrl+N', () =>
          openAsDialog(context, const TripEditScreen(initialId: null), width: 680)),
      _PaletteEntry('💰', '记一笔', '命令', () =>
          openAsDialog(context, const ExpenseEditScreen(initialId: null), width: 800)),
      _PaletteEntry('🧮', '打开结算', '命令', () =>
          openAsDialog(context, const SettleScreen(), width: 840)),
      _PaletteEntry('📊', '打开统计', '命令', () =>
          openAsDialog(context, const StatsScreen(), width: 840)),
      _PaletteEntry('🎯', '打开预算', '命令', () =>
          openAsDialog(context, const BudgetScreen(), width: 840)),
      _PaletteEntry('👥', '打开成员', '命令', () =>
          openAsDialog(context, const MembersScreen(), width: 840)),
    ];
    final entries = <_PaletteEntry>[...commands];

    try {
      final trips = await ref.read(tripsRepoProvider).watchAll().first;
      for (final t in trips) {
        if (t.archived) continue;
        entries.add(_PaletteEntry(t.emoji, t.name, '行程 · ${t.destination}', () =>
            context.push('/trips/detail', extra: t.id)));
      }
    } catch (_) {}

    try {
      final expenses = ref.read(expensesProvider).value ?? const <ExpenseRecord>[];
      for (final e in expenses.take(200)) {
        entries.add(_PaletteEntry('🧾', e.title, '账单 · ${fmtMenuDate2(e.dateEpochDay)}', () =>
            openAsDialog(context, ExpenseEditScreen(initialId: e.id), width: 800)));
      }
    } catch (_) {}

    try {
      final members = ref.read(membersProvider).value ?? const <LedgerMemberView>[];
      for (final m in members) {
        entries.add(_PaletteEntry('👤', m.name, '成员', () {}));
      }
    } catch (_) {}

    try {
      final groups = ref.read(groupsProvider).value ?? const <LedgerGroupView>[];
      for (final g in groups) {
        entries.add(_PaletteEntry(g.icon, g.name, '旅行团 · 切换', () async {
          await activateGroup(ref, g.id);
        }));
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  List<_PaletteEntry> get _filtered {
    final q = _ctl.text.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.subtitle.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;
    if (_sel >= filtered.length) _sel = filtered.isEmpty ? 0 : filtered.length - 1;
    return Dialog(
      backgroundColor: scheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                _close();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                setState(() => _sel = (_sel + 1).clamp(0, filtered.length - 1));
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                setState(() => _sel = (_sel - 1).clamp(0, filtered.length - 1));
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter && filtered.isNotEmpty) {
                _run(filtered[_sel]);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
                child: TextField(
                  controller: _ctl,
                  autofocus: true,
                  onChanged: (_) => setState(() => _sel = 0),
                  decoration: const InputDecoration(
                      hintText: '搜索行程 / 账单 / 成员 / 团，或输入命令…',
                      prefixIcon: Icon(Icons.search_rounded)),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const Center(child: Text('没有匹配项'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final e = filtered[i];
                              final sel = i == _sel;
                              return InkWell(
                                onHover: (_) {},
                                onTap: () => _run(e),
                                child: Container(
                                  color: sel ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
                                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 9),
                                  child: Row(
                                    children: [
                                      Text(e.emoji, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: Spacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                            Text(e.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String fmtMenuDate2(int day) {
  final d = epochDayToDate(day);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
