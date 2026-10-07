# Próxima etapa

## Autenticación y hogares

Elegir un proveedor de identidad o implementar sesiones del backend con hashing robusto de contraseñas, refresh tokens revocables, rate limiting y verificación de correo. Guardar tokens en almacenamiento seguro nativo; definir cookies seguras y protección CSRF para web. Nunca enviar `DATABASE_URL` o secretos al cliente. Separar cuenta local de cuenta cloud, y ofrecer migración voluntaria de datos reales desde el hogar local. Incorporar selector de hogar, invitaciones y roles owner/editor/viewer con autorización en cada consulta REST.

## API Express y PostgreSQL

Convertir la migración preparada en una migración revisada con tests sobre una instancia nueva PostgreSQL. Añadir contratos REST/OpenAPI, validación de entradas, límites BIGINT seguros, índices por hogar/fecha, política de auditoría y transacciones para pagos, transferencias y sincronización. Implementar aislamiento de hogares en repositorios del servidor y considerar RLS como segunda capa. Añadir pruebas de autorización, idempotencia, concurrencia, conflictos y recuperación de fallos antes de activar sync.

## Railway independiente

Crear un nuevo proyecto Railway con dos servicios exclusivos de Nido: API y PostgreSQL. Utilizar credenciales, volumen, variables, dominio y backups propios. Configurar `DATABASE_URL` mediante la referencia de ese PostgreSQL, CORS con el dominio elegido, healthcheck `/health`, HTTPS, límites de conexiones y migraciones durante el despliegue. Confirmar backups, restauración y observabilidad antes de recibir datos reales. Esta etapa no configura ni despliega Railway.

## Producto y publicación comercial

- Implementar backup/exportación y restauración de datos locales antes de invitar a usuarios a registrar información importante.
- Anular pagos/aportes con movimientos de reversión; retiros y reasignación de metas; conciliación de tarjetas, cierre, pago de resumen y comisiones.
- Adjuntos de comprobantes, notificaciones locales, recurrentes opcionales automáticos y filtro por cuenta/categoría.
- Selector multiusuario, sincronización y políticas de privacidad/retención.
- Definir monedas adicionales y conversión; el MVP solo admite ARS y permite elegir símbolo o código monetario.
- Revisar accesibilidad, tamaños de texto, lectores de pantalla y almacenamiento en Safari/Chrome móvil con dispositivos reales.
- Firmar Android e iOS con credenciales fuera del repositorio, definir identificadores finales de paquete, preparar fichas, screenshots, política de privacidad y cumplir los requisitos vigentes de las tiendas.
- Compilar y probar plataformas nativas con sus herramientas correspondientes. iOS/macOS requieren macOS con Xcode; Windows requiere Visual Studio con C++; Android requiere SDK/JDK. Las carpetas generadas no equivalen a builds nativos verificados.
- Pagos y suscripciones comerciales se mantienen fuera de esta etapa.
