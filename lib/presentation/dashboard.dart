import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';
import '../domain/models.dart';
import '../domain/finance.dart';
import '../data/repository.dart';
import 'widgets.dart';
import 'theme.dart';
import 'modules.dart';

class Dashboard extends ConsumerWidget {
  const Dashboard({super.key, required this.s});
  final FinanceSnapshot s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(monthProvider);
    final income = Finance.total(s, MovementKind.income, month),
        expense = Finance.total(s, MovementKind.expense, month);
    final balances = Finance.balances(s, through: DateTime.now());
    final total = balances.values.fold(0, (a, b) => a + b);
    final budgets = s.budgets
        .where((b) => b['month'] == monthOnly(month))
        .toList();
    final moves =
        s.movements.where((m) => Finance.inMonth(m.date, month)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final due = <({String name, DateTime date, int amount, String path})>[
      for (final r in s.recurring)
        (
          name: r['name'],
          date: DateTime.parse(r['next_due']),
          amount: r['amount_cents'],
          path: '/recurring',
        ),
      for (final p in s.installments.where((p) => p['paid_count'] < p['count']))
        (
          name: '${p['name']} · cuota ${p['paid_count'] + 1}',
          date: Finance.shiftMonth(
            DateTime.parse(p['first_due']),
            p['paid_count'],
          ),
          amount: Finance.installmentAmount(p),
          path: '/installments',
        ),
      for (final d in s.debts.where(
        (d) =>
            d['direction'] == 'owe' && d['settled_cents'] < d['amount_cents'],
      ))
        (
          name: d['name'],
          date: DateTime.parse(d['due_on']),
          amount: d['amount_cents'] - d['settled_cents'],
          path: '/debts',
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 850;
        final stats = [
          BalanceCard(total: total),
          StatCard(
            'Ingresos del mes',
            income,
            Icons.south_west_rounded,
            green,
            'Lo que entra a tu hogar',
          ),
          StatCard(
            'Gastos del mes',
            expense,
            Icons.north_east_rounded,
            coral,
            'Lo que invertís en tu día a día',
          ),
          StatCard(
            'Balance mensual',
            income - expense,
            Icons.balance_rounded,
            blue,
            income >= expense ? 'Vas por buen camino' : 'Un mes para revisar',
          ),
        ];
        Widget pair(Widget a, Widget b) => wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: a),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: b),
                ],
              )
            : Column(children: [a, const SizedBox(height: 20), b]);
        return Column(
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final card in stats)
                  SizedBox(
                    width: wide
                        ? (c.maxWidth - 48) / 4
                        : c.maxWidth >= 520
                        ? (c.maxWidth - 16) / 2
                        : c.maxWidth,
                    child: card,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            pair(
              Panel(
                child: Column(
                  children: [
                    SectionTitle(
                      'El ritmo de tu hogar',
                      subtitle: 'Ingresos y gastos · últimos 6 meses',
                      action: TextButton(
                        onPressed: () => context.go('/reports'),
                        child: const Text('Ver reportes'),
                      ),
                    ),
                    const SizedBox(height: 28),
                    TrendChart(s: s, month: month),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Legend('Ingresos', green),
                        SizedBox(width: 24),
                        Legend('Gastos', coral),
                      ],
                    ),
                  ],
                ),
              ),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      '¿A dónde va tu dinero?',
                      subtitle: 'Gastos por categoría',
                    ),
                    const SizedBox(height: 16),
                    CategoryChart(s: s, month: month),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            pair(
              Panel(
                child: Column(
                  children: [
                    SectionTitle(
                      'Últimos movimientos',
                      action: TextButton(
                        onPressed: () => context.go('/movements'),
                        child: const Text('Ver todos'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (moves.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Text('Todavía no hay movimientos en este mes.'),
                      ),
                    for (final m in moves.take(5)) MovementTile(m: m, s: s),
                  ],
                ),
              ),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      'Tus presupuestos',
                      action: IconButton(
                        tooltip: 'Ver presupuestos',
                        onPressed: () => context.go('/budgets'),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      ),
                    ),
                    if (budgets.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('Creá un presupuesto para este mes.'),
                      ),
                    for (final b in budgets.take(4))
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: BudgetContent(b: b, s: s, month: month),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            pair(
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      'Lo que se viene',
                      subtitle: 'Próximos vencimientos',
                    ),
                    const SizedBox(height: 12),
                    if (due.isEmpty) const Text('Sin vencimientos pendientes.'),
                    for (final d in due.take(4))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SoftIcon(
                          Icons.event_outlined,
                          color:
                              d.date.isBefore(
                                DateTime.now().subtract(
                                  const Duration(days: 1),
                                ),
                              )
                              ? coral
                              : gold,
                          size: 42,
                        ),
                        title: Text(
                          d.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('d MMM yyyy', 'es_AR').format(d.date),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: SizedBox(
                          width: 110,
                          child: Money(
                            d.amount,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        onTap: () => context.go(d.path),
                      ),
                  ],
                ),
              ),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      'Planes que crecen',
                      action: IconButton(
                        tooltip: 'Ver metas',
                        onPressed: () => context.go('/goals'),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (s.goals.isEmpty)
                      const Text('Tu próxima meta empieza acá.'),
                    for (final g in s.goals.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: GoalContent(g: g),
                      ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Deudas pendientes',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Money(
                          s.debts
                              .where((d) => d['direction'] == 'owe')
                              .fold<int>(
                                0,
                                (a, d) =>
                                    a +
                                    (d['amount_cents'] as int) -
                                    (d['settled_cents'] as int),
                              ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: coral,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.total});
  final int total;
  @override
  Widget build(BuildContext context) => Container(
    height: 168,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [Color(0xFF23634D), Color(0xFF34755D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white70,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Saldo total',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Money(
          total,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const Spacer(),
        const Text(
          'Todas tus cuentas · ARS',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    ),
  );
}

class StatCard extends StatelessWidget {
  const StatCard(
    this.title,
    this.amount,
    this.icon,
    this.color,
    this.caption, {
    super.key,
  });
  final String title, caption;
  final int amount;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 168,
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoftIcon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Money(
            amount,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: -.8,
            ),
          ),
          const Spacer(),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class Legend extends StatelessWidget {
  const Legend(this.title, this.color, {super.key});
  final String title;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class TrendChart extends ConsumerWidget {
  const TrendChart({
    super.key,
    required this.s,
    required this.month,
    this.wealth = false,
  });
  final FinanceSnapshot s;
  final DateTime month;
  final bool wealth;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moneyStyle = ref.watch(moneyStyleProvider);
    final months = List.generate(
      6,
      (i) => DateTime(month.year, month.month - 5 + i, 1),
    );
    final series = wealth
        ? [
            List.generate(
              6,
              (i) =>
                  Finance.balances(
                    s,
                    through: DateTime(
                      months[i].year,
                      months[i].month + 1,
                      0,
                      23,
                      59,
                      59,
                    ),
                  ).values.fold<int>(0, (a, b) => a + b) /
                  100,
            ),
          ]
        : [
            for (final k in [MovementKind.income, MovementKind.expense])
              months.map((m) => Finance.total(s, k, m) / 100).toList(),
          ];
    return SizedBox(
      height: 210,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map(
                    (spot) => LineTooltipItem(
                      money((spot.y * 100).round(), moneyStyle),
                      TextStyle(
                        color: spot.bar.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(
              color: Theme.of(context).dividerColor,
              strokeWidth: 1,
              dashArray: [4, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (v, meta) => Text(
                  v.abs() >= 1000000
                      ? '${(v / 1000000).toStringAsFixed(1)}M'
                      : '${(v / 1000).round()}k',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  return i >= 0 && i < 6
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('MMM', 'es_AR').format(months[i]),
                            style: const TextStyle(fontSize: 10),
                          ),
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
          lineBarsData: [
            for (var j = 0; j < series.length; j++)
              LineChartBarData(
                spots: [
                  for (var i = 0; i < 6; i++)
                    FlSpot(i.toDouble(), series[j][i]),
                ],
                isCurved: false,
                color: j == 0 ? green : coral,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: (j == 0 ? green : coral).withValues(alpha: .05),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CategoryChart extends StatelessWidget {
  const CategoryChart({super.key, required this.s, required this.month});
  final FinanceSnapshot s;
  final DateTime month;
  @override
  Widget build(BuildContext context) {
    final cats =
        s.categories
            .where((c) => c.kind == 'expense' && c.parentId == null)
            .map((c) => (c, Finance.spent(s, c.id, month)))
            .where((c) => c.$2 > 0)
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
    if (cats.isEmpty) {
      return const SizedBox(
        height: 254,
        child: Center(child: Text('Sin gastos para este mes.')),
      );
    }
    final total = cats.fold<int>(0, (a, c) => a + c.$2);
    return Column(
      children: [
        SizedBox(
          height: 156,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 48,
                  sectionsSpace: 3,
                  sections: [
                    for (var i = 0; i < cats.length; i++)
                      PieChartSectionData(
                        value: cats[i].$2.toDouble(),
                        color: chartColors[i % chartColors.length],
                        showTitle: false,
                        radius: 22,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gastos del mes', style: TextStyle(fontSize: 10)),
                  Money(
                    total,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < cats.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Legend(
                    cats[i].$1.name,
                    chartColors[i % chartColors.length],
                  ),
                ),
                Text(
                  '${(cats[i].$2 / total * 100).toStringAsFixed(0)} %',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
