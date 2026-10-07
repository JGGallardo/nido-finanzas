import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../domain/models.dart';
import '../domain/finance.dart';
import 'database.dart' show AppDatabase;
import 'seed.dart';

class LocalFinanceRepository implements FinanceRepository {
  LocalFinanceRepository(this.db, {this.householdId = 'demo-household'});
  final AppDatabase db;
  final String householdId;
  static const collections = {
    'accounts',
    'categories',
    'movements',
    'budgets',
    'recurring',
    'installments',
    'debts',
    'goals',
  };
  static const columns = {
    'accounts': {'name', 'kind', 'opening_cents', 'currency'},
    'categories': {'name', 'kind', 'parent_id'},
    'movements': {
      'kind',
      'amount_cents',
      'occurred_on',
      'account_id',
      'target_account_id',
      'category_id',
      'recurring_id',
      'description',
      'source_type',
      'source_id',
    },
    'budgets': {'category_id', 'month', 'limit_cents'},
    'recurring': {
      'name',
      'amount_cents',
      'account_id',
      'category_id',
      'frequency',
      'next_due',
    },
    'installments': {
      'name',
      'account_id',
      'category_id',
      'total_cents',
      'count',
      'paid_count',
      'first_due',
    },
    'debts': {'name', 'direction', 'amount_cents', 'settled_cents', 'due_on'},
    'goals': {'name', 'account_id', 'target_cents', 'saved_cents', 'due_on'},
  };
  Future<void> initialize({bool demo = true}) async {
    await db.transaction(() async {
      final rows = await db
          .customSelect(
            'SELECT id FROM households WHERE id = ?',
            variables: [Variable(householdId)],
          )
          .get();
      if (rows.isNotEmpty) {
        return;
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await db.customStatement(
        'INSERT OR IGNORE INTO users (id,display_name,updated_at) VALUES (?,?,?)',
        ['local-user', 'Vos', now],
      );
      await db.customStatement(
        'INSERT INTO households (id,name,updated_at) VALUES (?,?,?)',
        [householdId, 'Mi hogar', now],
      );
      await db.customStatement(
        'INSERT INTO household_members (id,household_id,user_id,role,updated_at) VALUES (?,?,?,?,?)',
        [const Uuid().v4(), householdId, 'local-user', 'owner', now],
      );
      if (demo) {
        await seedDemo(this);
      }
    });
  }

  Future<List<Map<String, dynamic>>> rows(String collection) async {
    if (!collections.contains(collection)) {
      throw ArgumentError('Colección desconocida');
    }
    final result = await db
        .customSelect(
          'SELECT * FROM $collection WHERE household_id = ? AND deleted_at IS NULL',
          variables: [Variable(householdId)],
        )
        .get();
    return result.map((r) => r.data).toList();
  }

  @override
  Future<FinanceSnapshot> load() async => db.transaction(
    () async => FinanceSnapshot(
      accounts: (await rows('accounts')).map(Account.fromMap).toList(),
      categories: (await rows('categories')).map(Category.fromMap).toList(),
      movements: (await rows('movements')).map(Movement.fromMap).toList(),
      budgets: await rows('budgets'),
      recurring: await rows('recurring'),
      installments: await rows('installments'),
      debts: await rows('debts'),
      goals: await rows('goals'),
    ),
  );

  Future<Map<String, dynamic>> find(String collection, String id) async {
    final matches = (await rows(collection)).where((r) => r['id'] == id);
    if (matches.isEmpty) {
      throw ArgumentError('El registro ya no está disponible.');
    }
    return matches.first;
  }

  @override
  Future<void> save(
    String collection,
    Map<String, dynamic> values, {
    String? id,
  }) async {
    if (!collections.contains(collection) ||
        values.keys.any((k) => !columns[collection]!.contains(k))) {
      throw ArgumentError('Campos inválidos');
    }
    await db.transaction(() async {
      final entityId = id ?? const Uuid().v4();
      Map<String, dynamic>? previous;
      if (id != null) {
        previous = await find(collection, id);
      }
      final data = {
        ...?previous,
        ...values,
        'id': entityId,
        'household_id': householdId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'deleted_at': null,
        'revision': (previous?['revision'] as int? ?? 0) + 1,
      };
      await validate(collection, data);
      if (previous == null) {
        final keys = data.keys.toList();
        await db.customStatement(
          'INSERT INTO $collection (${keys.join(',')}) VALUES (${List.filled(keys.length, '?').join(',')})',
          keys.map((k) => data[k]).toList(),
        );
      } else {
        final keys = data.keys
            .where((k) => k != 'id' && k != 'household_id')
            .toList();
        await db.customStatement(
          'UPDATE $collection SET ${keys.map((k) => '$k = ?').join(',')} WHERE id = ? AND household_id = ?',
          [...keys.map((k) => data[k]), entityId, householdId],
        );
      }
      // Read persisted defaults too: synchronization payload must be a complete entity.
      await enqueue(
        collection,
        entityId,
        'upsert',
        await find(collection, entityId),
      );
    });
  }

  Future<void> validate(String c, Map<String, dynamic> v) async {
    if (c == 'movements') {
      final old = (await rows(c)).where((r) => r['id'] == v['id']).firstOrNull;
      if (old != null &&
          old['source_type'] != null &&
          columns[c]!
              .where((f) => f != 'description')
              .any((f) => old[f] != v[f])) {
        throw ArgumentError(
          'Este movimiento pertenece a un pago o aporte registrado. Solo podés editar sus notas.',
        );
      }
      if (v['source_type'] != null) {
        if (!{
          'recurring',
          'installments',
          'debts',
          'goals',
        }.contains(v['source_type'])) {
          throw ArgumentError('Origen de movimiento inválido.');
        }
        await find(v['source_type'], v['source_id']);
      }
    }
    if (c == 'installments') {
      final old = (await rows(c)).where((r) => r['id'] == v['id']).firstOrNull;
      if (old != null &&
          old['paid_count'] > 0 &&
          [
            'total_cents',
            'count',
            'first_due',
            'account_id',
            'category_id',
          ].any((field) => old[field] != v[field])) {
        throw ArgumentError(
          'Una compra con cuotas registradas solo permite editar su nombre.',
        );
      }
    }
    if (c == 'goals') {
      final old = (await rows(c)).where((r) => r['id'] == v['id']).firstOrNull;
      if (old != null &&
          old['saved_cents'] > 0 &&
          old['account_id'] != v['account_id']) {
        throw ArgumentError(
          'Una meta con ahorros registrados debe conservar su cuenta de ahorros.',
        );
      }
    }
    if (c == 'debts') {
      final old = (await rows(c)).where((r) => r['id'] == v['id']).firstOrNull;
      if (old != null &&
          old['settled_cents'] > 0 &&
          old['direction'] != v['direction']) {
        throw ArgumentError(
          'Una deuda con pagos registrados debe conservar su tipo.',
        );
      }
    }
    if (v['name'] is String && (v['name'] as String).trim().isEmpty) {
      throw ArgumentError('Ingresá un nombre.');
    }
    for (final field in ['account_id', 'target_account_id']) {
      if (v[field] != null) {
        await find('accounts', v[field]);
      }
    }
    if (v['category_id'] != null) {
      final cat = await find('categories', v['category_id']);
      if (c != 'movements' && cat['kind'] != 'expense') {
        throw ArgumentError('Elegí una categoría de gasto.');
      }
    }
    if (c == 'movements') {
      final s = await load();
      Finance.validateMovement(Movement.fromMap(v), s.accounts, s.categories);
      if (v['recurring_id'] != null) {
        await find('recurring', v['recurring_id']);
      }
    }
    if (c == 'categories' && v['parent_id'] != null) {
      final parent = await find('categories', v['parent_id']);
      if (parent['kind'] != v['kind']) {
        throw ArgumentError(
          'La subcategoría debe tener el mismo tipo que su categoría.',
        );
      }
      final categories = (await rows(
        'categories',
      )).map(Category.fromMap).toList();
      if (Finance.categoryTree(categories, v['id']).contains(v['parent_id'])) {
        throw ArgumentError(
          'Una categoría no puede depender de sí misma ni de sus subcategorías.',
        );
      }
    }
    if (c == 'categories') {
      final previous = (await rows(
        'categories',
      )).where((row) => row['id'] == v['id']).firstOrNull;
      if (previous != null && previous['kind'] != v['kind']) {
        for (final table in [
          'movements',
          'budgets',
          'recurring',
          'installments',
        ]) {
          if ((await rows(table)).any((row) => row['category_id'] == v['id'])) {
            throw ArgumentError(
              'No se puede cambiar el tipo de una categoría en uso.',
            );
          }
        }
        if ((await rows(
          'categories',
        )).any((row) => row['parent_id'] == v['id'])) {
          throw ArgumentError('Primero modificá las subcategorías.');
        }
      }
    }
    if (c == 'accounts' && v['currency'] != 'ARS') {
      throw ArgumentError('Esta versión trabaja con cuentas en ARS.');
    }
    if (c == 'installments') {
      Finance.splitInstallments(v['total_cents'], v['count']);
      final a = await find('accounts', v['account_id']);
      if (a['kind'] != 'credit') {
        throw ArgumentError('Seleccioná una tarjeta de crédito.');
      }
    }
    if (c == 'goals') {
      final a = await find('accounts', v['account_id']);
      if (a['kind'] != 'savings') {
        throw ArgumentError('La meta necesita una cuenta de ahorros.');
      }
    }
    if (c == 'budgets' &&
        (await rows('budgets')).any(
          (r) =>
              r['category_id'] == v['category_id'] &&
              r['month'] == v['month'] &&
              r['id'] != v['id'],
        )) {
      throw ArgumentError('Ya existe un presupuesto para esa categoría y mes.');
    }
  }

  Future<void> enqueue(
    String collection,
    String id,
    String op,
    Map<String, dynamic> payload,
  ) => db.customStatement(
    'INSERT INTO outbox (id,household_id,entity_type,entity_id,operation,payload,created_at) VALUES (?,?,?,?,?,?,?)',
    [
      const Uuid().v4(),
      householdId,
      collection,
      id,
      op,
      jsonEncode(payload),
      DateTime.now().toUtc().toIso8601String(),
    ],
  );

  @override
  Future<void> remove(String collection, String id) async {
    await db.transaction(() async {
      final row = await find(collection, id);
      if (collection == 'movements' && row['source_type'] != null) {
        throw ArgumentError(
          'Este movimiento corresponde a un pago o aporte registrado y no puede eliminarse en esta versión.',
        );
      }
      final checks = <String, List<String>>{};
      if (collection == 'accounts') {
        checks.addAll({
          'movements': ['account_id', 'target_account_id'],
          'recurring': ['account_id'],
          'installments': ['account_id'],
          'goals': ['account_id'],
        });
      }
      if (collection == 'categories') {
        checks.addAll({
          'movements': ['category_id'],
          'budgets': ['category_id'],
          'recurring': ['category_id'],
          'installments': ['category_id'],
          'categories': ['parent_id'],
        });
      }
      for (final entry in checks.entries) {
        if ((await rows(
          entry.key,
        )).any((r) => entry.value.any((f) => r[f] == id))) {
          throw ArgumentError(
            'Este registro tiene operaciones asociadas. Eliminá o reasigná esas operaciones primero.',
          );
        }
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await db.customStatement(
        'UPDATE $collection SET deleted_at = ?, updated_at = ?, revision = revision + 1 WHERE id = ? AND household_id = ?',
        [now, now, id, householdId],
      );
      await enqueue(collection, id, 'delete', {
        ...row,
        'deleted_at': now,
        'updated_at': now,
        'revision': row['revision'] + 1,
      });
    });
  }

  @override
  Future<void> payRecurring(String id) async => db.transaction(() async {
    final r = await find('recurring', id);
    await save('movements', {
      'kind': 'expense',
      'amount_cents': r['amount_cents'],
      'occurred_on': dateOnly(DateTime.now()),
      'account_id': r['account_id'],
      'category_id': r['category_id'],
      'description': r['name'],
      'recurring_id': id,
      'source_type': 'recurring',
      'source_id': id,
    });
    await save('recurring', {
      'next_due': Finance.nextDate(
        DateTime.parse(r['next_due']),
        r['frequency'],
      ).toIso8601String().substring(0, 10),
    }, id: id);
  });
  @override
  Future<void> payInstallment(String id) async => db.transaction(() async {
    final r = await find('installments', id);
    if (r['paid_count'] >= r['count']) {
      throw ArgumentError('Todas las cuotas ya están registradas.');
    }
    await save('movements', {
      'kind': 'expense',
      'amount_cents': Finance.installmentAmount(r),
      'occurred_on': dateOnly(DateTime.now()),
      'source_type': 'installments',
      'source_id': id,
      'account_id': r['account_id'],
      'category_id': r['category_id'],
      'description':
          '${r['name']} · cuota ${r['paid_count'] + 1}/${r['count']}',
    });
    await save('installments', {'paid_count': r['paid_count'] + 1}, id: id);
  });
  @override
  Future<void> settleDebt(String id, String accountId, int amountCents) async =>
      db.transaction(() async {
        final r = await find('debts', id);
        if (amountCents <= 0 ||
            amountCents > r['amount_cents'] - r['settled_cents']) {
          throw ArgumentError('El importe supera el saldo pendiente.');
        }
        final kind = r['direction'] == 'owe' ? 'expense' : 'income';
        final categoryLabel = kind == 'expense'
            ? 'Pago de deudas'
            : 'Cobro de deudas';
        var category = (await rows('categories'))
            .where((c) => c['kind'] == kind && c['name'] == categoryLabel)
            .firstOrNull;
        if (category == null) {
          await save('categories', {'kind': kind, 'name': categoryLabel});
          category = (await rows(
            'categories',
          )).firstWhere((c) => c['kind'] == kind && c['name'] == categoryLabel);
        }
        await save('movements', {
          'kind': kind,
          'source_type': 'debts',
          'source_id': id,
          'amount_cents': amountCents,
          'occurred_on': dateOnly(DateTime.now()),
          'account_id': accountId,
          'category_id': category['id'],
          'description':
              '${kind == 'expense' ? 'Pago' : 'Cobro'} de deuda · ${r['name']}',
        });
        await save('debts', {
          'settled_cents': r['settled_cents'] + amountCents,
        }, id: id);
      });
  @override
  Future<void> contribute(
    String id,
    String sourceAccountId,
    int amountCents,
  ) async => db.transaction(() async {
    final r = await find('goals', id);
    await save('movements', {
      'kind': 'transfer',
      'source_type': 'goals',
      'source_id': id,
      'amount_cents': amountCents,
      'occurred_on': dateOnly(DateTime.now()),
      'account_id': sourceAccountId,
      'target_account_id': r['account_id'],
      'description': 'Aporte · ${r['name']}',
    });
    await save('goals', {
      'saved_cents': r['saved_cents'] + amountCents,
    }, id: id);
  });
}

String dateOnly(DateTime date) => date.toIso8601String().substring(0, 10);
String monthOnly(DateTime date) => date.toIso8601String().substring(0, 7);
