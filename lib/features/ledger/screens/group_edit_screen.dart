import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// 👥 新建 / 编辑旅行团（同屏复用，query id 区分）。
class GroupEditScreen extends ConsumerStatefulWidget {
  const GroupEditScreen({super.key});

  @override
  ConsumerState<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends ConsumerState<GroupEditScreen> {
  static const _iconChoices = ['🧭', '🏝️', '🚗', '🏔️', '🎡', '🏖️', '🎒', '🍜', '🏙️', '🚄'];

  final _nameController = TextEditingController();
  String _icon = _iconChoices.first;

  /// 账本类型（S4）：travel 旅行账本（AA）/ personal 个人账本。
  String _kind = 'travel';
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initOnce() {
    if (_initialized) return;
    _initialized = true;
    final id = GoRouterState.of(context).uri.queryParameters['id'];
    if (id == null || id.isEmpty) return;
    for (final g in ref.read(groupsProvider).value ?? const <LedgerGroupView>[]) {
      if (g.id == id) {
        setState(() {
          _nameController.text = g.name;
          _icon = g.icon;
          _kind = g.isPersonal ? 'personal' : 'travel';
        });
        break;
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    HapticFeedback.lightImpact();
    final editId = GoRouterState.of(context).uri.queryParameters['id'];
    // V2.9.0:保存链路包错误兜底 —— 此前失败直接抛未捕获异常且页面无提示。
    try {
      if (editId != null && editId.isNotEmpty) {
        await updateGroupInfo(ref, editId, name, _icon);
        if (mounted) {
          showAppSnackBar(context, '已保存修改');
          context.pop();
        }
        return;
      }
      final created = await createGroup(ref, name: name, icon: _icon, kind: _kind);
      await activateGroup(ref, created.id);
      if (mounted) {
        showAppSnackBar(context, _kind == 'personal'
                ? '「' + name + '」建好啦，记下自己的每一笔 ✍️'
                : '「' + name + '」建好啦，开始记账吧 🎉');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, '保存失败，请稍后重试',
            tone: SnackTone.destructive);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _initOnce();
    final scheme = Theme.of(context).colorScheme;
    final editing = GoRouterState.of(context).uri.queryParameters['id']?.isNotEmpty ?? false;
    final canSave = _nameController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: GlassAppBar(title: editing ? '编辑账本' : '新建账本'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, Spacing.xxxl),
        children: [
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.cardValue),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
              ),
              child: Text(_icon, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // V2.8.2 S6：团卡→团编辑名称 Hero（编辑态才与团卡同 tag 成对）
          Hero(
            tag: editing
                ? 'group-name-${GoRouterState.of(context).uri.queryParameters['id'] ?? ''}'
                : 'group-name-new',
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                controller: _nameController,
                autofocus: !editing,
                maxLength: 20,
                style: Theme.of(context).textTheme.titleMedium,
                decoration: InputDecoration(
                  hintText:
                      _kind == 'personal' ? '账本的名字，如「我的日常」' : '团的名字，如「大理四人组」',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          // S4：账本类型（仅新建时可选；已有账本改类型会改变历史语义，故只读展示）。
          Text('账本类型', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Spacing.sm),
          if (editing)
            Row(children: [
              Icon(_kind == 'personal' ? Icons.person_outline_rounded : Icons.groups_2_outlined,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: Spacing.sm),
              Text(_kind == 'personal' ? '个人账本（创建后不可更改）' : '旅行账本 · AA（创建后不可更改）',
                  style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
            ])
          else ...[
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'travel', label: Text('旅行账本')),
                ButtonSegment(value: 'personal', label: Text('个人账本')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) {
                HapticFeedback.selectionClick();
                setState(() => _kind = s.first);
              },
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              _kind == 'personal'
                  ? '只记自己的每一笔：无需选择付款人与分摊，成员固定为「我」。'
                  : '和同伴 AA：可添加成员、选择付款人与分摊方式。',
              style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: Spacing.lg),
          Text('挑个徽标', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: [
              for (final emoji in _iconChoices)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _icon = emoji);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: emoji == _icon
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.inputValue),
                      border: Border.all(
                        color: emoji == _icon ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.6),
                        width: emoji == _icon ? 1.6 : 1,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.xxxl),
          PrimaryButton(
            label: editing ? '保存修改' : '创建并开始记账',
            expanded: true,
            onPressed: canSave ? _save : null,
          ),
        ],
      ),
    );
  }
}
