import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/finance.dart';
import 'modules.dart';
import 'widgets.dart';

Future<void> openEditor(
  BuildContext context,
  WidgetRef ref,
  String section, [
  Map<String, dynamic>? record,
]) async {
  final s = ref.read(snapshotProvider).asData?.value;
  if (s == null) return;
  await showDialog<void>(
    context: context,
    builder: (context) => FinanceEditor(
      section: section,
      s: s,
      record: record,
      month: ref.read(monthProvider),
    ),
  );
}

class FinanceEditor extends ConsumerStatefulWidget {
  const FinanceEditor({
    super.key,
    required this.section,
    required this.s,
    required this.month,
    this.record,
  });
  final String section;
  final FinanceSnapshot s;
  final DateTime month;
  final Map<String, dynamic>? record;
  @override
  ConsumerState<FinanceEditor> createState() => _FinanceEditorState();
}

class _FinanceEditorState extends ConsumerState<FinanceEditor> {
  final key = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final selected = <String, String?>{};
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final r = widget.record ?? <String, dynamic>{};
    for (final f in [
      'name',
      'description',
      'amount_cents',
      'opening_cents',
      'limit_cents',
      'total_cents',
      'target_cents',
      'count',
    ]) {
      final value = r[f];
      controllers[f] = TextEditingController(
        text: value == null
            ? (f == 'count'
                  ? '12'
                  : f == 'opening_cents'
                  ? '0'
                  : '')
            : f.endsWith('_cents')
            ? (value / 100).toStringAsFixed(2).replaceAll('.', ',')
            : value.toString(),
      );
    }
    selected.addAll({
      'kind': r['kind'] ?? (widget.section == 'accounts' ? 'bank' : 'expense'),
      'account_id': r['account_id'],
      'target_account_id': r['target_account_id'],
      'category_id': r['category_id'],
      'parent_id': r['parent_id'],
      'recurring_id': r['recurring_id'],
      'frequency': r['frequency'] ?? 'monthly',
      'direction': r['direction'] ?? 'owe',
      'occurred_on': r['occurred_on'] ?? dateOnly(DateTime.now()),
      'next_due': r['next_due'] ?? dateOnly(DateTime.now()),
      'first_due': r['first_due'] ?? dateOnly(DateTime.now()),
      'due_on': r['due_on'] ?? dateOnly(DateTime.now()),
      'month': r['month'] ?? monthOnly(widget.month),
    });
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget input(
    String field,
    String label, {
    bool amount = false,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controllers[field],
      decoration: InputDecoration(
        labelText: label,
        helperText: amount ? 'Pesos argentinos · ej. 1500,50' : null,
      ),
      keyboardType: amount
          ? const TextInputType.numberWithOptions(decimal: true)
          : field == 'count'
          ? TextInputType.number
          : TextInputType.text,
      maxLength: amount
          ? null
          : field == 'count'
          ? 3
          : 120,
      validator: (v) {
        if (optional) return null;
        if (v == null || v.trim().isEmpty) return 'Completá este campo.';
        if (amount) {
          try {
            if (field == 'opening_cents' &&
                (v.trim() == '0' || v.trim() == '0,00')) {
              return null;
            }
            Finance.parseMoney(
              field == 'opening_cents' ? v.replaceFirst('-', '') : v,
            );
          } catch (e) {
            return friendlyError(e);
          }
        }
        if (field == 'count') {
          final n = int.tryParse(v);
          if (n == null || n < 1 || n > 120) {
            return 'Ingresá entre 1 y 120 cuotas.';
          }
        }
        return null;
      },
    ),
  );
  Widget select(
    String field,
    String label,
    Map<String, String> options, {
    bool optional = false,
    VoidCallback? after,
  }) {
    if (selected[field] != null && !options.containsKey(selected[field])) {
      selected[field] = null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$field-${selected[field]}-${options.keys.join()}'),
        initialValue: selected[field],
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          if (optional)
            const DropdownMenuItem(value: '', child: Text('Sin asignar')),
          for (final o in options.entries)
            DropdownMenuItem(
              value: o.key,
              child: Text(
                o.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: busy
            ? null
            : (v) => setState(() {
                selected[field] = v == '' ? null : v;
                after?.call();
              }),
        validator: (v) => !optional && (v == null || v.isEmpty)
            ? 'Seleccioná una opción.'
            : null,
      ),
    );
  }

  Widget date(String field, String label, {bool month = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: busy
          ? null
          : () async {
              final initial = DateTime.parse(
                '${selected[field]}${month ? '-01' : ''}',
              );
              final chosen = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (chosen != null && mounted) {
                setState(
                  () => selected[field] = month
                      ? monthOnly(chosen)
                      : dateOnly(chosen),
                );
              }
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        child: Text(month ? selected[field]! : dateLabel(selected[field]!)),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final section = widget.section, s = widget.s;
    final accounts = {
      for (final a in s.accounts.where(
        (a) => section == 'installments'
            ? a.kind == AccountKind.credit
            : section == 'goals'
            ? a.kind == AccountKind.savings
            : true,
      ))
        a.id: a.name,
    };
    final cats = {
      for (final c in s.categories.where(
        (c) =>
            c.kind == (section == 'movements' ? selected['kind'] : 'expense'),
      ))
        c.id: c.parentId == null
            ? c.name
            : '${categoryName(s, c.parentId)} / ${c.name}',
    };
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.record == null
                          ? 'Agregar ${formLabels[section]}'
                          : 'Editar ${formLabels[section]}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: key,
                    child: Column(
                      children: [
                        if (!['movements', 'budgets'].contains(section))
                          input('name', 'Nombre'),
                        if (section == 'accounts') ...[
                          select('kind', 'Tipo de cuenta', accountLabels),
                          input(
                            'opening_cents',
                            'Saldo inicial (puede ser negativo)',
                            amount: true,
                          ),
                        ],
                        if (section == 'categories') ...[
                          select('kind', 'Tipo', const {
                            'income': 'Ingreso',
                            'expense': 'Gasto',
                          }, after: () => selected['parent_id'] = null),
                          select('parent_id', 'Categoría principal', {
                            for (final c in s.categories.where(
                              (c) =>
                                  c.id != widget.record?['id'] &&
                                  c.kind == selected['kind'],
                            ))
                              c.id: c.name,
                          }, optional: true),
                        ],
                        if (section == 'movements') ...[
                          select(
                            'kind',
                            'Tipo de movimiento',
                            const {
                              'income': 'Ingreso',
                              'expense': 'Gasto',
                              'transfer': 'Transferencia',
                            },
                            after: () {
                              selected['category_id'] = null;
                              selected['target_account_id'] = null;
                              selected['recurring_id'] = null;
                            },
                          ),
                          input('amount_cents', 'Importe', amount: true),
                          date('occurred_on', 'Fecha'),
                          select(
                            'account_id',
                            selected['kind'] == 'transfer'
                                ? 'Cuenta de origen'
                                : 'Cuenta',
                            accounts,
                          ),
                          if (selected['kind'] == 'transfer')
                            select('target_account_id', 'Cuenta de destino', {
                              for (final a in s.accounts.where(
                                (a) => a.id != selected['account_id'],
                              ))
                                a.id: a.name,
                            })
                          else
                            select('category_id', 'Categoría', cats),
                          input(
                            'description',
                            'Descripción / notas',
                            optional: true,
                          ),
                          if (selected['kind'] == 'expense')
                            select(
                              'recurring_id',
                              'Vincular a gasto recurrente',
                              {for (final r in s.recurring) r['id']: r['name']},
                              optional: true,
                            ),
                        ],
                        if (section == 'budgets') ...[
                          select('category_id', 'Categoría', cats),
                          date('month', 'Mes del presupuesto', month: true),
                          input('limit_cents', 'Límite mensual', amount: true),
                        ],
                        if (section == 'recurring') ...[
                          input('amount_cents', 'Importe', amount: true),
                          select('account_id', 'Cuenta', accounts),
                          select('category_id', 'Categoría', cats),
                          select('frequency', 'Frecuencia', frequencyLabels),
                          date('next_due', 'Próximo vencimiento'),
                          const Text(
                            'Los pagos se registran manualmente. Cada pago crea un gasto y avanza el próximo vencimiento.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                        if (section == 'installments') ...[
                          select('account_id', 'Tarjeta de crédito', accounts),
                          select('category_id', 'Categoría', cats),
                          input(
                            'total_cents',
                            'Importe total de la compra',
                            amount: true,
                          ),
                          input('count', 'Cantidad de cuotas'),
                          date('first_due', 'Vencimiento de la primera cuota'),
                          const Text(
                            'La compra genera una planificación. Usá «Registrar cuota» para registrar cada gasto, sin duplicar el total.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                        if (section == 'debts') ...[
                          select('direction', 'Tipo de deuda', const {
                            'owe': 'Dinero que debo',
                            'owed': 'Dinero que me deben',
                          }),
                          input(
                            'amount_cents',
                            'Importe total de la deuda',
                            amount: true,
                          ),
                          date('due_on', 'Vencimiento'),
                        ],
                        if (section == 'goals') ...[
                          input(
                            'target_cents',
                            'Objetivo de ahorro',
                            amount: true,
                          ),
                          select('account_id', 'Cuenta de ahorros', accounts),
                          date('due_on', 'Fecha objetivo'),
                          const Text(
                            'Los aportes se registran como transferencias desde otra cuenta hacia tu cuenta de ahorros.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                        if (accounts.isEmpty &&
                            [
                              'movements',
                              'recurring',
                              'installments',
                              'goals',
                            ].contains(section))
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              section == 'installments'
                                  ? 'Primero creá una cuenta de tipo tarjeta de crédito.'
                                  : section == 'goals'
                                  ? 'Primero creá una cuenta de tipo ahorros.'
                                  : 'Primero creá una cuenta.',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(busy ? 'Guardando…' : 'Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final c = widget.section, v = <String, dynamic>{};
      for (final f in LocalFinanceRepository.columns[c]!) {
        if (controllers.containsKey(f)) {
          final raw = controllers[f]!.text.trim();
          if (f.endsWith('_cents')) {
            v[f] = f == 'opening_cents' && (raw == '0' || raw == '0,00')
                ? 0
                : Finance.parseMoney(raw.replaceFirst('-', '')) *
                      (f == 'opening_cents' && raw.startsWith('-') ? -1 : 1);
          } else if (f == 'count') {
            v[f] = int.parse(raw);
          } else {
            v[f] = raw;
          }
        } else if (selected.containsKey(f)) {
          v[f] = selected[f];
        }
      }
      if (c == 'accounts') v['currency'] = 'ARS';
      if (c == 'movements') {
        if (v['kind'] == 'transfer') {
          v['category_id'] = null;
          v['recurring_id'] = null;
        } else {
          v['target_account_id'] = null;
        }
      }
      await ref.read(repositoryProvider).save(c, v, id: widget.record?['id']);
      ref.invalidate(snapshotProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

const formLabels = {
  'accounts': 'cuenta',
  'categories': 'categoría',
  'movements': 'movimiento',
  'budgets': 'presupuesto',
  'recurring': 'gasto recurrente',
  'installments': 'compra en cuotas',
  'debts': 'deuda',
  'goals': 'meta de ahorro',
};

class AmountDialog extends StatefulWidget {
  const AmountDialog({
    super.key,
    required this.accounts,
    required this.title,
    this.initial,
  });
  final List<Account> accounts;
  final String title;
  final int? initial;
  @override
  State<AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<AmountDialog> {
  late final controller = TextEditingController(
    text: widget.initial == null
        ? ''
        : (widget.initial! / 100).toStringAsFixed(2).replaceAll('.', ','),
  );
  late String accountId = widget.accounts.first.id;
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: accountId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Cuenta'),
          items: [
            for (final a in widget.accounts)
              DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: (v) {
            if (v != null) accountId = v;
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Importe en ARS',
            errorText: error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          try {
            final amount = Finance.parseMoney(controller.text);
            if (widget.initial != null && amount > widget.initial!) {
              throw ArgumentError('El importe supera el saldo pendiente.');
            }
            Navigator.pop(context, (accountId: accountId, amount: amount));
          } catch (e) {
            setState(() => error = friendlyError(e));
          }
        },
        child: const Text('Registrar'),
      ),
    ],
  );
}
