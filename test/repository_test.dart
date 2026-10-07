import 'dart:io';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nido_finanzas/data/database.dart' show AppDatabase;
import 'package:nido_finanzas/data/repository.dart';
import 'package:nido_finanzas/domain/finance.dart';

void main() {
  late AppDatabase db;
  late LocalFinanceRepository repo;
  var memoryClosed = false;
  setUp(() async {
    memoryClosed = false;
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalFinanceRepository(db);
    await repo.initialize();
  });
  tearDown(() async {
    if (!memoryClosed) {
      await db.close();
    }
  });
  test('Demo initialization is idempotent and includes every module', () async {
    final before = await repo.load();
    await repo.initialize();
    final after = await repo.load();
    expect(after.movements.length, before.movements.length);
    expect(after.accounts.length, 5);
    expect(after.budgets, isNotEmpty);
    expect(after.recurring, isNotEmpty);
    expect(after.installments, isNotEmpty);
    expect(after.debts, isNotEmpty);
    expect(after.goals, isNotEmpty);
  });
  test(
    'Transfers are atomic; edits and deletes recompute balances and retain tombstones',
    () async {
      final before = Finance.balances(await repo.load());
      await repo.save('movements', {
        'kind': 'transfer',
        'amount_cents': 10001,
        'occurred_on': dateOnly(DateTime.now()),
        'account_id': 'bank',
        'target_account_id': 'cash',
        'description': 'Transfer test',
      });
      final row = (await repo.rows('movements')).last;
      final after = Finance.balances(await repo.load());
      expect(after['bank'], before['bank']! - 10001);
      expect(after['cash'], before['cash']! + 10001);
      expect(
        after.values.reduce((a, b) => a + b),
        before.values.reduce((a, b) => a + b),
      );
      await repo.save('movements', {'amount_cents': 15000}, id: row['id']);
      expect(
        Finance.balances(await repo.load())['bank'],
        before['bank']! - 15000,
      );
      await repo.remove('movements', row['id']);
      expect(Finance.balances(await repo.load()), before);
      final outbox = await db
          .customSelect('SELECT * FROM outbox ORDER BY rowid')
          .get();
      expect(outbox.length, 3);
      expect(outbox.last.data['operation'], 'delete');
      expect(jsonDecode(outbox.first.data['payload'])['revision'], 1);
    },
  );
  test('Invalid transfer rolls back movement and outbox', () async {
    final count = (await repo.rows('movements')).length;
    await expectLater(
      repo.save('movements', {
        'kind': 'transfer',
        'amount_cents': 100,
        'occurred_on': '2026-10-01',
        'account_id': 'bank',
        'target_account_id': 'bank',
        'description': '',
      }),
      throwsArgumentError,
    );
    expect((await repo.rows('movements')).length, count);
    expect(await db.customSelect('SELECT * FROM outbox').get(), isEmpty);
  });
  test(
    'Household isolation rejects references and updates belonging to another household',
    () async {
      final other = LocalFinanceRepository(db, householdId: 'other-household');
      await other.initialize(demo: false);
      expect((await other.load()).accounts, isEmpty);
      await expectLater(
        other.save('accounts', {'name': 'Hack'}, id: 'bank'),
        throwsArgumentError,
      );
      await expectLater(
        other.save('movements', {
          'kind': 'expense',
          'amount_cents': 100,
          'occurred_on': '2026-10-01',
          'account_id': 'bank',
          'category_id': 'food',
          'description': '',
        }),
        throwsArgumentError,
      );
      expect((await repo.find('accounts', 'bank'))['name'], 'Cuenta bancaria');
    },
  );
  test(
    'Categories prevent cycles, mismatched kinds and deletion while referenced',
    () async {
      await expectLater(
        repo.save('categories', {'parent_id': 'groceries'}, id: 'food'),
        throwsArgumentError,
      );
      await expectLater(
        repo.save('categories', {'parent_id': 'salary'}, id: 'food'),
        throwsArgumentError,
      );
      await expectLater(repo.remove('categories', 'food'), throwsArgumentError);
      await expectLater(repo.remove('accounts', 'bank'), throwsArgumentError);
      await expectLater(
        repo.save('categories', {'kind': 'income'}, id: 'food'),
        throwsArgumentError,
      );
    },
  );
  test('Budget uniqueness includes household, category and month', () async {
    await expectLater(
      repo.save('budgets', {
        'category_id': 'food',
        'month': monthOnly(DateTime.now()),
        'limit_cents': 100,
      }),
      throwsArgumentError,
    );
    await repo.save('budgets', {
      'category_id': 'food',
      'month': '2090-01',
      'limit_cents': 100,
    });
    expect((await repo.rows('budgets')).length, 5);
  });
  test(
    'Recurring payment creates an expense and advances due date together',
    () async {
      final before = await repo.find('recurring', 'internet');
      await repo.payRecurring('internet');
      final after = await repo.find('recurring', 'internet');
      expect(
        after['next_due'],
        dateOnly(
          Finance.nextDate(DateTime.parse(before['next_due']), 'monthly'),
        ),
      );
      final m = (await repo.rows('movements')).last;
      expect(m['amount_cents'], before['amount_cents']);
      expect(m['source_id'], 'internet');
      expect(m['occurred_on'], dateOnly(DateTime.now()));
      expect((await db.customSelect('SELECT * FROM outbox').get()).length, 2);
    },
  );
  test(
    'Installments register the exact total once and protect financial history',
    () async {
      final before = (await repo.rows('movements')).length;
      for (var i = 0; i < 12; i++) {
        await repo.payInstallment('laptop');
      }
      expect((await repo.find('installments', 'laptop'))['paid_count'], 12);
      final records = (await repo.rows(
        'movements',
      )).where((m) => m['source_id'] == 'laptop').toList();
      expect(
        records.fold<int>(0, (a, m) => a + (m['amount_cents'] as int)),
        96000000,
      );
      expect((await repo.rows('movements')).length, before + 12);
      await expectLater(repo.payInstallment('laptop'), throwsArgumentError);
      await expectLater(
        repo.save('installments', {'total_cents': 100000000}, id: 'laptop'),
        throwsArgumentError,
      );
      await expectLater(
        repo.remove('movements', records.first['id']),
        throwsArgumentError,
      );
      await expectLater(
        repo.save('movements', {'amount_cents': 1}, id: records.first['id']),
        throwsArgumentError,
      );
    },
  );
  test(
    'Debt payment rejects overpayment and rolls back when account is invalid',
    () async {
      final before = await repo.find('debts', 'debt-two');
      await expectLater(
        repo.settleDebt('debt-two', 'bank', 18000001),
        throwsArgumentError,
      );
      await expectLater(
        repo.settleDebt('debt-two', 'missing', 100),
        throwsArgumentError,
      );
      expect(
        (await repo.find('debts', 'debt-two'))['settled_cents'],
        before['settled_cents'],
      );
      await repo.settleDebt('debt-two', 'bank', 10001);
      expect((await repo.find('debts', 'debt-two'))['settled_cents'], 6010001);
      expect((await repo.rows('movements')).last['kind'], 'expense');
      await repo.settleDebt('debt-one', 'bank', 100);
      expect((await repo.rows('movements')).last['kind'], 'income');
    },
  );
  test(
    'Goal contribution transfers funds without adding expenses or consolidated money',
    () async {
      final before = await repo.load();
      await repo.contribute('vacation', 'bank', 10001);
      final after = await repo.load();
      expect(
        after.goals.firstWhere((g) => g['id'] == 'vacation')['saved_cents'],
        75010001,
      );
      expect(
        Finance.balances(after)['savings'],
        Finance.balances(before)['savings']! + 10001,
      );
      expect(
        Finance.balances(after).values.reduce((a, b) => a + b),
        Finance.balances(before).values.reduce((a, b) => a + b),
      );
      await expectLater(
        repo.contribute('vacation', 'savings', 100),
        throwsArgumentError,
      );
      expect((await repo.find('goals', 'vacation'))['saved_cents'], 75010001);
    },
  );
  test('Data persists after closing and reopening SQLite', () async {
    await db.close();
    memoryClosed = true;
    final dir = await Directory.systemTemp.createTemp('nido-test-');
    final file = File('${dir.path}/nido.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    final r = LocalFinanceRepository(first);
    await r.initialize(demo: false);
    await r.save('accounts', {
      'name': 'Persistente',
      'kind': 'cash',
      'opening_cents': 12345,
      'currency': 'ARS',
    });
    await first.close();
    final second = AppDatabase(NativeDatabase(file));
    try {
      expect(
        (await LocalFinanceRepository(
          second,
        ).load()).accounts.single.openingCents,
        12345,
      );
    } finally {
      await second.close();
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final tempFile = File('${file.path}$suffix');
        if (await tempFile.exists()) await tempFile.delete();
      }
      await dir.delete();
    }
  });
}
