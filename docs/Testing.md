# Pruebas

## Niveles

| Nivel | Dónde | Qué debe cubrir cuando exista la función |
| --- | --- | --- |
| Unitaria | Servicios y dominio, sin HTTP ni base real | Contraseñas, reglas de fechas, recurrencia diaria, semanal y mensual, versiones y autorización por dueño |
| Integración de API | Supertest contra `createApp()`. PostgreSQL solo con `RUN_DB_INTEGRATION=1` | Validación, `401`, `404` de un recurso ajeno, conflictos `409` y persistencia real |
| Widget | `flutter_test` | Estados de carga, vacío, error y reintento, sin red |
| Manual de dispositivo | Android | Cifrado local, aviso local y comportamiento offline. No sustituye a las anteriores |

No se exige una prueba de extremo a extremo con emulador en esta etapa. No hay un emulador comprobado ni licencias de Android aceptadas.

## Herramientas

- Cliente: `flutter test` y `flutter analyze`, con `flutter_lints` 6.0.0.
- API: Jest 30.5.2, ts-jest 29.4.14 y Supertest 7.3.1. El script usa `--experimental-vm-modules` porque el proyecto es ESM. Node avisa de que esa opción es experimental; las 22 pruebas aun así terminaron bien.
- Formato: `dart format` y Prettier 3.9.10.
- Análisis: analizador de Dart y ESLint 10.12.0.
- Dependencias: `npm audit`. El 13 de octubre de 2026 informó 24 avisos. No hay un fallo de auditoría que se haya corregido en esta tarea.

## Pruebas que existen

Cliente:

- `test/app_shell_test.dart`: el cascarón muestra `SecurePlan` y el estado vacío.
- `test/shared_widgets_test.dart`: vacío, reintento del error y mensaje de carga.
- `test/password_policy_test.dart`: correo y política de contraseña.
- `test/access_token_test.dart`: un token vigente, uno caducado y uno malformado.
- `test/auth_controller_test.dart`: arranque sin token, token caducado, red caída, rechazo del servidor, guardado y borrado.
- `test/auth_screen_test.dart`: inicio en vez de la agenda, validación, carga, error, entrada a la agenda, cierre y registro.
- `test/event_rules_test.dart`: título, descripción, fecha e intervalo.
- `test/agenda_screen_test.dart`: carga, error y reintento, día seleccionado, cambio de mes, alta, edición, borrado con confirmación y error HTTP.

API:

- `tests/http.test.ts`: `GET /health` y el `404` de una ruta de producto inexistente, incluida la ausencia de `X-Powered-By`.
- `tests/env.test.ts`: valores por defecto, puerto inválido, `DATABASE_URL` vacío y `JWT_SECRET` corto.
- `tests/error-handler.test.ts`: un `AppError` se expone; una excepción inesperada no devuelve su mensaje.
- `tests/prisma-client.test.ts`: sin `DATABASE_URL`, el singleton lanza y no construye el cliente.
- `tests/auth.test.ts`: registro, hash Argon2id, entrada inválida, correo duplicado, inicio, credenciales iguales si el usuario no existe, JWT caducado, token malformado, ruta protegida, cierre sin revocación, límite de intentos, error de repositorio sin filtrar el texto y clasificación de `P2002`.
- `tests/events.test.ts`: alta válida, rechazo de `userId` en el cuerpo, título, descripción, categoría, prioridad e intervalo, listado propio, lectura, edición y borrado, acceso de otro usuario, identificador ausente, petición anónima e identificador malformado.
- `tests/recurrence.test.ts`: evento único, intervalos diario y semanal, meses cortos, 29 de febrero, desfase, rango parcial, excepciones y límites.
- `tests/events.test.ts` también cubre la expansión, la edición de una ocurrencia, la edición de la serie, la exclusión, el borrado de la serie, el acceso ajeno y un rango excesivo.
- `tests/sync.test.ts`: alta repetida con el mismo identificador, conflicto de versión, lápida y aislamiento del snapshot.
- `tests/postgres-integration.test.ts`: registro, inicio, CRUD y una serie mensual real. Queda omitida si no existe `RUN_DB_INTEGRATION=1`.
- `test/phase3_domain_test.dart`: meses cortos en el cliente, JSON, CSV, error de escritura, observer, recordatorios y reintentos.
- `test/local_agenda_test.dart`: base cifrada, cola que sobrevive al cierre, alta sin red, un solo envío al reconectar, aislamiento entre cuentas y conflicto sin sobrescritura.

`npm test` usa repositorios en memoria y omite la prueba de PostgreSQL. Esa prueba, con la variable activada, sí abre `secureplan_dev` y borra solo los usuarios `phase1-*@secureplan.test` que ella crea. El caso `P2002` de la suite en memoria solo comprueba el clasificador.

Resultado comprobado el 14 de octubre de 2026, después de la agenda local: `flutter analyze` sin incidencias, `flutter test` con 33 pruebas superadas, `npm test` con 35 pruebas superadas y 2 omitidas, y esas 2 superadas con `RUN_DB_INTEGRATION=1`. `npm run lint` y `npm run build` quedaron limpios.

## Qué no se debe simular todavía

No añadir pruebas de recurrencia o sincronización que pasen contra funciones vacías. Esas pruebas se escriben junto con la regla que protegen.

Cuando llegue la recurrencia, los casos mínimos son: todos los días, todas las semanas el mismo día, todos los meses con el tope de un mes corto, una fecha `until` y un `count`. El aislamiento entre usuarios ya está cubierto en memoria y en PostgreSQL.

## Criterio mínimo para dar por cerrada una tarea futura

- La prueba nueva falla si se quita la regla.
- `flutter analyze` o `npm run lint` no añaden incidencias.
- El cambio no deja secretos en el diff.
- Si toca la API, el `500` sigue sin devolver el error interno.
