import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';

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
    if (editId != null && editId.isNotEmpty) {
      await updateGroupInfo(ref, editId, name, _icon);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存修改 ✅')));
        context.pop();
      }
      return;
    }
    final created = await createGroup(ref, name: name, icon: _icon);
    await activateGroup(ref, created.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「' + name + '」建好啦，开始记账吧 🎉')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    _initOnce();
    final scheme = Theme.of(context).colorScheme;
    final editing = GoRouterState.of(context).uri.queryParameters['id']?.isNotEmpty ?? false;
    final canSave = _nameController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: GlassAppBar(title: editing ? '编辑旅行团' : '新建旅行团'),
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
          TextField(
            controller: _nameController,
            autofocus: !editing,
            maxLength: 20,
            style: Theme.of(context).textTheme.titleMedium,
            decoration: InputDecoration(hintText: '团的名字，如「大理四人组」'),
            onChanged: (_) => setState(() {}),
          ),
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
