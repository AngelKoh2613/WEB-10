# Decisiones

Cada decisión indica su estado: tomada, o propuesta y pendiente de confirmación. Nada de lo pendiente se ha codificado como si ya estuviera cerrado.

## D1. Monorepositorio con dos proyectos

Estado: tomada.

Contexto: el directorio solo contenía la plantilla Flutter `flutter_application_1`, sin Git, sin API y sin documentación.

Alternativas: un repositorio solo para Flutter y otro para la API; o un workspace de Dart/npm.

Decisión: un directorio, con el cliente y `backend/` separados, sin workspaces. `docs/` describe el conjunto.

Consecuencias: hay dos instalaciones y dos juegos de pruebas. Un cambio de contrato se revisa en los dos lados a propósito.

## D2. Reutilizar la plantilla Flutter

Estado: tomada.

Contexto: el proyecto ya tenía Android, iOS y Windows generados con Flutter 3.47.6, revisión `5fc346839b`, y `lib/main.dart` mostraba `Hello World`.

Alternativas: borrar la plantilla y ejecutar `flutter create` otra vez.

Decisión: conservar los proyectos de plataforma y sustituir el código Dart de aplicación.

Consecuencias: no se regeneraron carpetas nativas. Los identificadores de plantilla se sustituyeron después; el valor actual está en D4.

## D3. La carpeta del cliente no se llama `mobile`

Estado: superada. Ver D18.

Contexto: los dos primeros `move` devolvieron que el directorio estaba en uso y movieron 0 directorios. No se copió el proyecto.

## D18. El cliente vive en `mobile/`

Estado: tomada.

Contexto: en un tercer intento, el 13 de octubre de 2026, ningún proceso tenía `flutter_application_1` en su línea de comandos. `adb` y dos procesos `node` seguían en ejecución y no se cerraron. `mobile/` no existía.

Decisión: `move flutter_application_1 mobile` movió 1 directorio. Se conservaron código, pruebas y proyectos de plataforma. No se cambió el paquete Dart ni los identificadores nativos.

Consecuencias: las instrucciones usan `mobile/`. `flutter_application_1/` ya no está en la raíz.

## D4. Identificador nativo `com.secureplan.mobile`

Estado: tomada e implementada en los archivos de proyecto. La compilación nativa no está verificada.

Contexto: Android usaba `com.example.flutter_application_1` como `applicationId`, `namespace` y paquete Kotlin. iOS usaba `com.example.flutterApplication1` en la aplicación y `com.example.flutterApplication1.RunnerTests` en las pruebas. La propuesta anterior de `edu.secureplan.mobile` no se adoptó.

Decisión: el identificador definitivo, pedido para esta tarea, es `com.secureplan.mobile`. El paquete Dart sigue siendo `secureplan_mobile` y el nombre visible sigue siendo SecurePlan. No se cambió `CFBundleName` ni el nombre interno de Windows `flutter_application_1`, porque no son el identificador de la aplicación. No había firmas ni servicios externos configurados que actualizar.

Consecuencias: una instalación anterior con el identificador de plantilla no se actualiza encima de esta. Android quedó en `applicationId`, `namespace` y `MainActivity.kt` bajo `com.secureplan.mobile`. iOS quedó en los seis `PRODUCT_BUNDLE_IDENTIFIER` de `project.pbxproj`, tres de la app y tres de `RunnerTests`. No se compiló un APK ni un proyecto iOS: esta máquina es Windows y no se ejecutó Gradle.

## D5. Riverpod como composición, sin más librerías de cliente

Estado: tomada.

Contexto: el enunciado fija Riverpod. Drift, almacenamiento seguro, router, avisos y conectividad tienen versiones vigentes compatibles con Dart 3.13, pero sus módulos no existen.

Decisión: instalar `flutter_riverpod` 3.4.3 al crear el cascarón. La autenticación añadió `flutter_secure_storage` 11.2.0 y `http` 1.6.0. Drift, el router, los avisos y la conectividad siguen sin instalarse.

