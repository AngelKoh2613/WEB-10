# Base de datos

El esquema declara `User` y `Event`. `npx prisma validate` termina bien. El 13 de octubre de 2026 se aplicaron, con `prisma migrate deploy`, las migraciones `20261013184500_create_users` y `20261014000000_create_events` sobre la base local `secureplan_dev`.

Drift y `sqlite3` no están en el `pubspec`. La copia local cifrada sigue sin existir.

## Servidor: PostgreSQL

La base de desarrollo es el contenedor `secureplan-postgres` (`postgres:16-alpine`), definido en `backend/docker-compose.yml`. Publica el puerto del host `5434` hacia el `5432` del contenedor. El usuario es `secureplan` y la base es `secureplan_dev`. El volumen se llama `secureplan_pg`.

No se usó el servicio PostgreSQL 18 de Windows, que escucha en `5432` y exige una contraseña que este proyecto no tiene. Tampoco se usó el puerto `5433`: lo ocupa un contenedor de otro proyecto. No se borró ninguna base existente.

`backend/.env` guarda la URL y el secreto de desarrollo. Está ignorado. `backend/.env.example` solo tiene marcadores. Una variable `DATABASE_URL` ya presente en el proceso tiene prioridad sobre `.env`, porque dotenv no la sustituye.

Prisma 7 no lee la URL desde el bloque `datasource`. Está en `backend/prisma7.config.ts`. El cliente de aplicación usa `@prisma/adapter-pg` y solo se construye dentro de `getPrismaClient()` si `DATABASE_URL` tiene valor. El arranque de la API no llama a esa función.

## Cliente: SQLite cifrado

La agenda offline usa Drift 2.35.2 sobre `sqlite3` 3.7.1, compilado con SQLite3MultipleCiphers:

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

`sqlcipher_flutter_libs` 0.7.0+eol no se usa: el paquete declara que ya no aporta el cifrado. La clave se aplica con `PRAGMA key` antes de cualquier consulta y vive en el almacenamiento seguro, no en el código ni en la base.

La prueba automatizada de Windows comprobó `PRAGMA cipher`, el rechazo de una clave incorrecta y que el título no queda en claro en el archivo. El binario de Android no se ejecutó en un emulador.

## Entidades preliminares

`User`, `Event`, `EventException` y `EventTombstone` ya están creadas en PostgreSQL. La bandeja local está en Drift.

### User

Cuenta del servidor. Está en `schema.prisma` y en la migración aplicada `20261013184500_create_users`.

- `id`: `String` con `@id @default(uuid())`.
- `email`: `String` `@unique`. El servidor lo normaliza a minúsculas antes de guardarlo. El índice `User_email_key` es la restricción real; una consulta previa no basta.
- `passwordHash`: `String` con el resultado de Argon2id. Nunca el texto plano.
- `createdAt`: `DateTime` `@default(now())`.
- `updatedAt`: `DateTime` `@updatedAt`.

No se guarda el nombre para mostrar. No hay tabla de refresh tokens: D12 descartó la revocación en servidor para esta versión.

### Event

Evento de un solo dueño. Está en `schema.prisma` y en la migración aplicada `20261014000000_create_events`. La copia SQLite todavía no existe.

- `id`: UUID. El servidor lo genera si el cliente no envía uno. Si lo envía, ese valor es la clave de idempotencia.
- `userId`: dueño, clave foránea a `User` con borrado en cascada. No se acepta en el cuerpo de la petición.
- `title`: texto de 1 a 200 caracteres, recortado.
- `description`: opcional, hasta 4000 caracteres. Una cadena vacía se guarda como nulo.
- `startsAt`: instante obligatorio. La API exige ISO-8601 con zona (`Z` o un desplazamiento). El servidor lo guarda como `TIMESTAMP(3)` en UTC. El teléfono lo muestra en la zona local del dispositivo.
- `endsAt`: opcional. Si viene, tiene que ser posterior a `startsAt`. En la base aplicada, `Event_interval_check` rechaza un fin que no sea posterior al inicio.
- `category`: `personal`, `trabajo`, `estudio` u `otro`.
- `priority`: `low`, `medium` o `high`.
- `createdAt` y `updatedAt`.

`version` empieza en 1. `reminderMinutes` admite nulo o uno de 5, 15, 60 y 1440; si el alta no lo envía, queda 15. El borrado de un evento único, o de una serie completa, sigue siendo físico y además escribe `EventTombstone` con el mismo `id`. Una ocurrencia excluida no borra la serie: queda una fila en `EventException`. La migración es `20261014043000_event_sync`.

La repetición no crea una fila por fecha. `recurrenceFrequency` es `daily`, `weekly` o `monthly`, o queda nula en un evento único. `recurrenceInterval` va de 1 a 99. `recurrenceOffsetMinutes` es el desfase fijo, en minutos, del instante de inicio; no sigue el horario de verano. `recurrenceWeekdays` guarda los días semanales de 0 (domingo) a 6 (sábado) en ese desfase. `recurrenceCount` y `recurrenceUntil` no se combinan. La serie no se extiende más de 366 días.

Un mes que no contiene el día civil del inicio se omite. El 31 no pasa al 30 ni al 1, y el 29 de febrero no pasa al 28 en un año no bisiesto. Esos meses no consumen una repetición del límite `count`.

`EventException` identifica la ocurrencia por `eventId` y `originalStart`. `excluded` verdadero la oculta. Si es falso, guarda el título, la descripción, el intervalo, la categoría y la prioridad de esa sola fecha. Editar toda la serie borra estas excepciones. La migración es `20261014023000_event_recurrence`.

El índice `Event_userId_startsAt_idx` ordena la agenda de cada persona. Las consultas de lectura, cambio y borrado filtran por `id` y `userId` a la vez.

### Recurrence

La regla no tiene tabla propia. Vive en las columnas `recurrence*` de `Event`, y cada excepción vive en `EventException`. Ver D21.

### Outbox local

Tabla Drift `outbox_items`, dentro de la base cifrada de esa cuenta.

- `id`: entero autogenerado.
- `userId`: cuenta dueña. Una sesión no lee ni envía filas de otra.
- `operation`: `create`, `update` o `delete`.
- `entityId`: UUID estable del evento.
- `payload`: JSON de la operación, sin token ni clave.
- `baseVersion`: versión que el cliente creía vigente. Nula en un alta que todavía no existe en el servidor.
- `attempts` y `status`: `pending`, `conflict` o `failed`.
- `createdAt` y `lastError`.

## Restricciones que ya se pueden fijar

- Un evento pertenece a un usuario.
- El título no puede ser vacío ni superar 200 caracteres. La descripción no supera 4000.
- `startsAt` es obligatorio. `endsAt`, si existe, es posterior.
- La categoría y la prioridad solo admiten los valores anteriores. La frecuencia admite `daily`, `weekly`, `monthly` o nulo.
- El borrado de usuario en el servidor elimina sus eventos. La clave `Event_userId_fkey` usa `ON DELETE CASCADE`.

## Qué queda pendiente en los datos

`User` y `Event` existen en `secureplan_dev`, con sus índices y las comprobaciones de categoría, prioridad e intervalo. No se deben aplicar estas migraciones contra una base que no sea la de desarrollo de SecurePlan.

Siguen abiertos, y no forman parte de esta migración:

- si una categoría es un enum o una tabla del usuario;
- la confirmación de `sqlite3mc` dentro de un APK Android. En Windows, la prueba de Flutter ya abrió la base cifrada.
