# API

La API ofrece el estado del proceso, la sesión y los eventos del usuario autenticado.

## Base

- Transporte HTTP y cuerpos JSON con `Content-Type: application/json; charset=utf-8`.
- La sesión vive en `/api/auth` y los eventos en `/api/events`. El prefijo previsto `/api/v1` no está montado. `GET /api/v1/events` sigue respondiendo `404`.
- El proceso escucha `PORT` o `3000`.
- No hay CORS.
- Las rutas protegidas exigen `Authorization: Bearer` con el access token.
- Toda respuesta pasa por `securityHeaders`: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer` y `Content-Security-Policy: default-src 'none'`. No se envía `Strict-Transport-Security`.

## Endpoint existente

`GET /health`

Respuesta `200`:

```json
{
  "status": "ok",
  "service": "secureplan-api"
}
```

No requiere sesión ni base de datos. No indica que PostgreSQL esté conectado. Comprobado el 13 de octubre de 2026 contra `node dist/server.js` en el puerto 3099.

`GET /api/v1/events`, y cualquier otra ruta no declarada, responde `404`:

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Route not found"
  }
}
```

Eso no es un recurso de eventos. Es la prueba de que la ruta no existe.

## Sesión

Si faltan el repositorio de usuarios o un `JWT_SECRET` de al menos 32 caracteres, cualquier ruta bajo `/api/auth` responde `503` con `SERVICE_UNAVAILABLE`. `GET /health` no depende de eso.

Los cuerpos rechazan campos desconocidos. El correo se recorta, se pasa a minúsculas y debe ser un email de hasta 254 caracteres. La contraseña de registro tiene de 10 a 128 caracteres, una letra, un dígito y no puede coincidir con el correo. La de inicio solo exige de 1 a 128 caracteres, porque la política ya se aplicó al registrarla.

`POST /api/auth/register` responde `201`. `POST /api/auth/login` responde `200`. Las dos devuelven:

```json
{
  "user": { "id": "uuid", "email": "ana@example.com" },
  "accessToken": "jwt",
  "expiresAt": "2026-10-13T12:15:00.000Z"
}
```

`expiresAt` es el instante de caducidad, 15 minutos después de la emisión. El cuerpo no incluye `passwordHash`.

`POST /api/auth/logout` exige el bearer y responde `204` sin cuerpo. El token sigue siendo válido hasta `exp`. Comprobado en prueba: después del `204`, `GET /api/auth/session` sigue respondiendo `200`.

`GET /api/auth/session` exige el bearer y responde `200`:

```json
{ "userId": "uuid" }
```

| Situación | HTTP | `code` | Mensaje |
| --- | --- | --- | --- |
| Correo o contraseña de registro inválidos | 400 | `VALIDATION_ERROR` | Texto fijo. No repite la contraseña |
| Credenciales incorrectas o usuario ausente | 401 | `INVALID_CREDENTIALS` | `Correo o contraseña incorrectos` |
| Token ausente, malformado o caducado | 401 | `UNAUTHENTICATED` | `Autenticación requerida` |
| Correo ya registrado | 409 | `CONFLICT` | `No se pudo completar el registro` |
| Demasiados intentos | 429 | `TOO_MANY_REQUESTS` | `Demasiados intentos. Espera antes de reintentar.` |
| Fallo inesperado de datos | 500 | `INTERNAL_ERROR` | Mensaje genérico. No incluye el error de la base |
| Sesión sin configurar | 503 | `SERVICE_UNAVAILABLE` | `La autenticación no está disponible` |

El límite es de 10 peticiones de registro o inicio por IP durante 15 minutos, en la memoria del proceso. `logout` y `session` no cuentan para ese límite.

## Eventos

Todas las rutas exigen `Authorization: Bearer`. Si no hay repositorio de eventos o el secreto no alcanza 32 caracteres, `/api/events` responde `503` con `La agenda no está disponible`.

El cuerpo no acepta `userId`, `createdAt` ni `updatedAt`. `POST` puede incluir `id` si es un UUID creado por el cliente. El dueño sale del token. Un campo desconocido responde `400`.

Categorías: `personal`, `trabajo`, `estudio`, `otro`. Prioridades: `low`, `medium`, `high`. El título tiene de 1 a 200 caracteres. La descripción, si viene, tiene como máximo 4000. Las fechas son ISO-8601 con zona horaria. `endsAt` es opcional y, si está, debe ser posterior a `startsAt`.

`GET /api/events` sin rango responde `200` con las definiciones guardadas, una por evento o serie. Con `from` y `to` en ISO-8601 responde las ocurrencias que se solapan con ese intervalo, cerrado al inicio y abierto al final. El intervalo no puede superar 62 días ni devolver más de 500 ocurrencias. El calendario pide el mes visible, con un día de margen.

```json
{ "events": [] }
```

La lista contiene solo eventos del sujeto del token. No está paginada.

`GET /api/events/sync` responde las definiciones, las excepciones y las lápidas del usuario. No expande ocurrencias y no incluye secretos.

