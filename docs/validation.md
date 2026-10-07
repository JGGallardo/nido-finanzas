# Verificación de la entrega local

Fecha: 7 de octubre de 2026. Flutter 3.47.6 stable, Dart 3.13.5, Node.js 22.13.0. Build web de producción con base `/nido-finanzas/` y recursos Flutter incluidos localmente.

| Verificación | Resultado |
|---|---|
| `dart format lib test` | Código formateado |
| `flutter analyze --no-pub` | Sin observaciones |
| `flutter test --no-pub --coverage` | 23 tests aprobados |
| `flutter build web --release --base-href /nido-finanzas/ --no-web-resources-cdn` | Build correcto |
| Generación del service worker propio | Caché versionado de 41 archivos |
| Backend: sintaxis de app, servidor y pool | Correcta |
| Backend: test HTTP | 1 test aprobado |
| SQLite nativo: cierre y reapertura | Datos conservados |
| Navegador: creación de cuenta con centavos y recarga | Datos conservados |
| Navegador: apertura, creación y eliminación lógica con servidor detenido | Correctas |
| UI: todos los módulos a 390, 900 y 1440 px | Tests sin desbordes |
| Browser: vista móvil 390 × 844 y desktop 1440 × 1000 | Inspección visual correcta |

Los tests financieros comprueban conservación del consolidado en transferencias, exclusión de transferencias de ingresos/gastos, importes exactos, límites mensuales y cuotas con distribución de centavos. Los tests del repositorio cubren aislamiento por hogar, rechazo de referencias inválidas, rollback de transacciones, outbox, subcategorías sin ciclos, presupuestos únicos, pagos de cuotas/recurrentes, deudas parciales y aportes a metas.

La comprobación offline se realizó después de una primera carga completa y de instalar la caché del sitio. Se detuvo el servidor local, se recargó la app, se creó una cuenta temporal de ARS 8,42 y se eliminó lógicamente para dejar la demo original. No se modificó información financiera real.

No se han ejecutado builds Android, iOS, Windows, macOS o Linux. Las carpetas de plataforma están preparadas; faltan toolchains, firmas y pruebas en dispositivos. La migración PostgreSQL está preparada pero no se ha aplicado a una instancia real. No hay despliegue Railway ni sincronización cloud. El despliegue GitHub Pages y la creación del repositorio remoto requieren la confirmación pendiente en esta entrega.
