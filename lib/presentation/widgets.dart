import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';
import 'theme.dart';

String money(int cents, [String style = 'symbol']) => NumberFormat.currency(
  locale: 'es_AR',
  name: 'ARS',
  symbol: style == 'code' ? 'ARS' : r'$',
  customPattern: '¤ #,##0.00',
  decimalDigits: cents % 100 == 0 ? 0 : 2,
).format(cents / 100);

class Money extends ConsumerWidget {
  const Money(this.cents, {super.key, this.style, this.prefix = ''});
  final int cents;
  final TextStyle? style;
  final String prefix;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
    '$prefix${money(cents, ref.watch(moneyStyleProvider))}',
    style: style,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = 24});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      ?action,
    ],
  );
}

class SoftIcon extends StatelessWidget {
  const SoftIcon(this.icon, {super.key, this.color = green, this.size = 46});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color, size: size * .48),
  );
}

class Progress extends StatelessWidget {
  const Progress(this.value, {super.key, this.color = green});
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 8,
      color: color,
      backgroundColor: color.withValues(alpha: .12),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Panel(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SoftIcon(Icons.spa_outlined, size: 58),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    ),
  );
}

String friendlyError(Object e) {
  if (e is ArgumentError) {
    return e.message?.toString() ?? 'Revisá los datos ingresados.';
  }
  if (e is FormatException) {
    return e.message;
  }
  return 'No pudimos guardar el cambio. Revisá los datos e intentá nuevamente.';
}

Future<void> runAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  String success = 'Cambio guardado',
}) async {
  try {
    await action();
    ref.invalidate(snapshotProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

Future<bool> confirmDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este registro?'),
        content: const Text(
          'Dejará de aparecer en tu hogar y en los cálculos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ??
    false;
