import 'models.dart';

class Finance {
  static int parseMoney(String input) {
    final raw = input.trim().replaceAll(' ', '');
    // Locale es_AR: thousands '.'; decimals ','. A lone dot with <=2 digits is also accepted.
    final value = RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(raw)
        ? raw.replaceAll('.', '')
        : raw.contains(',')
        ? raw.replaceAll('.', '').replaceAll(',', '.')
        : raw;
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
      throw const FormatException(
        'Usá un importe positivo con hasta dos decimales (ej. 1500,50).',
      );
    }
    final parts = value.split('.');
    final cents =
        int.parse(parts[0]) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
    if (cents <= 0 || cents > 9000000000000000) {
      throw const FormatException(
        'El importe debe ser mayor a cero y estar dentro del límite permitido.',
      );
    }
    return cents;
  }

  static bool inMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;
  static Map<String, int> balances(FinanceSnapshot s, {DateTime? through}) {
    final result = {for (final a in s.accounts) a.id: a.openingCents};
    for (final m in s.movements) {
      if (through != null && m.date.isAfter(through)) {
        continue;
      }
      result[m.accountId] =
          (result[m.accountId] ?? 0) +
          (m.kind == MovementKind.income ? m.amountCents : -m.amountCents);
      if (m.kind == MovementKind.transfer) {
        result[m.targetAccountId!] =
            (result[m.targetAccountId!] ?? 0) + m.amountCents;
      }
    }
    return result;
  }

  static int total(FinanceSnapshot s, MovementKind kind, DateTime month) => s
      .movements
      .where((m) => m.kind == kind && inMonth(m.date, month))
      .fold(0, (sum, m) => sum + m.amountCents);
  static Set<String> categoryTree(List<Category> categories, String id) {
    final found = <String>{id};
    bool changed;
    do {
      changed = false;
      for (final c in categories) {
        if (found.contains(c.parentId) && found.add(c.id)) {
          changed = true;
        }
      }
    } while (changed);
    return found;
  }

  static int spent(FinanceSnapshot s, String categoryId, DateTime month) {
    final ids = categoryTree(s.categories, categoryId);
    return s.movements
        .where(
          (m) =>
              m.kind == MovementKind.expense &&
              ids.contains(m.categoryId) &&
              inMonth(m.date, month),
        )
        .fold(0, (v, m) => v + m.amountCents);
  }

  static List<int> splitInstallments(int totalCents, int count) {
    if (totalCents <= 0 || count < 1 || count > 120 || totalCents < count) {
      throw ArgumentError('Cantidad de cuotas inválida.');
    }
    return List.generate(
      count,
      (i) => totalCents ~/ count + (i < totalCents % count ? 1 : 0),
    );
  }

  static DateTime nextDate(DateTime date, String frequency) {
    if (frequency == 'weekly') {
      return date.add(const Duration(days: 7));
    }
    if (frequency == 'daily') {
      return date.add(const Duration(days: 1));
    }
    return shiftMonth(date, frequency == 'yearly' ? 12 : 1);
  }

  static DateTime shiftMonth(DateTime date, int offset) {
    final first = DateTime(date.year, date.month + offset, 1);
    final last = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, date.day > last ? last : date.day);
  }

  static int installmentAmount(Map<String, dynamic> p) =>
      splitInstallments(p['total_cents'], p['count'])[p['paid_count']];
  static int installmentDue(Map<String, dynamic> p, DateTime month) {
    var amount = 0;
    final parts = splitInstallments(p['total_cents'], p['count']);
    final first = DateTime.parse(p['first_due']);
    for (var i = p['paid_count'] as int; i < parts.length; i++) {
      if (inMonth(shiftMonth(first, i), month)) {
        amount += parts[i];
      }
    }
    return amount;
  }

  static void validateMovement(
    Movement m,
    List<Account> accounts,
    List<Category> categories,
  ) {
    if (m.amountCents <= 0) {
      throw ArgumentError('El importe debe ser mayor a cero.');
    }
    final source = accounts.where((a) => a.id == m.accountId).firstOrNull;
    if (source == null) {
      throw ArgumentError('Seleccioná una cuenta válida.');
    }
    if (m.kind == MovementKind.transfer) {
      final target = accounts
          .where((a) => a.id == m.targetAccountId)
          .firstOrNull;
      if (target == null || target.id == source.id) {
        throw ArgumentError('Elegí dos cuentas diferentes.');
      }
      if (target.currency != source.currency) {
        throw ArgumentError('Las cuentas deben usar la misma moneda.');
      }
      if (m.categoryId != null) {
        throw ArgumentError('Las transferencias no llevan categoría.');
      }
    } else {
      final category = categories
          .where((c) => c.id == m.categoryId)
          .firstOrNull;
      if (category == null || category.kind != m.kind.name) {
        throw ArgumentError(
          'La categoría debe corresponder al tipo de movimiento.',
        );
      }
      if (m.targetAccountId != null) {
        throw ArgumentError('Solo las transferencias tienen cuenta destino.');
      }
    }
  }
}
