# Seguridad

Estas reglas valen para todo el desarrollo posterior. Lo que hoy está construido es solo la parte marcada como control actual.

## Reglas obligatorias

- No guardar contraseñas en texto plano. El servidor debe almacenar el resultado de Argon2id.
- No poner secretos, tokens reales, contraseñas ni claves privadas en el repositorio, en capturas ni en pruebas compartidas.
- Las credenciales del backend viven en el entorno. `.env.example` solo tiene marcadores.
- Validar en el servidor aunque el cliente ya haya validado.
- Autorizar cada recurso privado por su propietario. Un identificador enviado por el cliente no demuestra que ese cliente pueda usarlo.
- No devolver al cliente excepciones internas, SQL ni stack traces.
- Guardar tokens de sesión en almacenamiento seguro de la plataforma, no en preferencias sin cifrar.
- Cifrar la base SQLite. El archivo de SQLite, por sí solo, no cumple ese requisito.
- No registrar contraseñas, tokens, cabeceras `Authorization` ni cuerpos de autenticación.
- Separar la configuración por entorno.
- Usar el cliente de Prisma o consultas parametrizadas. No concatenar SQL.
- La expiración de esta versión es de 15 minutos y no hay renovación ni revocación en servidor. Está registrada en D12.

## Amenazas y medidas previstas

| Amenaza | Medida prevista | Estado |
| --- | --- | --- |
| Filtración de secretos en Git | `.gitignore` de raíz, cliente y API; ejemplo sin secretos reales | Control actual |
| Exceso de información en errores | El manejador responde `INTERNAL_ERROR` / `Unexpected error` y escribe en consola solo el texto fijo `Unhandled error` | Control actual. Todavía no hay un registrador que conserve el diagnóstico sin datos sensibles |
| Identificación del framework | `x-powered-by` desactivado. Comprobado en `/health` | Control actual |
| Cabeceras de respuesta | `nosniff`, `DENY`, `no-referrer` y `Content-Security-Policy: default-src 'none'` en todas las respuestas. Sin `helmet` y sin HSTS | Control actual, cubierto por `tests/http.test.ts` |
| Cuerpo JSON grande | Límite de `1mb` en `express.json` | Control actual |
| Contraseñas débiles o en claro | Argon2id, política de 10 a 128 caracteres con letra y dígito, y respuestas que no revelan si el correo existe | Implementado. El hash guardado en PostgreSQL empieza por `$argon2id$` y no sale en la respuesta |
| Robo de token en el dispositivo | `flutter_secure_storage` 11.2.0, clave `secureplan.access_token` | Implementado. Las pruebas usan un almacén en memoria |
| Fuerza bruta de la sesión | 10 intentos de registro o inicio por IP cada 15 minutos, en memoria y en un solo proceso | Implementado. No se comparte entre procesos y se pierde al reiniciar |
| Agenda local legible | Drift 2.35.2 con `sqlite3` 3.7.1 y el origen `sqlite3mc`. No se usa `sqlcipher_flutter_libs` | Comprobado en la prueba de Flutter sobre Windows. El APK Android no se ejecutó |
| IDOR sobre eventos | Cada consulta filtra por el sujeto del JWT. Un evento ajeno responde `404` con el mismo cuerpo que uno inexistente. El cuerpo no puede fijar `userId` | Implementado. Cubierto en memoria y contra PostgreSQL |
| Inyección | Zod en el entorno y en los cuerpos. Prisma parametriza usuarios y eventos | Implementado en sesión y agenda |
| Repetición de una sincronización | Clave de idempotencia por operación | Pendiente. Ver `Sync.md` |
| Sesión robada | Access token de 15 minutos. No hay refresh ni revocación | Implementado con esa limitación. Borrar el token del teléfono no invalida una copia |
| CORS abierto | No hay CORS. El cliente móvil nativo no lo necesita. Si más adelante hay web, la lista de orígenes será explícita | Control actual por ausencia de destino web |
| Dependencias vulnerables | `npm audit` registró 24 avisos. No se cambió ninguna dependencia en esta consolidación | Aplazado hasta el 13 de enero de 2027. Ver el detalle de abajo |

## Autenticación implementada

El registro, el inicio y el cierre están en el código y persisten en PostgreSQL cuando `DATABASE_URL` y `JWT_SECRET` están configurados.

