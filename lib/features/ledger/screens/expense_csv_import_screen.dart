// 📥 CSV 批量导入账单：选文件 → 列映射（付款人/分账人可补充）→ 预览校验 → 导入当前团。
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../core/money.dart' show parseMoney;
import '../../../data/providers.dart';
import '../../../domain/csv_parser.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/tokens.dart';
import '../ledger_providers.dart';

/// CSV 列角色
const List<String> _roles = [
  '忽略', '日期', '标题', '金额（元）', '分类', '付款人', '分账人', '币种', '备注',
];

class ExpenseCsvImportScreen extends ConsumerStatefulWidget {
  const ExpenseCsvImportScreen({super.key});

  @override
  ConsumerState<ExpenseCsvImportScreen> createState() =>
      _ExpenseCsvImportScreenState();
}

class _ExpenseCsvImportScreenState extends ConsumerState<ExpenseCsvImportScreen> {
  List<List<String>> _rows = const [];
  List<String> _headers = const [];
  List<String> _rolesPerCol = const [];
  final _defaultPayer = TextEditingController();
  String _result = '';
  bool _busy = false;

  @override
  void dispose() {
    _defaultPayer.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result.isEmpty) return;
    try {
      final bytes = await result.single.readAsBytes();
      final parsed = parseCsv(String.fromCharCodes(bytes));
      if (parsed.isEmpty) throw StateError('文件为空');
      setState(() {
        _headers = parsed.first;
        _rows = parsed.sublist(1).where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
        _rolesPerCol = _guessRoles(_headers);
        _result = '';
      });
    } catch (e) {
      _toast('解析失败：${e.toString()}');
    }
  }

  List<String> _guessRoles(List<String> headers) {
    return [
      for (final h in headers)
        switch (h.trim()) {
          '日期' || 'date' || '时间' => '日期',
          '描述' || '标题' || '项目' || 'title' => '标题',
          '金额' || '金额元' || 'amount' || '价格' || '消费' => '金额（元）',
          '分类' || 'category' || '类别' => '分类',
          '付款人' || 'pay' || 'payer' => '付款人',
          '分账人' || '分摊人' || 'share' || '参与人' => '分账人',
          '币种' || 'currency' => '币种',
          '备注' || 'note' => '备注',
          _ => '忽略',
        },
    ];
  }

  int? _epochOf(String cell) {
    final s = cell.trim();
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d{4})[-\/](\d{1,2})[-\/](\d{1,2})$').firstMatch(s);
    if (m != null) {
      final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
      return dateToEpochDay(DateTime(y, mo, d));
    }
    final d = DateTime.tryParse(s);
    if (d != null) return dateToEpochDay(d);
    return null;
  }

  int? _centsOf(String cell) {
    var s = cell.trim().replaceAll(',', '');
    if (s.isEmpty) return null;
    var neg = false;
    if (s.startsWith('-')) {
      neg = true;
      s = s.substring(1).trim();
    } else if (s.startsWith('(') && s.endsWith(')')) {
      neg = true;
      s = s.substring(1, s.length - 1).trim();
    }
    final c = parseMoney(s);
    if (c == null) return null;
    return neg ? -c : c;
  }

  /// 把行映射为归一化账单（供 repo 批量导入）。
  List<Map<String, dynamic>> _buildRows() {
    final out = <Map<String, dynamic>>[];
    final payerCols = <int>[];
    final shareCols = <int>[];
    var dateCol = -1, titleCol = -1, amountCol = -1, catCol = -1,
        curCol = -1, noteCol = -1;
    for (var i = 0; i < _rolesPerCol.length; i++) {
      switch (_rolesPerCol[i]) {
        case '日期':
          dateCol = i;
        case '标题':
          titleCol = i;
        case '金额（元）':
          amountCol = i;
        case '分类':
          catCol = i;
        case '币种':
          curCol = i;
        case '备注':
          noteCol = i;
        case '付款人':
          payerCols.add(i);
        case '分账人':
          shareCols.add(i);
      }
    }
    final defPayer = _splitNames(_defaultPayer.text);
    for (final r in _rows) {
      String cell(int c) => (c >= 0 && c < r.length) ? r[c].trim() : '';
      final amount = _centsOf(cell(amountCol));
      if (amount == null) continue;
      final payer = _splitNames(
              [for (final c in payerCols) cell(c)].where((x) => x.isNotEmpty).join('、'))
          .isNotEmpty
          ? [
              for (final c in payerCols)
                ..._splitNames(cell(c)),
            ]
          : defPayer;
      final shares = [
        for (final c in shareCols) ..._splitNames(cell(c)),
      ];
      out.add({
        'title': cell(titleCol),
        'amountCents': amount,
        'dateEpochDay': _epochOf(cell(dateCol)) ?? todayEpochDay(),
        'categoryKey': cell(catCol),
        'type': amount < 0 ? 'refund' : 'normal',
        'payerNames': payer,
        'shareMode': 'equal',
        'shareNames': shares,
        'currency': cell(curCol),
        'rate': 1.0,
        'note': cell(noteCol),
      });
    }
    return out;
  }

  List<String> _splitNames(String s) =>
      s.split(RegExp(r'[、,，;；/]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _import() async {
    final gid = ref.read(activeGroupIdProvider).value;
    if (gid == null) {
      _toast('请先到「账本」选择一个旅行团');
      return;
    }
    final rows = _buildRows();
    if (rows.isEmpty) {
      _toast('没有可导入的有效行（请检查金额列映射）');
      return;
    }
    setState(() => _busy = true);
    try {
      final report = await ref
          .read(ledgerRepoProvider)
          .bulkImportExpenses(gid, rows: rows);
      final warnings = report.warnings.isEmpty ? '' : '；${report.warnings.join('；')}';
      final msg = '已导入账单 ${report.expenses} 笔、新建成员 ${report.members} 名$warnings';
      if (mounted) setState(() => _result = msg);
      _toast(msg);
    } catch (e) {
      _toast('导入失败：${e.toString()}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlassAppBar(title: 'CSV 批量导入账单'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxxl),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _rows.isEmpty
                        ? '选择 Excel 导出的 CSV 文件，映射列后一键导入当前团。'
                        : '已解析 ${_rows.length} 行，请核对列映射与预览。',
                    style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('选择 CSV'),
                ),
              ],
            ),
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              Text('列映射（付款人/分账人列缺失时，可在下方补充统一付款人）',
                  style: TextStyle(fontSize: AppFontSizes.caption, fontWeight: FontWeight.w700)),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  for (var i = 0; i < _headers.length; i++)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_headers[i],
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        DropdownButton<String>(
                          value: _rolesPerCol[i],
                          style: const TextStyle(fontSize: 12),
                          items: [
                            for (final r in _roles)
                              DropdownMenuItem(value: r, child: Text(r)),
                          ],
                          onChanged: (v) => setState(() => _rolesPerCol[i] = v ?? '忽略'),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: _defaultPayer,
                decoration: const InputDecoration(
                  labelText: '统一付款人（可空）',
                  hintText: '多个人用顿号分隔，如：小王、小李',
                  helperText: '未映射「付款人」列时使用',
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Text('预览（前 8 行）', style: TextStyle(fontSize: AppFontSizes.caption, fontWeight: FontWeight.w700)),
              const SizedBox(height: Spacing.sm),
              _PreviewTable(headers: _headers, rows: _rows, roles: _rolesPerCol),
              const SizedBox(height: Spacing.lg),
              if (_result.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: Text(_result,
                      style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.primary)),
                ),
              PrimaryButton(
                label: _busy ? '导入中…' : '导入到当前团（${_buildRows().length} 行）',
                expanded: true,
                onPressed: _busy ? null : _import,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.headers, required this.rows, required this.roles});
  final List<String> headers;
  final List<List<String>> rows;
  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final show = rows.take(8).toList();
    // 只显示被映射的列
    final cols = <int>[
      for (var i = 0; i < roles.length; i++)
        if (roles[i] != '忽略') i,
    ];
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.inputValue),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
          columnSpacing: 18,
          horizontalMargin: Spacing.md,
          columns: [
            for (final c in cols) DataColumn(label: Text('${roles[c]}(${headers[c]})', style: const TextStyle(fontSize: 11))),
          ],
          rows: [
            for (final r in show)
              DataRow(cells: [
                for (final c in cols)
                  DataCell(Text(
                    c < r.length ? r[c] : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  )),
              ]),
          ],
        ),
      ),
    );
  }
}
