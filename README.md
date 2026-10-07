# Nido Finanzas

**Más calma. Más futuro.** Aplicación multiplataforma para organizar las finanzas del hogar, construida con Flutter y arquitectura local-first.

## Estado de esta primera entrega

MVP local funcional con datos de demostración. Proyectos Android, iOS, web, Windows, macOS y Linux generados. La versión web es la plataforma compilada y verificada en esta etapa; las plataformas nativas requieren sus toolchains y pruebas en dispositivos antes de distribuir.

El proyecto es independiente de cualquier otro producto: almacenamiento, backend, configuración y servicios propios. No implementa todavía autenticación, sincronización cloud, pagos comerciales, suscripciones ni despliegue en Railway.

## Funcionalidades

- Dashboard: saldo consolidado, ingresos, gastos y balance mensual, evolución, distribución por categoría, vencimientos, presupuestos, metas y deudas.
- Cuentas de efectivo, banco, billetera, tarjeta, ahorros y otras; saldo inicial y saldo derivado del historial.
- Ingresos, gastos y transferencias: alta, edición, eliminación lógica, fecha, importe, categoría/subcategoría, cuenta y notas. Buscador y filtro por tipo/mes.
- Categorías y subcategorías personalizadas, protegidas contra ciclos y eliminación mientras están en uso.
- Presupuestos por categoría/mes, progreso y monto disponible/excedido. Incluyen subcategorías.
- Recurrentes con frecuencia, vencimiento y registro manual de pago.
- Tarjetas y compras en cuotas con distribución exacta, avance de cuotas registradas y proyección a seis meses.
- Deudas por pagar/cobrar, vencimiento y pagos/cobros parciales.
- Metas de ahorro con aportes mediante transferencias y progreso.
- Reportes de ingresos/gastos, saldo acumulado, categorías, comparación mensual y presupuesto vs. real.
- Tema claro/oscuro persistente, moneda ARS con símbolo/código configurable, navegación inferior móvil y menú lateral de escritorio.
- SQLite local nativo y SQLite WASM en navegador. Demo de seis meses, incluyendo transferencias y ejemplos de todos los módulos.
- Cola outbox transaccional, UUID, revisiones y eliminaciones lógicas para futura sincronización.

## Requisitos

- Flutter **3.47.6 stable**, Dart 3.13.5 (incluido en Flutter).
- Node.js >=22 para el backend y scripts de preview/caché offline.
- Git.
- Para Windows: modo desarrollador habilitado para enlaces simbólicos de plugins, y Visual Studio con C++ si se compila desktop.
- Para Android: Android SDK/JDK. Para iOS/macOS: macOS + Xcode. Para Linux: herramientas requeridas por Flutter desktop.

Las versiones se resuelven en `pubspec.lock` y `backend/package-lock.json`. El analizador se limita a `<14.5.0` por incompatibilidad detectada entre esa versión y build_runner 2.16.1. Revisar ese límite al actualizar el generador.

## Instalación y ejecución

Desde la raíz del proyecto:

```sh
flutter pub get
dart run build_runner build
flutter run -d chrome
```

Para dispositivos nativos, seleccionar el destino correspondiente en `flutter devices`, por ejemplo `flutter run -d windows` en un entorno con las herramientas necesarias.

En Windows, instalar el SDK de Flutter en una ruta sin espacios: el ejecutor de native assets de esta versión presenta problemas con rutas con espacios al ejecutar tests. La carpeta del proyecto puede tener espacios. No agregar el SDK al repositorio.

Los datos demo se crean una sola vez, al abrir un hogar nuevo; cerrar y abrir la app no duplica registros. El MVP usa un hogar local y no requiere Internet para operaciones financieras. No ingresar secretos en la app. Esta versión no tiene backup/exportación todavía.

## Variables de entorno

`.env.example` documenta configuración pública Flutter y configuración privada de backend. Flutter no lee ese archivo automáticamente: utilizar `--dart-define` cuando se incorpore el adaptador REST:

```sh
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1 --dart-define=SYNC_ENABLED=false
```

Las variables del frontend quedan visibles en el build; jamás incluir claves privadas o contraseñas. `SYNC_ENABLED` y `API_BASE_URL` son preparación; actualmente no hay sincronizador activo incluso si se cambia la bandera.

Para el servicio independiente:

```sh
cd backend
npm ci
# Copiar .env.example a .env y completar valores propios.
npm run check
npm test
npm start
```

`GET /health` responde con el estado del proceso sin consultar ni modificar una base de datos. El endpoint `/api/v1/households/:householdId/sync` devuelve 501 hasta implementar autenticación y autorización. El pool PostgreSQL está preparado pero no se utiliza en la API del MVP. La migración `backend/migrations/001_initial.sql` es una base de diseño, pendiente de ejecutar y validar en PostgreSQL propio. No usa credenciales de otros servicios.

## Verificación

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter build web --release --base-href /nido-finanzas/ --no-web-resources-cdn
node tool/generate_sw.mjs
```

Los tests cubren centavos y redondeo, transferencias, signo de saldos, ventanas mensuales, subcategorías, cuotas, recurrencias, restricciones entre hogares, rollback, outbox, pagos parciales, aportes, persistencia SQLite y todos los módulos a 390, 900 y 1440 px. El backend verifica salud, respuesta explícita de sync no implementado y endpoints inexistentes.

Para probar el build exacto publicado en Pages:

```sh
node tool/serve_web.mjs
```

Abrir `http://127.0.0.1:8080/nido-finanzas/`. El server de preview solo escucha en la interfaz local. El script de service worker genera un caché versionado del build completo, incluyendo SQLite, fuentes y CanvasKit. La primera carga requiere conexión y completar la caché antes de abrir offline. La navegación usa hash, por lo que las rutas no dependen de reescrituras del servidor.

## GitHub Pages

El workflow `.github/workflows/pages.yml` verifica formato, análisis, tests, build y backend antes de publicar. Los pull requests solo verifican. Cada actualización de `main` y las ejecuciones manuales despliegan la versión web en el entorno `github-pages`.

En el repositorio nuevo, abrir **Settings → Pages → Source → GitHub Actions**. Confirmar la primera ejecución exitosa en **Actions**. El repositorio y la publicación remota se habilitan únicamente después de la autorización requerida por el entorno. No confundir una URL prevista con un sitio ya publicado.

Los datos de cada visitante son locales al origen web: no se publican en GitHub y no se comparten entre dispositivos. La demo crea ejemplos locales y se puede editar. No es una API en producción.

## Arquitectura y siguiente etapa

Consultar [arquitectura](docs/architecture.md), [próximos pasos](docs/roadmap.md) y [origen de assets SQLite](docs/web-assets.md). La próxima etapa es autenticación y hogares reales, API REST con autorización por hogar, migraciones verificadas en PostgreSQL independiente y sincronización idempotente. Railway se configura después con servicios exclusivos para esta app.

Pendientes: backup/restauración, anulación transaccional de pagos y aportes, gestión completa de resumen de tarjeta, retiros/reasignación de metas, adjuntos, notificaciones, multimoneda, pruebas nativas y preparación de tiendas. Las deudas y cuotas futuras son compromisos planificados; no alteran automáticamente el saldo hasta registrar sus movimientos.

## Propiedad y dependencias

Nombre provisional: Nido Finanzas. El repositorio no incluye una licencia que otorgue derechos de uso del código comercial del proyecto. Las dependencias conservan sus licencias originales.
