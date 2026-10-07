import 'repository.dart';

Future<void> seedDemo(LocalFinanceRepository repo) async {
  final now = DateTime.now();
  final month = DateTime(now.year, now.month, 1);
  Future<void> insert(
    String table,
    String id,
    Map<String, dynamic> values,
  ) async {
    // Explicit IDs are for this isolated, local demo only.
    final data = {
      ...values,
      'id': id,
      'household_id': repo.householdId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await repo.db.customStatement(
      'INSERT INTO $table (${data.keys.join(',')}) VALUES (${List.filled(data.length, '?').join(',')})',
      data.values.toList(),
    );
  }

  for (final a in [
    ['cash', 'Efectivo', 'cash', 8500000],
    ['bank', 'Cuenta bancaria', 'bank', 68500000],
    ['wallet', 'Billetera virtual', 'wallet', 12500000],
    ['credit', 'Visa · Banco', 'credit', -12400000],
    ['savings', 'Fondo de ahorros', 'savings', 75000000],
  ]) {
    await insert('accounts', a[0] as String, {
      'name': a[1],
      'kind': a[2],
      'opening_cents': a[3],
    });
  }
  final cats = {
    'food': 'Alimentación',
    'housing': 'Vivienda',
    'services': 'Servicios',
    'transport': 'Transporte',
    'health': 'Salud',
    'education': 'Educación',
    'fun': 'Entretenimiento',
    'shopping': 'Compras',
    'tax': 'Impuestos',
    'other': 'Otros',
  };
  for (final c in cats.entries) {
    await insert('categories', c.key, {'name': c.value, 'kind': 'expense'});
  }
  await insert('categories', 'salary', {'name': 'Sueldo', 'kind': 'income'});
  await insert('categories', 'extra', {
    'name': 'Ingresos extra',
    'kind': 'income',
  });
  await insert('categories', 'groceries', {
    'name': 'Supermercado',
    'kind': 'expense',
    'parent_id': 'food',
  });
  var n = 0;
  for (var offset = -5; offset <= 0; offset++) {
    final m = DateTime(month.year, month.month + offset, 1);
    for (final transfer in [
      ('wallet', 30000000, 'Carga de billetera'),
      ('cash', 10000000, 'Retiro de efectivo'),
    ]) {
      await insert('movements', 'demo-${n++}', {
        'kind': 'transfer',
        'amount_cents': transfer.$2,
        'occurred_on': dateOnly(m),
        'account_id': 'bank',
        'target_account_id': transfer.$1,
        'description': transfer.$3,
      });
    }
    await insert('movements', 'demo-${n++}', {
      'kind': 'income',
      'amount_cents': 180000000 + (offset * 6000000),
      'occurred_on': dateOnly(m),
      'account_id': 'bank',
      'category_id': 'salary',
      'description': 'Sueldo mensual',
    });
    final costs = [
      ('housing', 48000000, 'Alquiler', 'bank', 2),
      ('food', 21500000 + offset * 1000000, 'Supermercado', 'wallet', 3),
      ('services', 9800000, 'Servicios del hogar', 'bank', 4),
      ('transport', 6200000, 'Transporte', 'cash', 5),
      ('fun', 4500000, 'Salida en familia', 'wallet', 6),
    ];
    for (final e in costs) {
      final day = offset == 0 && now.day < e.$5 ? now.day : e.$5;
      await insert('movements', 'demo-${n++}', {
        'kind': 'expense',
        'amount_cents': e.$2,
        'occurred_on': dateOnly(DateTime(m.year, m.month, day)),
        'account_id': e.$4,
        'category_id': e.$1,
        'description': e.$3,
      });
    }
  }
  for (final b in [
    ('food', 30000000),
    ('services', 15000000),
    ('fun', 8000000),
    ('transport', 10000000),
  ]) {
    await insert('budgets', 'budget-${b.$1}', {
      'category_id': b.$1,
      'month': monthOnly(month),
      'limit_cents': b.$2,
    });
  }
  for (final r in [
    ('internet', 'Internet hogar', 3200000, 10),
    ('insurance', 'Seguro del auto', 4800000, 15),
    ('rent', 'Alquiler', 48000000, 1),
  ]) {
    var due = DateTime(month.year, month.month, r.$4);
    if (due.isBefore(DateTime(now.year, now.month, now.day))) {
      due = DateTime(month.year, month.month + 1, r.$4);
    }
    await insert('recurring', r.$1, {
      'name': r.$2,
      'amount_cents': r.$3,
      'account_id': 'bank',
      'category_id': r.$1 == 'rent' ? 'housing' : 'services',
      'frequency': 'monthly',
      'next_due': dateOnly(due),
    });
  }
  await insert('installments', 'laptop', {
    'name': 'Notebook familiar',
    'account_id': 'credit',
    'category_id': 'shopping',
    'total_cents': 96000000,
    'count': 12,
    'paid_count': 0,
    'first_due': dateOnly(DateTime(month.year, month.month, 20)),
  });
  await insert('debts', 'debt-one', {
    'name': 'Préstamo a Martín',
    'direction': 'owed',
    'amount_cents': 12000000,
    'due_on': dateOnly(DateTime(month.year, month.month + 1, 5)),
  });
  await insert('debts', 'debt-two', {
    'name': 'Arreglo de la casa',
    'direction': 'owe',
    'amount_cents': 24000000,
    'settled_cents': 6000000,
    'due_on': dateOnly(DateTime(month.year, month.month, 25)),
  });
  await insert('goals', 'vacation', {
    'name': 'Vacaciones en familia',
    'account_id': 'savings',
    'target_cents': 200000000,
    'saved_cents': 75000000,
    'due_on': dateOnly(DateTime(month.year + 1, 1, 15)),
  });
  await insert('goals', 'emergency', {
    'name': 'Fondo de tranquilidad',
    'account_id': 'savings',
    'target_cents': 350000000,
    'saved_cents': 0,
    'due_on': dateOnly(DateTime(month.year + 1, 6, 1)),
  });
}
