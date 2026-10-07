import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers.dart';
import 'presentation/shell.dart';
import 'presentation/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_AR');
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [preferencesProvider.overrideWithValue(preferences)],
      child: const NidoApp(),
    ),
  );
}

final router = GoRouter(
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/dashboard'),
    for (final item in destinations)
      GoRoute(
        path: item.path,
        builder: (context, state) => AppShell(section: item.key),
      ),
  ],
);

class NidoApp extends ConsumerWidget {
  const NidoApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Nido Finanzas',
    debugShowCheckedModeBanner: false,
    theme: appTheme(false),
    darkTheme: appTheme(true),
    themeMode: ref.watch(themeProvider),
    locale: const Locale('es', 'AR'),
    supportedLocales: const [Locale('es', 'AR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: router,
  );
}
