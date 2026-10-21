# Arquitectura

Fecha de esta base: 13 de octubre de 2026.

## Estado

Implementado:

- Monorepositorio con el cliente Flutter, la API Node.js y `docs/`.
- Identificador nativo `com.secureplan.mobile` en los archivos de Android e iOS.
- Cliente con tema, Riverpod, pantallas de registro e inicio, puerta de sesión, agenda y calendario.
- API con `GET /health`, sesión y CRUD de eventos en `/api/events`.
- Recurrencia diaria, semanal y mensual. La serie se guarda una vez y las ocurrencias se calculan al consultar un rango.
- Modelos Prisma `User`, `Event`, `EventException` y `EventTombstone`. Las migraciones están aplicadas en la base local `secureplan_dev`.
- API conectada a PostgreSQL de desarrollo mediante Docker, en `127.0.0.1:5434`.
- Base local cifrada, bandeja, conflictos, exportación y el observer de recordatorios.

No verificado:

- Instalación del APK en un emulador o teléfono. El paquete de depuración sí compiló.
- Compilación de iOS o Windows.
- El flujo visual del emulador contra la API.
- El cifrado y las notificaciones dentro de un APK. La prueba de cifrado corrió en el ejecutor de Windows.
- El plugin de almacenamiento seguro fuera de las pruebas, que usan un doble.

## Organización

```text
WEB-10/
  mobile/                   cliente Flutter
  backend/                  API REST
  docs/                     documentación técnica
  .agents/skills/           skills de agente
```

Son dos proyectos independientes dentro del mismo directorio. No hay workspaces de npm ni de Dart: cada uno instala y se prueba por su cuenta. Así un fallo de Flutter no bloquea la API y al revés.

## Cliente

El paquete Dart es `secureplan_mobile`. Flutter 3.47.6 y Dart 3.13.5.

| Carpeta | Responsabilidad ahora | Después |
| --- | --- | --- |
| `lib/app/` | `MaterialApp`, tema y pantalla inicial | Seguir siendo la composición raíz |
| `lib/core/config/` | Nombre y URL base por `API_BASE_URL` | Entornos de compilación |
| `lib/core/di/` | `appNameProvider` bajo `ProviderScope` | Repositorios y casos de uso |
| `lib/core/theme/` | Tema claro Material 3 | Tokens compartidos con las pantallas |
| `lib/presentation/shell/` | Cascarón con cierre de sesión y la agenda | Navegación entre módulos |
| `lib/shared/widgets/` | Vacío, error con reintento y carga | Usarlos en cada módulo |
| `lib/domain/` | Vacía | Entidades compartidas sin Flutter ni SQL |
| `lib/data/` | Vacía | Drift y la bandeja de salida |
| `lib/features/auth/` | Política de contraseña, token, HTTP, Riverpod y pantallas | Sigue siendo el módulo de sesión |
| `lib/features/agenda/` | Reglas, HTTP, estado y calendario de eventos | Recurrencia, cuando exista |

La presentación de autenticación llama al controlador. El controlador llama a `AuthApi` y a `TokenStore`. La regla de contraseña y la lectura de `exp` viven en `features/auth/domain` y no importan widgets. Riverpod construye el almacén seguro y el cliente HTTP. Las pruebas sustituyen ambos.

`go_router` sigue sin instalarse. `AuthGate` distingue la carga inicial, la persona sin sesión y la agenda vacía. El registro se abre con `Navigator.push`.

## Servidor

Node.js 22.14.0, TypeScript 6.0.3, Express 5.3.0, módulos ES.

| Carpeta | Responsabilidad ahora |
| --- | --- |
| `src/server.ts` | Carga entorno y abre el puerto. En producción termina si faltan `JWT_SECRET` o `DATABASE_URL`. |
| `src/app.ts` | Construye Express, desactiva `x-powered-by`, monta `/health` y `/api/auth`. |
| `src/config/` | Valida `NODE_ENV`, `PORT`, `DATABASE_URL` y `JWT_SECRET` con Zod. |
| `src/errors/` | `AppError` y un manejador que no envía stack al cliente. |
| `src/middleware/` | Cabeceras, 404, límite de intentos y `requireAuth`. |
| `src/auth/` | Contraseñas, JWT, repositorio y rutas de sesión. |
| `src/events/` | Validación, autorización por dueño y CRUD de eventos. |
| `src/data/prisma-client.ts` | Singleton perezoso de Prisma 7.10.0 con el adaptador `pg`. |
| `prisma/schema.prisma` | Modelos `User` y `Event`. Las migraciones existen y no se han aplicado. |

Una petición futura debe recorrer ruta, esquema Zod, controlador, servicio y Prisma. El controlador no construye consultas. El servicio no conoce `Request` ni `Response`.

## Límites entre cliente y servidor

- La API es la autoridad de los datos compartidos. La base local es la autoridad mientras no hay red, y luego se reconcilia.
- El cliente puede validar para mejorar la interfaz. El servidor vuelve a validar.
- El identificador de usuario que viaje en el cuerpo no autoriza la operación. La autorización sale de la sesión verificada en el servidor.
- PostgreSQL no es accesible desde el teléfono. Solo la API lo usa.
- Los tokens no se guardan en `SharedPreferences` ni en el código fuente.

## Flujo de autenticación

1. Al arrancar, `AuthGate` permanece en carga hasta leer el almacenamiento seguro.
2. Si no hay token, o si `exp` ya pasó o el token no se puede leer, se borra y se muestra el inicio de sesión. Esa lectura local no comprueba la firma: la clave no está en la aplicación.
3. Si el token parece vigente, el cliente llama a `GET /api/auth/session`. Un `401` borra el token. Si no hay red, se conserva y se abre el cascarón. Eso no demuestra que el servidor lo acepte; la siguiente llamada autenticada puede fallar.
4. El registro y el inicio validan en el formulario y otra vez en el servidor. El servidor guarda Argon2id, emite el JWT y nunca devuelve el hash.
5. El cierre borra el token del dispositivo. El endpoint `POST /api/auth/logout` responde `204` y no revoca el JWT.

El cascarón autenticado muestra el calendario. Los eventos se leen y escriben en la API. No hay copia local ni sincronización.

## Agenda

`AgendaController` pide la lista al iniciar sesión y actualiza el estado después de crear, editar o borrar. `SelectedDay` guarda el día visible. El calendario y el formulario no deciden el propietario: el cliente HTTP envía el JWT y el servidor filtra por el sujeto del token. Un `401` cierra la sesión local una sola vez, sin reintentar la petición.

## Flujo de datos previsto

1. La interfaz pide un caso de uso.
2. El caso de uso lee o escribe la base local cifrada y registra la operación en una bandeja de salida.
3. Si hay sesión y red, un sincronizador envía esa operación a la API.
4. La API valida, autoriza por propietario y persiste en PostgreSQL.
5. Si la versión no coincide, la API responde conflicto y el cliente muestra las dos versiones.

Ese flujo de sincronización no está implementado. La interfaz autenticada muestra el calendario y guarda los eventos en la API. No hay base local ni bandeja de salida.

## Patrones pedidos

| Patrón | Estado |
| --- | --- |
| Singleton | Implementado solo como `getPrismaClient()`. No se ha ejecutado ninguna consulta. |
| Strategy | Implementado. `JsonEventExporter` y `CsvEventExporter` comparten `EventExportStrategy`. |
| Observer | Implementado. `AgendaChangeHub` avisa a `ReminderObserver` cuando cambia la agenda local. Riverpod sigue pintando la pantalla. |
| SOLID | La separación anterior es la regla de construcción. No hay casos de uso que demostrar todavía. |
