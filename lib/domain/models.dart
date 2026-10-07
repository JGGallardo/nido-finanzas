enum MovementKind { income, expense, transfer }

enum AccountKind { cash, bank, wallet, credit, savings, other }

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.kind,
    required this.openingCents,
    this.currency = 'ARS',
  });
  final String id, name, currency;
  final AccountKind kind;
  final int openingCents;
  factory Account.fromMap(Map<String, dynamic> m) => Account(
    id: m['id'],
    name: m['name'],
    kind: AccountKind.values.byName(m['kind']),
    openingCents: m['opening_cents'],
    currency: m['currency'],
  );
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.parentId,
  });
  final String id, name, kind;
  final String? parentId;
  factory Category.fromMap(Map<String, dynamic> m) => Category(
    id: m['id'],
    name: m['name'],
    kind: m['kind'],
    parentId: m['parent_id'],
  );
}

class Movement {
  const Movement({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.date,
    required this.accountId,
    required this.description,
    this.categoryId,
    this.targetAccountId,
    this.recurringId,
  });
  final String id, accountId, description;
  final String? categoryId, targetAccountId, recurringId;
  final MovementKind kind;
  final int amountCents;
  final DateTime date;
  factory Movement.fromMap(Map<String, dynamic> m) => Movement(
    id: m['id'],
    kind: MovementKind.values.byName(m['kind']),
    amountCents: m['amount_cents'],
    date: DateTime.parse(m['occurred_on']),
    accountId: m['account_id'],
    description: m['description'],
    categoryId: m['category_id'],
    targetAccountId: m['target_account_id'],
    recurringId: m['recurring_id'],
  );
}

class FinanceSnapshot {
  const FinanceSnapshot({
    required this.accounts,
    required this.categories,
    required this.movements,
    required this.budgets,
    required this.recurring,
    required this.installments,
    required this.debts,
    required this.goals,
  });
  final List<Account> accounts;
  final List<Category> categories;
  final List<Movement> movements;
  final List<Map<String, dynamic>> budgets,
      recurring,
      installments,
      debts,
      goals;
}

abstract class FinanceRepository {
  Future<FinanceSnapshot> load();
  Future<void> save(
    String collection,
    Map<String, dynamic> values, {
    String? id,
  });
  Future<void> remove(String collection, String id);
  Future<void> payRecurring(String id);
  Future<void> payInstallment(String id);
  Future<void> settleDebt(String id, String accountId, int amountCents);
  Future<void> contribute(String id, String sourceAccountId, int amountCents);
}
