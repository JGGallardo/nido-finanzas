import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';
import 'dashboard.dart';
import 'modules.dart';
import 'forms.dart';
import 'reports.dart';
import 'widgets.dart';
import 'theme.dart';

class Destination {
  const Destination(this.key, this.label, this.icon);
  final String key, label;
  final IconData icon;
  String get path => '/$key';
}

const destinations = [
  Destination('dashboard', 'Mi resumen', Icons.space_dashboard_outlined),
  Destination('movements', 'Movimientos', Icons.swap_vert_rounded),
  Destination('accounts', 'Cuentas', Icons.account_balance_wallet_outlined),
  Destination('budgets', 'Presupuestos', Icons.donut_small_outlined),
  Destination('recurring', 'Gastos recurrentes', Icons.event_repeat_outlined),
  Destination('installments', 'Tarjetas y cuotas', Icons.credit_card_outlined),
  Destination('debts', 'Deudas', Icons.handshake_outlined),
  Destination('goals', 'Metas de ahorro', Icons.savings_outlined),
  Destination('reports', 'Reportes', Icons.bar_chart_rounded),
  Destination('categories', 'Categorías', Icons.category_outlined),
  Destination('settings', 'Configuración', Icons.tune_rounded),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.section});
  final String section;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 1040;
    final snapshot = ref.watch(snapshotProvider);
    return Scaffold(
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(child: NavigationMenu(section: section)),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              SizedBox(width: 244, child: NavigationMenu(section: section)),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 36 : 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (!wide)
                          Builder(
                            builder: (context) => IconButton(
                              tooltip: 'Abrir menú',
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                              icon: const Icon(Icons.menu_rounded),
                            ),
                          ),
                        Text(
                          wide
                              ? destinations
                                    .firstWhere((d) => d.key == section)
                                    .label
                              : 'nido',
                          style: TextStyle(
                            fontSize: wide ? 14 : 25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: green.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.wifi_off_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Local',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Cambiar tema',
                          onPressed: () =>
                              ref.read(themeProvider.notifier).toggle(),
                          icon: Icon(
                            ref.watch(themeProvider) == ThemeMode.dark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                        ),
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFE6EBDD),
                          child: Text(
                            'MH',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: snapshot.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_outlined, size: 48),
                              const SizedBox(height: 12),
                              const Text('No pudimos abrir los datos locales.'),
                              const Text(
                                'Verificá que el navegador permita almacenamiento y recargá.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () =>
                                    ref.invalidate(snapshotProvider),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      data: (s) => SingleChildScrollView(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1440),
                            child: Padding(
                              padding: EdgeInsets.all(wide ? 32 : 18),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Column(
                                  key: ValueKey(section),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    PageHeading(section: section),
                                    const SizedBox(height: 26),
                                    if (section == 'dashboard')
                                      Dashboard(s: s)
                                    else if (section == 'reports')
                                      Reports(s: s)
                                    else if (section == 'settings')
                                      const SettingsPage()
                                    else
                                      ModulePage(section: section, s: s),
                                    const SizedBox(height: 28),
                                    Text(
                                      'Tus datos se guardan en este dispositivo. Hogar de demostración.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex:
                  [
                    'dashboard',
                    'movements',
                    'accounts',
                    'goals',
                  ].contains(section)
                  ? [
                      'dashboard',
                      'movements',
                      'accounts',
                      'goals',
                    ].indexOf(section)
                  : 4,
              onDestinationSelected: (i) {
                if (i == 4) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => SafeArea(
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height * .8,
                        child: NavigationMenu(section: section),
                      ),
                    ),
                  );
                } else {
                  context.go(
                    '/${['dashboard', 'movements', 'accounts', 'goals'][i]}',
                  );
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  label: 'Resumen',
                ),
                NavigationDestination(
                  icon: Icon(Icons.swap_vert_rounded),
                  label: 'Movimientos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  label: 'Cuentas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.savings_outlined),
                  label: 'Metas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: 'Más',
                ),
              ],
            ),
    );
  }
}

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({super.key, required this.section});
  final String section;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 24, 24),
          child: Row(
            children: [
              Icon(
                Icons.spa_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              const SizedBox(width: 10),
              Text(
                'nido',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.8,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                SoftIcon(Icons.home_outlined, size: 34),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mi hogar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Un espacio para tu familia',
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final d in destinations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: d.key == section,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .1),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      leading: Icon(d.icon, size: 21),
                      title: Text(
                        d.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: d.key == section
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                        context.go(d.path);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: green.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Más calma. Más futuro.',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cada pequeño paso cuenta.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class PageHeading extends ConsumerWidget {
  const PageHeading({super.key, required this.section});
  final String section;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = section == 'dashboard'
        ? 'Tu hogar, en equilibrio'
        : destinations.firstWhere((d) => d.key == section).label;
    final subtitles = {
      'dashboard': 'Una mirada clara a lo que tenés, gastás y soñás.',
      'movements': 'Cada ingreso y cada gasto, en un solo lugar.',
      'accounts': 'Tu dinero, organizado a tu manera.',
      'budgets': 'Dale un plan a cada peso.',
      'recurring': 'Lo de siempre, sin olvidos.',
      'installments': 'Tus próximos pagos, con claridad.',
      'debts': 'Lo que debés y lo que te deben.',
      'goals': 'Pequeños pasos hacia grandes planes.',
      'reports': 'Entendé tus hábitos y mirá cómo avanzás.',
      'categories': 'Un orden que se adapta a tu hogar.',
      'settings': 'Hacé que Nido se sienta tuyo.',
    };
    return LayoutBuilder(
      builder: (context, c) {
        final button = ['reports', 'settings'].contains(section)
            ? null
            : FilledButton.icon(
                onPressed: () => openEditor(
                  context,
                  ref,
                  section == 'dashboard' ? 'movements' : section,
                ),
                icon: const Icon(Icons.add, size: 19),
                label: Text(
                  section == 'dashboard'
                      ? 'Nuevo movimiento'
                      : section == 'categories'
                      ? 'Nueva categoría'
                      : section == 'accounts'
                      ? 'Nueva cuenta'
                      : 'Agregar',
                ),
              );
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text(
              subtitles[section]!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.maxWidth < 620) ...[
              heading,
              if (button != null) ...[const SizedBox(height: 18), button],
            ] else
              Row(
                children: [
                  Expanded(child: heading),
                  ?button,
                ],
              ),
            if ([
              'dashboard',
              'movements',
              'budgets',
              'reports',
            ].contains(section)) ...[
              const SizedBox(height: 20),
              const MonthPicker(),
            ],
          ],
        );
      },
    );
  }
}