`POST /api/events` responde `201` la primera vez. Si el mismo usuario repite el mismo `id`, responde `200` con el evento ya guardado y no crea otra fila. Si ese `id` está en `EventTombstone`, responde `409`. Un evento único omite `recurrence`. Una serie envía `recurrence` con `frequency` (`daily`, `weekly` o `monthly`), `interval` de 1 a 99, `offsetMinutes` de -840 a 840 y exactamente uno de `count` (1 a 366) o `until`. `weekly` exige `weekdays`, de 0 (domingo) a 6 (sábado), e incluye el día civil del inicio. La serie no puede extenderse más de 366 días.

`GET /api/events/:id` responde la definición. Con `occurrenceStart` responde esa ocurrencia. `PATCH` y `DELETE` exigen `baseVersion`. Si no coincide con `version`, responden `409` con el evento vigente en `server` y no modifican la fila. `PATCH` de un evento único mantiene el resto del cuerpo anterior. En una serie, `scope` es obligatorio: `occurrence` cambia solo esa fecha y exige `occurrenceStart`; `series` cambia la definición y descarta las excepciones anteriores. `DELETE` de un evento único borra la fila. En una serie, `scope=occurrence` excluye esa fecha y `scope=series` borra la serie. Omitir `scope` en una serie responde `400`. No hay borrado lógico de eventos únicos.

Ejemplo de evento:

```json
{
  "id": "uuid",
  "title": "Revisión del proyecto",
  "description": "Preparar la demostración",
  "startsAt": "2026-10-13T15:00:00.000Z",
  "endsAt": "2026-10-13T16:00:00.000Z",
  "category": "estudio",
  "priority": "high",
  "createdAt": "2026-10-13T12:00:00.000Z",
  "updatedAt": "2026-10-13T12:00:00.000Z",
  "occurrenceStart": "2026-10-13T15:00:00.000Z",
  "version": 1,
  "reminderMinutes": 15,
  "recurrence": null
}
```

La respuesta no incluye `userId`. Si el evento no existe o pertenece a otra persona, la lectura, la modificación y el borrado responden `404` con `Evento no encontrado` y el mismo cuerpo. Un identificador que no es UUID responde `400`.

| Situación | HTTP | `code` |
| --- | --- | --- |
| Datos de evento inválidos | 400 | `VALIDATION_ERROR` |
| Sin token o token inválido | 401 | `UNAUTHENTICATED` |
| Evento ausente o de otro usuario | 404 | `NOT_FOUND` |
| Agenda sin configurar | 503 | `SERVICE_UNAVAILABLE` |

## Sobre de error

Los errores previstos usan siempre:

```json
{
  "error": {
    "code": "CODIGO_ESTABLE",
    "message": "Texto seguro para mostrar"
  }
}
```

| Situación | HTTP | `code` | Estado |
| --- | --- | --- | --- |
| Ruta inexistente | 404 | `NOT_FOUND` | Implementado |
| Error no controlado | 500 | `INTERNAL_ERROR` | Implementado. El cuerpo no incluye el error interno |
| Entrada inválida | 400 | `VALIDATION_ERROR` | Implementado en sesión y eventos |
| Sin sesión o sesión inválida | 401 | `UNAUTHENTICATED` | Implementado en `requireAuth` |
| Credenciales incorrectas | 401 | `INVALID_CREDENTIALS` | Implementado. El mismo cuerpo si el correo no existe |
| Sesión válida sin ser el dueño | 404 | `NOT_FOUND` | Implementado en eventos. No se usa `403`, para no revelar que el recurso existe |
| Conflicto de versión o alta de un identificador ya borrado | 409 | `CONFLICT` | Implementado. El cuerpo añade `server` cuando el evento todavía existe |

El `500` comprobado en prueba unitaria no devuelve el mensaje de la excepción. Un fallo inesperado no se registra con su contenido: la consola recibe únicamente `Unhandled error`.

## Validación

Zod 4.6.7 valida el entorno, los cuerpos de sesión y los cuerpos de eventos. Un campo desconocido se rechaza.

## Autorización prevista

Para cualquier recurso de un usuario:

1. Verificar el access token.
2. Tomar el `userId` del token.
3. Leer o modificar solo filas de ese `userId`.
4. Si el identificador no existe o es de otra persona, responder como si no existiera (`404`) para no revelar recursos ajenos. `403` queda reservado a una acción prohibida sobre un recurso que el usuario sí puede saber que existe.

`requireAuth` protege la sesión y todas las rutas de `/api/events`. El servicio solo consulta y modifica filas cuyo `userId` es el sujeto del token.

## Recursos previstos y ausentes

No implementar estos caminos como si ya existieran:

| Método y ruta | Uso previsto |
| --- | --- |
La exportación JSON y CSV es una función del cliente sobre las ocurrencias cargadas en el mes visible. No requiere un endpoint. El archivo no incluye tokens, claves ni el estado interno de la cola.

## Idempotencia

El `id` opcional de `POST /api/events` es la clave. La primera respuesta es `201`. La repetición del mismo usuario es `200`. Una lápida responde `409` y no restaura el evento.