Consecuencias: las pruebas de sesión sustituyen el almacén y el cliente HTTP. No abren el plugin nativo de almacenamiento seguro.

## D6. Navegación con go_router, todavía sin dependencia

Estado: tomada como elección, no instalada.

Alternativa: `Navigator` con rutas con nombre.

Decisión: `go_router` 18.0.2 cuando haya varios módulos. La sesión usa `AuthGate` y un `Navigator.push` hacia el registro. Esa puerta evita mostrar la agenda antes de resolver el token y no justifica el router todavía.

## D7. Cifrado local con sqlite3mc

Estado: implementada en el cliente y comprobada en el ejecutor de pruebas de Windows. No se comprobó en un emulador ni en un dispositivo Android.

Contexto: `sqlcipher_flutter_libs` 0.7.0+eol ya no cifra. La documentación actual de Drift pide `sqlite3` 3.x con el origen `sqlite3mc`.

Alternativa: `encrypted_drift` desde un repositorio Git, o posponer el cifrado. Posponerlo contradice el requisito.

Decisión: Drift 2.35.2, `sqlite3` 3.7.1 y `source: sqlite3mc`. Cada cuenta tiene su archivo `agenda-<userId>.sqlite` en el directorio privado de la aplicación y su propia clave de 32 bytes en `flutter_secure_storage`. La clave se pasa como `PRAGMA key = "x'<hex>'"` después de comprobar que `PRAGMA cipher` no está vacío. Una clave incorrecta no borra el archivo.

Consecuencias: la prueba de Flutter abre la base, escribe una fila, cierra el archivo, comprueba que el título no aparece en claro, falla con otra clave y vuelve a leerla con la clave original. Eso usa el binario de Windows del ejecutor de pruebas, no el `.so` de Android.

## D8. TypeScript 6.0.3 y Prisma 7.10.0

Estado: tomada.

Contexto: TypeScript `latest` era 7.0.2 y Prisma `latest` era 8.0.0-rc.22 el 13 de octubre de 2026.

Alternativas: seguir `latest`, o bajar a Prisma 6.

Decisión: TypeScript 6.0.3 porque typescript-eslint 8.71.2 admite hasta `<6.1.0` y ts-jest 29.4.14 admite `<7`. Prisma 7.10.0 porque es la estable; la 8 sigue en candidata. El archivo de configuración es `prisma7.config.ts`, que es el nombre que Prisma 7.10 busca primero.

Consecuencias: `npm audit fix --force` no se puede aceptar: propone Prisma 6.19.3. Los avisos de `mysql2` y `deepmerge-ts` quedan registrados en `Development.md`.

## D9. API en ESM

Estado: tomada.

Contexto: el cliente generado por Prisma 7 usa ESM.

Decisión: `"type": "module"` y Express 5.3.0. Además de `GET /health`, la API expone el registro, el inicio, el cierre y la comprobación de sesión bajo `/api/auth`. Jest corre con módulos VM experimentales.

Consecuencias: los imports relativos de TypeScript llevan sufijo `.js`. El aviso experimental de Node apareció durante `npm test` y las pruebas pasaron.

## D10. Singleton de Prisma perezoso

Estado: tomada e implementada en el límite descrito.

Decisión: `getPrismaClient()` crea un único `PrismaClient` con `PrismaPg` la primera vez que se llama, y solo si hay `DATABASE_URL`. `PrismaUserRepository` lo usa en el primer registro o inicio, no al importar el módulo.

Consecuencias: sin `DATABASE_URL` o sin `JWT_SECRET`, `createApp()` responde `503` en `/api/auth` y `GET /health` sigue disponible. En `NODE_ENV=production` el proceso termina si falta uno de los dos. La prueba cubre la ausencia de URL, no una consulta. No hay que presentar este singleton como una conexión comprobada.

## D11. Strategy y Observer

Estado: implementados en el flujo real de la agenda.

Decisión: `EventExportStrategy` tiene dos estrategias, `JsonEventExporter` y `CsvEventExporter`. El archivo exporta las ocurrencias que la agenda tiene cargadas para el mes visible, no la cola de sincronización ni secretos. `AgendaChangeHub` avisa a `ReminderObserver` después de crear, editar, borrar o sincronizar. La pantalla sigue usando Riverpod y no programa notificaciones por su cuenta.