class MonthPicker extends ConsumerWidget {
  const MonthPicker({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Mes anterior',
          onPressed: () => ref.read(monthProvider.notifier).move(-1),
          icon: const Icon(Icons.chevron_left, size: 20),
        ),
        Text(
          DateFormat('MMMM yyyy', 'es_AR').format(ref.watch(monthProvider)),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        IconButton(
          tooltip: 'Mes siguiente',
          onPressed: () => ref.read(monthProvider.notifier).move(1),
          icon: const Icon(Icons.chevron_right, size: 20),
        ),
      ],
    ),
  );
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('A tu manera'),
        const SizedBox(height: 18),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tema oscuro'),
          subtitle: const Text(
            'También podés cambiarlo desde la barra superior.',
          ),
          value: ref.watch(themeProvider) == ThemeMode.dark,
          onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
        ),
        const Divider(),
        DropdownButtonFormField<String>(
          initialValue: ref.watch(moneyStyleProvider),
          decoration: const InputDecoration(
            labelText: 'Formato monetario · pesos argentinos',
          ),
          items: const [
            DropdownMenuItem(value: 'symbol', child: Text(r'$ 150.000')),
            DropdownMenuItem(value: 'code', child: Text('ARS 150.000')),
          ],
          onChanged: (v) {
            if (v != null) ref.read(moneyStyleProvider.notifier).set(v);
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Sobre tus datos',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nido funciona con almacenamiento local. Esta versión comienza con un hogar y datos de demostración que podés editar o eliminar. Los cambios permanecen en este navegador o dispositivo. No hay cuenta online ni sincronización todavía. Al borrar los datos del navegador se pierde la información local.',
        ),
        const SizedBox(height: 16),
        const Text('Nido Finanzas · MVP 0.1.0', style: TextStyle(fontSize: 12)),
      ],
    ),
  );
}
