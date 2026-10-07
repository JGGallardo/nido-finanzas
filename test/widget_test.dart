import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nido_finanzas/core/providers.dart';
import 'package:nido_finanzas/data/database.dart' show AppDatabase;
import 'package:nido_finanzas/data/repository.dart';
import 'package:nido_finanzas/main.dart';

void main() {
  for (final width in [390.0, 900.0, 1440.0]) {
    testWidgets('Responsive navigation and all modules at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await initializeDateFormatting('es_AR');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LocalFinanceRepository(db);
      await repo.initialize();
      final data = await repo.load();
      router.go('/dashboard');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            repositoryProvider.overrideWithValue(repo),
            snapshotProvider.overrideWith((ref) async => data),
          ],
          child: const NidoApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tu hogar, en equilibrio'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final section in [
        'movements',
        'accounts',
        'categories',
        'budgets',
        'recurring',
        'installments',
        'debts',
        'goals',
        'reports',
        'settings',
      ]) {
        router.go('/$section');
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'No overflow in $section at $width',
        );
      }
      router.go('/dashboard');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo movimiento'));
      await tester.pumpAndSettle();
      expect(find.text('Agregar movimiento'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    });
  }
}