## D12. Sesión de acceso, sin refresh token

Estado: tomada e implementada. La revocación en servidor queda descartada en esta versión.

Contexto: la propuesta anterior era un access token de 15 minutos más un refresh de 30 días con rotación y revocación. Añadir esa tabla ahora, sin PostgreSQL disponible para probarla, introducía un mecanismo que no se podía verificar.

Decisión: un JWT bearer de 15 minutos, firmado con HS256 mediante `jose` 6.2.12. Los claims son `sub`, `iat` y `exp`. La contraseña se guarda con Argon2id mediante `argon2` 0.45.1. El cliente guarda solo el access token en `flutter_secure_storage`. `POST /api/auth/logout` exige el token y responde `204`, pero no lo invalida. El cierre real en el dispositivo es borrar el token. Hasta que expire, cualquiera que lo haya copiado puede seguir llamando a la API.

Alternativa rechazada: cookie de sesión. El cliente es nativo y el enunciado pide JWT.

Consecuencias: no hay denylist ni refresh token. Una sesión robada dura como máximo 15 minutos. Cambiar a revocación más adelante no invalida por sí sola los JWT ya emitidos.

## D13. Conflictos de sincronización

Estado: implementada.

Decisión: `Event.version` empieza en 1 y aumenta en cada cambio. `PATCH` y `DELETE` exigen `baseVersion`. Si no coincide, el servidor responde `409` con `code` `CONFLICT` y el evento vigente en `server`. No se sobrescribe en silencio. El cliente conserva su copia, la marca como conflicto y ofrece «Usar servidor» o «Usar mi versión». Si el servidor ya borró el identificador, conservar la copia local crea un identificador nuevo para no resucitar la lápida.

Alternativa rechazada: el último `updatedAt` gana, sin avisar.

## D22. Cola local e identificador de cliente

Estado: implementada.

Decisión: el teléfono guarda la operación pendiente en `outbox_items` y envía el UUID local en `POST /api/events`. La primera petición responde `201`. Una repetición del mismo usuario e identificador responde `200` y no crea otra fila. `EventTombstone` impide que un alta retrasada restaure un evento borrado. Un fallo de red se reintenta hasta 5 veces. Un `400` queda como fallo permanente. Un `401` detiene el envío sin marcar la operación como sincronizada. La cola de una cuenta no se envía con el token de otra.

## D14. Git

Estado: pendiente.

`git` 2.47.1 está instalado y `WEB-10` no es un repositorio. No se ejecutó `git init` en esta tarea. Cuando exista el repositorio, el trabajo irá por ramas y Pull Requests, sin push directo a `main`.

## D15. Skills de agente en el repositorio de trabajo

Estado: tomada.

Contexto: el proyecto debe usar las skills de `addyosmani/agent-skills` durante el desarrollo.

Decisión: `npx skills add addyosmani/agent-skills` instaló 25 skills en `.agents/skills/`. El inventario local es `skills-lock.json`. No hay una skill específica de Flutter ni de Prisma en ese conjunto.

Consecuencias: antes de cada tarea se leen las skills cuyo flujo corresponda. No se reinstalan si el directorio y el lock siguen presentes.

## D16. Cabeceras sin una dependencia nueva

Estado: tomada.

Contexto: la skill de seguridad pide cabeceras en cada respuesta y menciona `helmet`.

Alternativa: añadir `helmet`.

Decisión: un middleware propio con cuatro cabeceras. No se añade un paquete para eso. No se envía HSTS desde la aplicación.

Consecuencias: el comportamiento queda cubierto por la prueba de `/health` y por la de la ruta inexistente.

## D17. No inicializar Git en esta consolidación

Estado: tomada, a la espera de un repositorio.

Contexto: la skill de Git pide un commit por cada cambio. El proyecto todavía no es un repositorio y la tarea no pidió crear uno ni hacer commit.