- Argon2id con `argon2` 0.45.1: `memoryCost` 19456, `timeCost` 2 y `parallelism` 1. El hash empieza por `$argon2id$`.
- La contraseña tiene entre 10 y 128 caracteres, al menos una letra y un dígito, y no puede ser igual al correo.
- El correo se recorta y se pasa a minúsculas. La unicidad también está en el índice `User_email_key`.
- Un correo duplicado responde `409` con `No se pudo completar el registro`. No dice que el correo exista.
- Un inicio fallido responde `401` con `Correo o contraseña incorrectos`, tanto si el correo no existe como si la contraseña no coincide. Si el correo no existe, la verificación usa un hash ficticio para no acortar el intento.
- El JWT usa `jose`, algoritmo explícito `HS256`, y solo lleva `sub`, `iat` y `exp`. Dura 15 minutos. `jwtVerify` rechaza otro algoritmo y un token caducado.
- `JWT_SECRET` es obligatorio para firmar, con al menos 32 caracteres. No hay valor por defecto en el código. Un secreto corto detiene `loadEnv` con `Invalid environment configuration`, sin imprimir el secreto.
- El middleware `requireAuth` toma el sujeto del token. No acepta un identificador enviado por el cliente.
- El cierre de sesión del teléfono borra el token. El servidor no lo revoca.
- Ni los registros ni las respuestas incluyen contraseñas, hashes ni tokens. El `500` sigue siendo genérico.
- El cliente no guarda la contraseña para reutilizarla. La comprobación local de `exp` no verifica la firma.

No hay refresh token. La cookie de sesión sigue descartada porque el cliente es nativo.

## Autorización de eventos

El cliente no es la frontera de seguridad. `requireAuth` verifica el JWT y deja el sujeto en `res.locals.userId`. Crear un evento ignora cualquier dueño enviado en el cuerpo: el esquema es estricto y rechaza `userId`. Listar, leer, modificar y borrar usan ese sujeto en el filtro. Si la fila no existe o es de otra persona, la respuesta es `404` y no incluye el título. Las pruebas en memoria cubren a dos usuarios. La prueba de PostgreSQL repitió la lectura, la edición y el borrado ajenos: los tres respondieron `404` y no devolvieron el título.

## Datos locales

La clave de la base local es aleatoria, de 32 bytes, y se guarda en el almacenamiento seguro con el identificador del usuario. No sale de la contraseña de la cuenta, así que cambiar esa contraseña no impide abrir la agenda. Cada cuenta usa su archivo y su clave. Cerrar sesión no borra la base de otra cuenta ni sus operaciones pendientes. Un campo CSV que empieza por `=`, `+`, `-`, `@` o un salto se precede con un apóstrofo para que una hoja de cálculo no lo interprete como fórmula.

## Configuración por entorno

`NODE_ENV` admite `development`, `test` y `production`. `PORT` debe estar entre 1 y 65535. Un valor inválido detiene el arranque con el mensaje genérico `Invalid environment configuration`, sin volcar el contenido de las variables.

`API_BASE_URL` del cliente es un `dart-define` con defecto `http://localhost:3000`.

## Controles que no se copiaron de la skill de seguridad

La skill `security-and-hardening` pide cookies `httpOnly` para la sesión y cabeceras mediante `helmet`. No se siguieron esas dos recomendaciones:

- La sesión es un JWT en `flutter_secure_storage`, porque el cliente es una aplicación nativa. Una cookie no viaja sola en ese cliente. La decisión está en D12.
- Las cuatro cabeceras se fijan en `securityHeaders` sin añadir una dependencia. `Strict-Transport-Security` no se envía: en HTTP local haría que el navegador recuerde HTTPS para `localhost`.
- El límite de intentos sí se añadió: la tarea lo pidió de forma explícita. Es un contador en memoria, 10 por 15 minutos y por IP, solo en el proceso actual.

## Aplazamiento del audit

Revisión prevista: 13 de enero de 2027. No se ejecutó `npm audit fix --force`.

| Paquete | Alcance | Motivo del aplazamiento |
| --- | --- | --- |
| `mysql2` | Dependencia de la CLI de Prisma. La API usa `pg` | Corregirlo a la fuerza instala Prisma 6.19.3 |
| `deepmerge-ts` | Dependencia de `@prisma/config`, no de los manejadores HTTP | El mismo cambio de Prisma |
| Cadena moderada de Jest | Solo pruebas | No está en el arranque de la API |

`npm audit signatures` no pudo comprobar las firmas. Falló al pedir `https://tuf-repo-cdn.sigstore.dev/11.root.json` con `SELF_SIGNED_CERT_IN_CHAIN`. No se desactivó la verificación TLS para esquivar ese error. Las firmas del registro quedan sin comprobar.
