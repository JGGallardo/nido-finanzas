import 'package:flutter_test/flutter_test.dart';
import 'package:nido_finanzas/domain/finance.dart';
import 'package:nido_finanzas/domain/models.dart';

FinanceSnapshot snapshot({
  List<Account> accounts = const [],
  List<Category> categories = const [],
  List<Movement> movements = const [],
}) => FinanceSnapshot(
  accounts: accounts,
  categories: categories,
  movements: movements,
  budgets: const [],
  recurring: const [],
  installments: const [],
  debts: const [],
  goals: const [],
);
void main() {
  const accounts = [
    Account(
      id: 'a',
      name: 'Origen',
      kind: AccountKind.bank,
      openingCents: 10000,
    ),
    Account(
      id: 'b',
      name: 'Destino',
      kind: AccountKind.savings,
      openingCents: 5000,
    ),
  ];
  const categories = [
    Category(id: 'income', name: 'Sueldo', kind: 'income'),
    Category(id: 'expense', name: 'Compras', kind: 'expense'),
    Category(
      id: 'child',
      name: 'Alimentos',
      kind: 'expense',
      parentId: 'expense',
    ),
  ];
  test(
    'Money parses integer cents exactly; invalid precision and signs are rejected',
    () {
      expect(Finance.parseMoney('1.234,56'), 123456);
      expect(Finance.parseMoney('1.500'), 150000);
      expect(Finance.parseMoney('0,01'), 1);
      expect(Finance.parseMoney('1500.5'), 150050);
      for (final input in ['0', '-1', 'NaN', '1,234', '1e6']) {
        expect(() => Finance.parseMoney(input), throwsFormatException);
      }
    },
  );
  test('Transfer changes both balances and conserves consolidated balance', () {
    final s = snapshot(
      accounts: accounts,
      movements: [
        Movement(
          id: 't',
          kind: MovementKind.transfer,
          amountCents: 3000,
          date: DateTime(2026, 10, 7),
          accountId: 'a',
          targetAccountId: 'b',
          description: 'Ahorro',
        ),
      ],
    );
    expect(Finance.balances(s), {'a': 7000, 'b': 8000});
    expect(Finance.total(s, MovementKind.income, DateTime(2026, 10)), 0);
    expect(Finance.total(s, MovementKind.expense, DateTime(2026, 10)), 0);
  });
  test('Income and expense change balance with correct sign', () {
    final s = snapshot(
      accounts: accounts,
      movements: [
        Movement(
          id: 'i',
          kind: MovementKind.income,
          amountCents: 1000,
          date: DateTime(2026, 10, 1),
          accountId: 'a',
          categoryId: 'income',
          description: '',
        ),
        Movement(
          id: 'e',
          kind: MovementKind.expense,
          amountCents: 350,
          date: DateTime(2026, 10, 2),
          accountId: 'a',
          categoryId: 'expense',
          description: '',
        ),
      ],
    );
    expect(Finance.balances(s)['a'], 10650);
  });
  test('Month boundaries include subcategories and exclude transfers', () {
    final s = snapshot(
      accounts: accounts,
      categories: categories,
      movements: [
        Movement(
          id: 'a',
          kind: MovementKind.expense,
          amountCents: 90,
          date: DateTime(2026, 9, 30),
          accountId: 'a',
          categoryId: 'expense',
          description: '',
        ),
        Movement(
          id: 'b',
          kind: MovementKind.expense,
          amountCents: 150,
          date: DateTime(2026, 10, 31, 23, 59),
          accountId: 'a',
          categoryId: 'child',
          description: '',
        ),
        Movement(
          id: 'c',
          kind: MovementKind.expense,
          amountCents: 70,
          date: DateTime(2026, 11, 1),
          accountId: 'a',
          categoryId: 'expense',
          description: '',
        ),
      ],
    );
    expect(Finance.spent(s, 'expense', DateTime(2026, 10)), 150);
    expect(Finance.total(s, MovementKind.expense, DateTime(2026, 10)), 150);
  });
  test('Installments preserve every cent across all counts', () {
    for (var n = 1; n <= 120; n++) {
      final values = Finance.splitInstallments(100001, n);
      expect(values.reduce((a, b) => a + b), 100001);
      expect(
        values.reduce((a, b) => a > b ? a : b) -
            values.reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(1),
      );
    }
    expect(() => Finance.splitInstallments(100, 0), throwsArgumentError);
    expect(() => Finance.splitInstallments(1, 2), throwsArgumentError);
  });
  test('Recurrence handles month end and leap years', () {
    expect(
      Finance.nextDate(DateTime(2026, 1, 31), 'monthly'),
      DateTime(2026, 2, 28),
    );
    expect(
      Finance.nextDate(DateTime(2024, 2, 29), 'yearly'),
      DateTime(2025, 2, 28),
    );
    expect(
      Finance.nextDate(DateTime(2026, 12, 30), 'weekly'),
      DateTime(2027, 1, 6),
    );
  });
  test(
    'Installment forecast uses original day and excludes paid installments',
    () {
      final p = {
        'total_cents': 10000,
        'count': 3,
        'paid_count': 1,
        'first_due': '2026-01-31',
      };
      expect(Finance.installmentDue(p, DateTime(2026, 1)), 0);
      expect(Finance.installmentDue(p, DateTime(2026, 2)), 3333);
      expect(Finance.installmentDue(p, DateTime(2026, 3)), 3333);
    },
  );
  test('Future movements are excluded from current balances', () {
    final s = snapshot(
      accounts: accounts,
      movements: [
        Movement(
          id: 'f',
          kind: MovementKind.income,
          amountCents: 500,
          date: DateTime(2027),
          accountId: 'a',
          categoryId: 'income',
          description: '',
        ),
      ],
    );
    expect(Finance.balances(s, through: DateTime(2026, 12, 31))['a'], 10000);
  });
  test(
    'Movement validation rejects same-account transfers and category type mismatch',
    () {
      expect(
        () => Finance.validateMovement(
          Movement(
            id: 'x',
            kind: MovementKind.transfer,
            amountCents: 100,
            date: DateTime(2026),
            accountId: 'a',
            targetAccountId: 'a',
            description: '',
          ),
          accounts,
          categories,
        ),
        throwsArgumentError,
      );
      expect(
        () => Finance.validateMovement(
          Movement(
            id: 'x',
            kind: MovementKind.expense,
            amountCents: 100,
            date: DateTime(2026),
            accountId: 'a',
            categoryId: 'income',
            description: '',
          ),
          accounts,
          categories,
        ),
        throwsArgumentError,
      );
      expect(
        () => Finance.validateMovement(
          Movement(
            id: 'x',
            kind: MovementKind.transfer,
            amountCents: 100,
            date: DateTime(2026),
            accountId: 'a',
            targetAccountId: 'usd',
            description: '',
          ),
          [
            ...accounts,
            const Account(
              id: 'usd',
              name: 'USD',
              kind: AccountKind.bank,
              openingCents: 0,
              currency: 'USD',
            ),
          ],
          categories,
        ),
        throwsArgumentError,
      );
    },
  );
}