Decisión: no ejecutar `git init` ni `git commit`. La prohibición de push directo a `main` sigue vigente para cuando el remoto exista.

## D19. Evento simple, sin recurrencia ni borrado lógico

Estado: tomada e implementada. La migración está aplicada en la base local de desarrollo.

Contexto: `Database.md` preveía un UUID creado por el cliente, `version`, `deletedAt` y `recurrenceId` para sincronizar y repetir. Esta tarea pide el CRUD y el calendario, y deja fuera la sincronización y la recurrencia.

Decisión: el servidor genera el UUID. `endsAt` es opcional y posterior al inicio. La categoría es un conjunto fijo (`personal`, `trabajo`, `estudio`, `otro`) y la prioridad es `low`, `medium` o `high`. Las fechas viajan en ISO-8601 con zona y se muestran en la zona del teléfono. El borrado es físico. No se añadió una dependencia de calendario.

Alternativa rechazada: guardar ya las columnas de sincronización sin código que las use. Se pueden añadir después sin cambiar las columnas actuales.

Consecuencias: repetir un `POST` crea otro evento. Un borrado no se puede sincronizar más tarde como baja lógica si la fila ya no existe. La recurrencia posterior no cambió este borrado físico; vive en D21.

## D21. Serie recurrente con excepciones, calculada en un desfase fijo

Estado: tomada e implementada. La migración `20261014023000_event_recurrence` está aplicada en `secureplan_dev`.

Contexto: hacía falta repetir eventos sin guardar cada fecha futura y sin que el teléfono calcule una serie distinta de la API.

Decisión: una fila `Event` guarda la regla. `EventException` guarda una ocurrencia movida o excluida, identificada por el inicio original. La repetición usa el desfase en minutos del inicio y no una zona IANA, así que no sigue el horario de verano. Un mes sin el día elegido se omite. La serie dura como máximo 366 días y exige `count` o `until`, nunca ambos ni ninguno. El calendario pide el mes visible; el servidor expande solo ese rango.

Alternativa rechazada: materializar todas las fechas en PostgreSQL. También se rechazó calcular la serie en Flutter, porque backend y calendario podían divergir.

Consecuencias: editar o borrar una serie pide una elección explícita. Editar toda la serie borra las excepciones. Un evento único conserva el contrato anterior cuando no envía `scope` ni `recurrence`.

## Confirmaciones que desbloquean trabajo

1. Identificador de aplicación. Resuelto: `com.secureplan.mobile` en los archivos de Android e iOS. Falta compilar ambos destinos.
2. Sesión. Resuelto para esta versión: access token de 15 minutos, sin refresh ni revocación en servidor. Ver D12.
3. Política de conflicto por versión.
4. Categorías. Resuelto para esta versión: conjunto fijo `personal`, `trabajo`, `estudio`, `otro`. Una tabla propia del usuario sigue pendiente.
5. Cómo se edita una sola ocurrencia de un evento repetido.
6. Si Windows sigue siendo destino de desarrollo o solo una herencia de la plantilla.
7. Dónde corre PostgreSQL. Resuelto para desarrollo: contenedor `secureplan-postgres` en el puerto 5434 y base `secureplan_dev`. El servicio PostgreSQL 18 de Windows no se modificó. Ver D20.

## D20. PostgreSQL de desarrollo en un contenedor propio

Estado: tomada y aplicada.

Contexto: el servicio PostgreSQL 18 de Windows escucha en el puerto 5432, pero no hay contraseña disponible para este proyecto. El puerto 5433 ya lo usa un contenedor de otro proyecto.

Decisión: crear solo el contenedor `secureplan-postgres`, con la imagen `postgres:16-alpine`, la base `secureplan_dev` y el puerto del host 5434. La contraseña y `JWT_SECRET` viven en `backend/.env`. No se cambia la contraseña del servicio de Windows ni se borra otra base.

Consecuencias: hay que arrancar Docker Desktop y `docker compose up -d` antes de la API. Las pruebas habituales siguen usando repositorios en memoria. La persistencia real se ejecuta con `RUN_DB_INTEGRATION=1`.
