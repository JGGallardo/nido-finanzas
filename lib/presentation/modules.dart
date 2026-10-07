import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';
import '../data/repository.dart';
import '../domain/finance.dart';
import '../domain/models.dart';
import 'forms.dart';
import 'theme.dart';
import 'widgets.dart';

const accountLabels = {
  'cash': 'Efectivo',
  'bank': 'Cuenta bancaria',
  'wallet': 'Billetera virtual',
  'credit': 'Tarjeta de crédito',
  'savings': 'Ahorros',
  'other': 'Otra',
};
const frequencyLabels = {
  'daily': 'Diaria',
  'weekly': 'Semanal',
  'monthly': 'Mensual',
  'yearly': 'Anual',
};
IconData accountIcon(AccountKind kind) => switch (kind) {
  AccountKind.cash => Icons.payments_outlined,
  AccountKind.bank => Icons.account_balance_outlined,
  AccountKind.wallet => Icons.wallet_outlined,
  AccountKind.credit => Icons.credit_card_outlined,
  AccountKind.savings => Icons.savings_outlined,
  AccountKind.other => Icons.account_balance_wallet_outlined,
};
String categoryName(FinanceSnapshot s, String? id) =>
    s.categories.where((c) => c.id == id).firstOrNull?.name ?? 'Transferencia';
String accountName(FinanceSnapshot s, String? id) =>
    s.accounts.where((a) => a.id == id).firstOrNull?.name ?? 'Cuenta';

