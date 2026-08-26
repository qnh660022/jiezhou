import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers.dart';
import '../../../data/seed/checklist_templates.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../theme/tokens.dart';
import '../../../theme/theme_provider.dart';

class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, this.itemId, this.tripId, this.scope = 'trip'});
  final String? itemId;
  final String? tripId;
  final String scope;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  final _textCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = 'other';

  @override
  void initState() {
    super.initState();
    if (widget.itemId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final db = ref.read(dbProvider);
        final items = await (db.select(db.checklistItems)..where((c) => c.id.equals(widget.itemId!))).get();
        if (items.isNotEmpty && mounted) {
          _textCtrl.text = items.first.label;
          setState(() => _selectedCategory = items.first.category);
        }
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final isEdit = widget.itemId != null;
    return Scaffold(
      appBar: GlassAppBar(title: isEdit ? '编辑条目' : '新增条目'),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _textCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '物品名称',
                  border: OutlineInputBorder(borderRadius: AppRadius.input),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '不能为空' : null,
              ),
              const SizedBox(height: Spacing.lg),
              Text('所属分类', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: kChecklistCategories.map((cat) {
                  final isSel = cat.key == _selectedCategory;
                  return GestureDetector(
                    onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedCategory = cat.key); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                      decoration: BoxDecoration(
                        color: isSel ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: AppRadius.capsule,
                        border: Border.all(color: isSel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Text(cat.icon + ' ' + cat.name, style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: Spacing.xxl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    HapticFeedback.lightImpact();
                    final router = GoRouter.of(context);
                    final repo = ref.read(checklistRepoProvider);
                    final text = _textCtrl.text.trim();
                    if (isEdit) {
                      await repo.updateItem(widget.itemId!, label: text, category: _selectedCategory);
                    } else {
                      final scope = widget.scope;
                      final existing = await repo.getAllByScope(scope, tripId: widget.tripId);
                      await repo.addItem(widget.tripId, scope, _selectedCategory, text, existing.length);
                    }
                    if (mounted) router.pop();
                  },
                  style: FilledButton.styleFrom(shape: const RoundedRectangleBorder(borderRadius: AppRadius.button)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                    child: Text(isEdit ? '保存' : '添加'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
