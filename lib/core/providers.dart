import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../domain/models.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
final repositoryProvider = Provider<FinanceRepository>(
  (ref) => LocalFinanceRepository(ref.watch(databaseProvider)),
);
final snapshotProvider = FutureProvider<FinanceSnapshot>((ref) async {
  final repository = ref.watch(repositoryProvider);
  if (repository is LocalFinanceRepository) {
    await repository.initialize();
  }
  return repository.load();
});
final monthProvider = NotifierProvider<MonthController, DateTime>(
  MonthController.new,
);

class MonthController extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime(DateTime.now().year, DateTime.now().month, 1);
  void move(int delta) => state = DateTime(state.year, state.month + delta, 1);
}

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);
final themeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(preferencesProvider).getBool('dark') == true
      ? ThemeMode.dark
      : ThemeMode.light;
  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    ref.read(preferencesProvider).setBool('dark', state == ThemeMode.dark);
  }
}

final moneyStyleProvider = NotifierProvider<MoneyStyleController, String>(
  MoneyStyleController.new,
);

class MoneyStyleController extends Notifier<String> {
  @override
  String build() =>
      ref.read(preferencesProvider).getString('money_style') ?? 'symbol';
  void set(String value) {
    state = value;
    ref.read(preferencesProvider).setString('money_style', value);
  }
}