class ModulePage extends ConsumerStatefulWidget {
  const ModulePage({super.key, required this.section, required this.s});
  final String section;
  final FinanceSnapshot s;
  @override
  ConsumerState<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends ConsumerState<ModulePage> {
  String query = '', kind = 'all';
  final Set<String> busy = {};
  Future<void> action(String id, Future<void> Function() run) async {
    if (busy.contains(id)) return;
    setState(() => busy.add(id));
    await runAction(context, ref, run);
    if (mounted) setState(() => busy.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s,
        section = widget.section,
        month = ref.watch(monthProvider);
    final repo = ref.read(repositoryProvider);
    if (section == 'movements') {
      final movements =
          s.movements
              .where(
                (m) =>
                    Finance.inMonth(m.date, month) &&
                    (kind == 'all' || m.kind.name == kind) &&
                    (m.description.toLowerCase().contains(
                          query.toLowerCase(),
                        ) ||
                        categoryName(
                          s,
                          m.categoryId,
                        ).toLowerCase().contains(query.toLowerCase()) ||
                        accountName(
                          s,
                          m.accountId,
                        ).toLowerCase().contains(query.toLowerCase())),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      return Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar descripción, cuenta o categoría',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                for (final k in {
                  'all': 'Todos',
                  'income': 'Ingresos',
                  'expense': 'Gastos',
                  'transfer': 'Transferencias',
                }.entries)
                  ChoiceChip(
                    label: Text(k.value),
                    selected: kind == k.key,
                    onSelected: (_) => setState(() => kind = k.key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (movements.isEmpty)
            const EmptyState('No hay movimientos para esta búsqueda.')
          else
            Panel(
              padding: 16,
              child: Column(
                children: [
                  for (final m in movements)
                    Row(
                      children: [
                        Expanded(
                          child: MovementTile(m: m, s: s),
                        ),
                        RecordMenu(
                          collection: section,
                          id: m.id,
                          onEdit: () =>
                              openEditor(context, ref, section, movementMap(m)),
                          onDelete: () async {
                            if (await confirmDelete(context)) {
                              if (!context.mounted) return;
                              await runAction(
                                context,
                                ref,
                                () => repo.remove(section, m.id),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      );
    }
    if (section == 'accounts') {
      final balances = Finance.balances(s, through: DateTime.now());
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Panel(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Saldo consolidado',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Money(
                  balances.values.fold(0, (a, b) => a + b),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          responsiveCards([
            for (final a in s.accounts)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SoftIcon(
                          accountIcon(a.kind),
                          color: a.kind == AccountKind.credit ? blue : green,
                        ),
                        const Spacer(),
                        menu('accounts', {
                          'id': a.id,
                          'name': a.name,
                          'kind': a.kind.name,
                          'opening_cents': a.openingCents,
                          'currency': a.currency,
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(a.name, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      accountLabels[a.kind.name]!,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Money(
                      balances[a.id] ?? 0,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: (balances[a.id] ?? 0) < 0
                            ? coral
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saldo inicial: ${money(a.openingCents, ref.watch(moneyStyleProvider))}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
          ]),
        ],
      );
    }
    if (section == 'categories') {
      return responsiveCards([
        for (final cat in s.categories)
          Panel(
            padding: 18,
            child: Row(
              children: [
                SoftIcon(
                  cat.kind == 'income'
                      ? Icons.south_west
                      : Icons.category_outlined,
                  color: cat.kind == 'income' ? green : coral,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        cat.parentId != null
                            ? 'Subcategoría de ${categoryName(s, cat.parentId)}'
                            : cat.kind == 'income'
                            ? 'Ingreso'
                            : 'Gasto',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                menu('categories', {
                  'id': cat.id,
                  'name': cat.name,
                  'kind': cat.kind,
                  'parent_id': cat.parentId,
                }),
              ],
            ),
          ),
      ]);
    }
    final records = switch (section) {
      'budgets' =>
        s.budgets.where((b) => b['month'] == monthOnly(month)).toList(),
      'recurring' => s.recurring,
      'installments' => s.installments,
      'debts' => s.debts,
      'goals' => s.goals,
      _ => <Map<String, dynamic>>[],
    };
    if (records.isEmpty) {
      return const EmptyState(
        'Tu hogar todavía no tiene registros en esta sección. Agregá el primero desde el botón de arriba.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section == 'installments') ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  'Pagos de los próximos meses',
                  subtitle: 'Cuotas pendientes según sus vencimientos',
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    for (var i = 0; i < 6; i++)
                      SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM yyyy', 'es_AR').format(
                                DateTime(month.year, month.month + i, 1),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                            Money(
                              records.fold<int>(
                                0,
                                (sum, p) =>
                                    sum +
                                    Finance.installmentDue(
                                      p,
                                      DateTime(month.year, month.month + i, 1),
                                    ),
                              ),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (section == 'debts') ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final d in {'owe': 'Debo', 'owed': 'Me deben'}.entries)
                Chip(
                  label: Text(
                    '${d.value}: ${money(records.where((r) => r['direction'] == d.key).fold<int>(0, (v, r) => v + (r['amount_cents'] as int) - (r['settled_cents'] as int)), ref.watch(moneyStyleProvider))}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        responsiveCards([
          for (final r in records)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SoftIcon(
                        switch (section) {
                          'budgets' => Icons.donut_small_outlined,
                          'recurring' => Icons.event_repeat_outlined,
                          'installments' => Icons.credit_card_outlined,
                          'debts' => Icons.handshake_outlined,
                          _ => Icons.savings_outlined,
                        },
                        color: section == 'debts' && r['direction'] == 'owe'
                            ? coral
                            : green,
                      ),
                      const Spacer(),
                      menu(section, r),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (section == 'budgets')
                    BudgetContent(b: r, s: s, month: month)
                  else if (section == 'goals') ...[
                    GoalContent(g: r),
                    const SizedBox(height: 16),
                    Text(
                      'Objetivo: ${dateLabel(r['due_on'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: busy.contains(r['id'])
                          ? null
                          : () => amountAction(r, goal: true),
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('Aportar a mi meta'),
                    ),
                  ] else ...[
                    Text(
                      r['name'],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (section == 'recurring') ...[
                      Money(
                        r['amount_cents'],
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${frequencyLabels[r['frequency']]} · ${accountName(s, r['account_id'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Próximo: ${dateLabel(r['next_due'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy.contains(r['id'])
                            ? null
                            : () => action(
                                r['id'],
                                () => repo.payRecurring(r['id']),
                              ),
                        icon: const Icon(Icons.check_circle_outline, size: 17),
                        label: const Text('Registrar pago'),
                      ),
                    ],
                    if (section == 'installments') ...[
                      Money(
                        r['paid_count'] < r['count']
                            ? Finance.installmentAmount(r)
                            : 0,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${r['paid_count']} de ${r['count']} cuotas registradas · total ${money(r['total_cents'], ref.watch(moneyStyleProvider))}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      Progress(r['paid_count'] / r['count'], color: blue),
                      const SizedBox(height: 10),
                      if (r['paid_count'] < r['count'])
                        Text(
                          'Vence: ${dateLabel(dateOnly(Finance.shiftMonth(DateTime.parse(r['first_due']), r['paid_count'])))}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed:
                            r['paid_count'] >= r['count'] ||
                                busy.contains(r['id'])
                            ? null
                            : () => action(
                                r['id'],
                                () => repo.payInstallment(r['id']),
                              ),
                        icon: const Icon(Icons.check_circle_outline, size: 17),
                        label: Text(
                          r['paid_count'] >= r['count']
                              ? 'Completado'
                              : 'Registrar cuota',
                        ),
                      ),
                    ],
                    if (section == 'debts') ...[
                      Text(
                        r['direction'] == 'owe'
                            ? 'Dinero que debo'
                            : 'Dinero que me deben',
                        style: TextStyle(
                          color: r['direction'] == 'owe' ? coral : green,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Money(
                        r['amount_cents'] - r['settled_cents'],
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Pendiente · vence ${dateLabel(r['due_on'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      Progress(r['settled_cents'] / r['amount_cents']),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed:
                            r['settled_cents'] >= r['amount_cents'] ||
                                busy.contains(r['id'])
                            ? null
                            : () => amountAction(r, goal: false),
                        icon: const Icon(Icons.check_circle_outline, size: 17),
                        label: Text(
                          r['direction'] == 'owe'
                              ? 'Registrar pago'
                              : 'Registrar cobro',
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
        ]),
      ],
    );
  }

  Widget responsiveCards(List<Widget> children) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= 950
          ? 3
          : c.maxWidth >= 620
          ? 2
          : 1;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final child in children)
            SizedBox(
              width: (c.maxWidth - (columns - 1) * 18) / columns,
              child: child,
            ),
        ],
      );
    },
  );
  Widget menu(String collection, Map<String, dynamic> row) => RecordMenu(
    collection: collection,
    id: row['id'],
    onEdit: () => openEditor(context, ref, collection, row),
    onDelete: () async {
      if (await confirmDelete(context)) {
        if (!mounted) return;
        await action(
          row['id'],
          () => ref.read(repositoryProvider).remove(collection, row['id']),
        );
      }
    },
  );
  Future<void> amountAction(
    Map<String, dynamic> row, {
    required bool goal,
  }) async {
    final accounts = widget.s.accounts
        .where((a) => !goal || a.id != row['account_id'])
        .toList();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Creá una cuenta de origen para registrar este aporte.',
          ),
        ),
      );
      return;
    }
    final result = await showDialog<({String accountId, int amount})>(
      context: context,
      builder: (context) => AmountDialog(
        accounts: accounts,
        title: goal
            ? 'Aportar a ${row['name']}'
            : row['direction'] == 'owe'
            ? 'Registrar pago'
            : 'Registrar cobro',
        initial: goal ? null : row['amount_cents'] - row['settled_cents'],
      ),
    );
    if (result == null || !mounted) return;
    await action(
      row['id'],
      () => goal
          ? ref
                .read(repositoryProvider)
                .contribute(row['id'], result.accountId, result.amount)
          : ref
                .read(repositoryProvider)
                .settleDebt(row['id'], result.accountId, result.amount),
    );
  }
}

class RecordMenu extends StatelessWidget {
  const RecordMenu({
    super.key,
    required this.collection,
    required this.id,
    required this.onEdit,
    required this.onDelete,
  });
  final String collection, id;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Opciones del registro',
    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: Text('Editar')),
      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
    ],
  );
}

Map<String, dynamic> movementMap(Movement m) => {
  'id': m.id,
  'kind': m.kind.name,
  'amount_cents': m.amountCents,
  'occurred_on': dateOnly(m.date),
  'account_id': m.accountId,
  'target_account_id': m.targetAccountId,
  'category_id': m.categoryId,
  'recurring_id': m.recurringId,
  'description': m.description,
};

class MovementTile extends StatelessWidget {
  const MovementTile({super.key, required this.m, required this.s});
  final Movement m;
  final FinanceSnapshot s;
  @override
  Widget build(BuildContext context) {
    final color = m.kind == MovementKind.income
        ? green
        : m.kind == MovementKind.expense
        ? coral
        : blue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          SoftIcon(
            m.kind == MovementKind.income
                ? Icons.south_west_rounded
                : m.kind == MovementKind.expense
                ? Icons.north_east_rounded
                : Icons.swap_horiz_rounded,
            color: color,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.description.isEmpty
                      ? categoryName(s, m.categoryId)
                      : m.description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${categoryName(s, m.categoryId)} · ${accountName(s, m.accountId)}${m.kind == MovementKind.transfer ? ' → ${accountName(s, m.targetAccountId)}' : ''}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Money(
                  m.amountCents,
                  prefix: m.kind == MovementKind.income
                      ? '+ '
                      : m.kind == MovementKind.expense
                      ? '− '
                      : '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  DateFormat('d MMM', 'es_AR').format(m.date),
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetContent extends ConsumerWidget {
  const BudgetContent({
    super.key,
    required this.b,
    required this.s,
    required this.month,
  });
  final Map<String, dynamic> b;
  final FinanceSnapshot s;
  final DateTime month;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(moneyStyleProvider);
    final spent = Finance.spent(s, b['category_id'], month),
        limit = b['limit_cents'] as int;
    final ratio = spent / limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                categoryName(s, b['category_id']),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${(ratio * 100).round()} %',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ratio > 1 ? coral : green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Progress(ratio, color: ratio > 1 ? coral : green),
        const SizedBox(height: 8),
        Text(
          '${money(spent, style)} de ${money(limit, style)}',
          style: const TextStyle(fontSize: 11),
        ),
        Text(
          limit >= spent
              ? 'Disponible: ${money(limit - spent, style)}'
              : 'Excedido: ${money(spent - limit, style)}',
          style: TextStyle(fontSize: 11, color: limit >= spent ? green : coral),
        ),
      ],
    );
  }
}

class GoalContent extends ConsumerWidget {
  const GoalContent({super.key, required this.g});
  final Map<String, dynamic> g;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(moneyStyleProvider);
    final ratio = g['saved_cents'] / g['target_cents'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                g['name'],
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${(ratio * 100).toStringAsFixed(1).replaceAll('.', ',')} %',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Progress(ratio),
        const SizedBox(height: 8),
        Text(
          '${money(g['saved_cents'], style)} de ${money(g['target_cents'], style)}',
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}

String dateLabel(String date) =>
    DateFormat('d MMM yyyy', 'es_AR').format(DateTime.parse(date));
