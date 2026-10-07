import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/models.dart';
import '../domain/finance.dart';
import '../data/repository.dart';
import 'dashboard.dart';
import 'modules.dart';
import 'widgets.dart';
import 'theme.dart';

class Reports extends ConsumerWidget {
  const Reports({super.key, required this.s});
  final FinanceSnapshot s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(monthProvider),
        previous = DateTime(
          ref.watch(monthProvider).year,
          ref.watch(monthProvider).month - 1,
          1,
        );
    final income = Finance.total(s, MovementKind.income, month),
        expense = Finance.total(s, MovementKind.expense, month),
        prevIncome = Finance.total(s, MovementKind.income, previous),
        prevExpense = Finance.total(s, MovementKind.expense, previous);
    final budgets = s.budgets
        .where((b) => b['month'] == monthOnly(month))
        .toList();
    return Column(
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                'Este mes, en perspectiva',
                subtitle: 'Comparación con el mes anterior',
              ),
              const SizedBox(height: 18),
              comparison(
                'Ingresos',
                income,
                prevIncome,
                green,
                ref.watch(moneyStyleProvider),
              ),
              const Divider(height: 30),
              comparison(
                'Gastos',
                expense,
                prevExpense,
                coral,
                ref.watch(moneyStyleProvider),
              ),
              const Divider(height: 30),
              comparison(
                'Balance',
                income - expense,
                prevIncome - prevExpense,
                blue,
                ref.watch(moneyStyleProvider),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            children: [
              const SectionTitle(
                'Ingresos y gastos',
                subtitle: 'Evolución mensual',
              ),
              const SizedBox(height: 26),
              TrendChart(s: s, month: month),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Legend('Ingresos', green),
                  SizedBox(width: 20),
                  Legend('Gastos', coral),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            children: [
              const SectionTitle(
                'Evolución del saldo consolidado',
                subtitle:
                    'Saldo inicial + movimientos acumulados · no incluye deudas externas ni cuotas futuras',
              ),
              const SizedBox(height: 26),
              TrendChart(s: s, month: month, wealth: true),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final a = Panel(
                  child: Column(
                    children: [
                      const SectionTitle('Gastos por categoría'),
                      const SizedBox(height: 20),
                      CategoryChart(s: s, month: month),
                    ],
                  ),
                ),
                b = Panel(
                  child: Column(
                    children: [
                      const SectionTitle('Presupuesto vs. gasto real'),
                      const SizedBox(height: 12),
                      if (budgets.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Text('No hay presupuestos en este mes.'),
                        ),
                      for (final budget in budgets)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: BudgetContent(b: budget, s: s, month: month),
                        ),
                    ],
                  ),
                );
            return c.maxWidth > 750
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: a),
                      const SizedBox(width: 20),
                      Expanded(child: b),
                    ],
                  )
                : Column(children: [a, const SizedBox(height: 20), b]);
          },
        ),
      ],
    );
  }

  Widget comparison(
    String title,
    int current,
    int previous,
    Color color,
    String style,
  ) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              'Mes anterior: ${money(previous, style)}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Money(
              current,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              previous == 0
                  ? 'Sin base de comparación'
                  : '${((current - previous) / previous.abs() * 100).toStringAsFixed(1)} % vs. mes anterior',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    ],
  );
}
