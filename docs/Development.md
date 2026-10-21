# Desarrollo

Las versiones y los resultados de abajo se comprobaron el 13 de octubre de 2026 en esta máquina. No describen un entorno genérico.

## Herramientas comprobadas

| Herramienta | Versión | Ubicación |
| --- | --- | --- |
| Flutter | 3.47.6 stable, revisión `5fc346839b` | `C:\dev\flutter` |
| Dart | 3.13.5 | incluido con Flutter |
| DevTools | 2.60.0 | incluido con Flutter |
| Node.js | 22.14.0 | `C:\Program Files\nodejs\node.exe` |
| npm | 10.9.2 | incluido con Node.js |
| Git | 2.47.1.windows.2 | `C:\Program Files\Git\cmd\git.exe` |
| Docker | 29.3.0 | motor en marcha; contenedor `secureplan-postgres` |
| Java del sistema | OpenJDK Temurin 21.0.6 | disponible |
| Java de Android Studio | OpenJDK 21.0.4 | reportado por `flutter doctor` |
| Android SDK | 35.0.1, plataforma android-36 | `C:\Users\unixc\AppData\Local\Android\sdk` |
| Visual Studio | Community 2022 17.12.4, Windows 10 SDK 10.0.22621.0 | disponible para el destino Windows |
| PostgreSQL | 16 en Docker; 18 como servicio de Windows | SecurePlan usa el contenedor en el puerto 5434 |
| Dispositivo Flutter | Windows de escritorio | detectado; la aplicación no se lanzó |

`flutter doctor`, en la preparación anterior de este mismo día, terminó con un aviso: las licencias de Android no están aceptadas (`flutter doctor --android-licenses`). Ese comando es interactivo y no se ejecutó. Por eso no se compiló un APK. Esta consolidación no volvió a lanzar el doctor ni un emulador.

El `minSdk` del cliente es `flutter.minSdkVersion`. En el SDK instalado, `packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt` lo define como 24. El manifiesto no declara permisos de notificación. Android 13 (API 33) exige el permiso de ejecución `POST_NOTIFICATIONS` para mostrar avisos; se añadirá con ese módulo, no antes. `flutter_secure_storage` sigue sin instalarse, así que el `minSdk` de ese paquete no se ha leído de su código.

El SDK de Flutter tiene el destino web desactivado (`no-enable-web`). iOS está en el proyecto, pero esta máquina Windows no puede compilarlo. El destino de desarrollo comprobado a nivel de pruebas es el arnés de widgets, no un emulador.

## Agent Skills

El 13 de octubre de 2026, desde la raíz, `npx skills add addyosmani/agent-skills` terminó con código 0 e instaló 25 skills en `.agents/skills/`. El inventario es `skills-lock.json`. No hace falta reinstalarlas mientras esos archivos existan.

No hay una skill de Flutter, Dart, Drift ni Prisma en ese conjunto. Las que aplican a este proyecto son las de arquitectura, API, seguridad, pruebas, revisión, Git y documentación. Sus instrucciones están en cada `SKILL.md`.

## Qué hay instalado en los proyectos

Cliente (`mobile/pubspec.yaml`):

- SDK Dart `^3.13.5`
- `flutter_riverpod` 3.4.3
- `flutter_secure_storage` 11.2.0
- `http` 1.6.0
- `flutter_lints` 6.0.0
- `flutter_test` del SDK

`flutter pub outdated` indicó que `material_color_utilities`, `meta` y `test_api` tienen versiones más nuevas incompatibles con las restricciones actuales. No se actualizaron.

No están instalados, a propósito: Drift, `sqlite3`, `go_router`, `flutter_local_notifications` y `connectivity_plus`. Sus versiones vigentes en pub.dev ese día eran Drift 2.35.2, `drift_flutter` 0.3.1, `sqlite3` 3.7.1, `go_router` 18.0.2, `flutter_local_notifications` 22.3.2 y `connectivity_plus` 7.3.2.

API (`backend/package.json`):

- Express 5.3.0, Zod 4.6.7, dotenv 18.0.7
- Prisma y `@prisma/client` 7.10.0, `@prisma/adapter-pg` 7.10.0, `pg` 8.23.1
- TypeScript 6.0.3, tsx 4.23.15, ESLint 10.12.0, typescript-eslint 8.71.2, Prettier 3.9.10
- Jest 30.5.2, ts-jest 29.4.14, Supertest 7.3.1
- `@types/node` 22.20.5, alineado con Node 22 y no con la línea 26
- `argon2` 0.45.1 y `jose` 6.2.12, fijados sin rango. `jose` firma y verifica el JWT. No se instaló `jsonwebtoken`

TypeScript 7.0.2 era la versión `latest`, pero typescript-eslint 8.71.2 exige TypeScript `<6.1.0` y ts-jest 29.4.14 exige `<7`. Se fijó 6.0.3, la última que cumplen ambos.

Prisma `latest` era `8.0.0-rc.22`. No se instaló la candidata. Se fijó la estable 7.10.0.

`JWT_SECRET` debe tener al menos 32 caracteres. El ejemplo de `.env.example` es un marcador, no una clave usable en producción. En `NODE_ENV=production` el proceso termina si faltan `JWT_SECRET` o `DATABASE_URL`. En desarrollo, sin esos valores, `/health` responde y `/api/auth` responde `503`.

## Configuración del entorno

Desde `backend/`:

```powershell
Copy-Item .env.example .env
```

`.env` está ignorado por la raíz y por `backend/.gitignore`. El ejemplo usa `replace-me` como contraseña ficticia. Hay que sustituirla en local y no commitearla. La API arranca sin `DATABASE_URL`, pero entonces `/api/auth` y `/api/events` responden `503`. Prisma CLI y `getPrismaClient()` necesitan la URL.

Para la base de este proyecto, desde `backend/`:

```powershell
docker compose up -d
npx prisma migrate deploy
npm run dev
```

`docker compose` lee `POSTGRES_PASSWORD` desde `.env`. El contenedor escucha en `127.0.0.1:5434`. No uses el puerto 5432 ni el 5433: el primero es el servicio de Windows y el segundo pertenece a otro contenedor. Si el volumen `secureplan_pg` ya existe, la contraseña de `.env` tiene que ser la del primer arranque. No ejecutes `prisma migrate reset` ni borres el volumen para cambiarla.

`android/local.properties` contiene rutas locales del SDK. Está en el `.gitignore` del cliente y no debe entrar al repositorio.

## Comandos

Cliente, desde `mobile/`:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
```

La URL de la API se fija al compilar. El valor por defecto es `http://localhost:3000` y no es una URL de producción.

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000
```

Ese `localhost` sirve para la API y para el cliente en el mismo ordenador. No sirve para el emulador de Android: ahí `localhost` es el propio emulador. Para hablar con el ordenador anfitrión:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

En un teléfono físico, `10.0.2.2` tampoco apunta al ordenador. Hay que usar la IP de la red local del equipo donde corre la API, por ejemplo `http://192.168.1.20:3000`, con el teléfono y el ordenador en la misma red. No se inventó una dirección de producción. El identificador de aplicación es `com.secureplan.mobile`.

API, desde `backend/`:

```powershell
npm install
npm run prisma:generate
npm run prisma:validate
npm test
npm run lint
npm run format:check
npm run build
npm run dev
```

`npm start` ejecuta `node dist/server.js` después de `npm run build`. `src/generated/` se regenera y está ignorado: sin `prisma:generate`, el módulo de Prisma no compila.

## Resultados de la comprobación

| Comando | Resultado |
| --- | --- |
| `flutter analyze` | Sin incidencias. |
| `flutter test` | 4 pruebas superadas. |
| `dart format lib test` | Formateó 2 archivos; el árbol quedó formateado. |
| `npx prisma generate` y `npx prisma validate` | Cliente 7.10.0 generado y esquema válido. No abrió una base de datos. |
| `npm test` | 8 pruebas superadas, después de corregir el import de Jest en ESM. |
| `npm run lint` | Sin incidencias, después de ignorar argumentos que empiezan por `_`. |
| `npm run format:check` | Conforme. |
| `npm run build` | `tsc` terminó sin errores. |
| `node dist/server.js` con `PORT=3099` y sin `DATABASE_URL` | Escuchó e imprimió `SecurePlan API listening on port 3099`. |
| `curl` a `/health` | `200` y `{"status":"ok","service":"secureplan-api"}`. Sin cabecera `X-Powered-By`. |
| `curl` a `/api/v1/events` | `404` y `{"error":{"code":"NOT_FOUND","message":"Route not found"}}`. |
| `npm audit` | 24 avisos: 20 moderados y 4 altos. No se aplicó `npm audit fix --force`. |
| Consolidación: prueba de cabeceras en rojo y luego `npm test` | La primera ejecución falló porque `x-content-type-options` no existía. Después del middleware, 8 pruebas superadas. |
| Consolidación: `npm run lint` y `npm run build` | Sin incidencias. `tsc` terminó sin errores. |
| `npm audit signatures` | No terminó la comprobación. Error `SELF_SIGNED_CERT_IN_CHAIN` contra `tuf-repo-cdn.sigstore.dev`. |
| `move flutter_application_1 mobile` | Movió 1 directorio. `mobile/pubspec.yaml` existe y `flutter_application_1/` ya no está en la raíz. |
| Desde `mobile/`: `flutter pub get`, `flutter analyze`, `flutter test` | Dependencias resueltas. Análisis sin incidencias. 4 pruebas superadas. |
| Tras el traslado: `npm test`, `npm run lint`, `npm run build` | 8 pruebas superadas. Lint limpio. `tsc` sin errores. |
| Identificador nativo y autenticación: `flutter analyze` y `flutter test` | Análisis sin incidencias. 18 pruebas superadas. |
| Autenticación: `npm test`, `npm run lint`, `npm run build` | 18 pruebas superadas. Lint limpio. `tsc` sin errores. |
| `npx prisma generate` y `npx prisma validate` tras el modelo `User` | Cliente regenerado y esquema válido. No se aplicó la migración. |
| Agenda: `npm test`, `npm run lint`, `npm run build` | 22 pruebas superadas. Lint limpio. `tsc` sin errores. |
| Agenda: `flutter analyze` y `flutter test` | Análisis sin incidencias. 23 pruebas superadas. |
| PostgreSQL local: `prisma migrate deploy` | Aplicó `20261013184500_create_users` y `20261014000000_create_events` en `secureplan_dev`. |
| Persistencia: `RUN_DB_INTEGRATION=1` y la API en el puerto 3000 | Registro, inicio, CRUD y aislamiento entre usuarios contra PostgreSQL. Los registros de prueba se borraron. |
| Regresión: `npm test`, `npm run lint`, `npm run build`, `npm run prisma:validate` | 22 pruebas superadas y 1 omitida sin la variable de integración. Lint, `tsc` y esquema válidos. |
| Regresión: `flutter test` y `flutter analyze` | 23 pruebas superadas. Análisis sin incidencias. |
| Recurrencia: `npm test`, `npm run lint`, `npm run build`, `npm run prisma:validate` | 31 pruebas superadas y 2 de PostgreSQL omitidas sin la variable. Lint, `tsc` y esquema válidos. |
| Recurrencia contra PostgreSQL: `RUN_DB_INTEGRATION=1` | 2 pruebas superadas, incluida una serie mensual. |
| Recurrencia: `flutter test` y `flutter analyze` | 24 pruebas superadas. Análisis sin incidencias. |
| Sincronización: `npm test`, `npm run lint`, `npm run build`, `prisma validate` | 35 pruebas superadas y 2 de PostgreSQL omitidas sin la variable. Lint y `tsc` sin errores. Esquema válido. |
| Sincronización contra PostgreSQL: `RUN_DB_INTEGRATION=1` | 2 pruebas superadas después de aplicar `20261014043000_event_sync`. |
| Agenda local: `flutter test` y `flutter analyze` | 33 pruebas superadas. Análisis sin incidencias. El cifrado se comprobó en ese ejecutor de Windows, no en Android. |
| Entrega: `npm test`, `npm run lint`, `npm run build`, `prisma validate` | 36 pruebas superadas y 2 de PostgreSQL omitidas. Lint, `tsc` y esquema válidos. |
| Entrega: `RUN_DB_INTEGRATION=1` | 2 pruebas superadas contra PostgreSQL. |
| Entrega: `flutter test` y `flutter analyze` | 34 pruebas superadas. Análisis sin incidencias. |
| Entrega: `flutter build apk --debug` | El primer intento falló porque faltaba desugaring. Tras activarlo, Gradle generó `mobile/build/app/outputs/flutter-apk/app-debug.apk`. |
| Entrega: `npm audit` | 24 avisos: 20 moderados y 4 altos. No se aplicó `npm audit fix --force`. |

El proceso de prueba se detuvo. El puerto 3099 quedó libre. `npm audit fix --force` proponía bajar Prisma a 6.19.3 y ts-jest a 29.1.2. Esos cambios rompen la selección de versiones y no se aplicaron. Los avisos altos están en `deepmerge-ts` y `mysql2`, ambos transitivos de la CLI de Prisma. Esta API usa el adaptador de PostgreSQL, no MySQL.

`npm install` también avisó de que la dependencia transitiva `glob@10.5.0` está obsoleta. No se forzó su actualización.

## No verificado

- `flutter run` y `flutter build windows`. El APK de depuración sí se compiló.
- Aceptación de licencias Android.
- El flujo visual en el emulador. La API ya escucha en el puerto 3000 y el emulador debe usar `http://10.0.2.2:3000`, pero no se recorrió la interfaz.
- Compilación Gradle, APK e iOS. Los identificadores sí se cambiaron en los archivos.
- El plugin nativo de `flutter_secure_storage` en un dispositivo. Las pruebas de la clave de la base usan un almacén en memoria; el cifrado en sí usa `PRAGMA key` en el ejecutor de Windows.
- Notificaciones locales, el permiso de Android 13 y el receptor de arranque en un dispositivo. El planificador se probó con un doble.
- La hoja de compartir de Android. La exportación se probó sobre los bytes, no sobre `share_plus` en un equipo.
- GitHub y la existencia de un remoto. `git` está instalado, pero `WEB-10` no es un repositorio.

## Control de versiones previsto

Cuando se inicialice el repositorio:

- trabajar en ramas y abrir Pull Requests;
- no hacer push directo a `main`;
- no commitear `.env`, `android/local.properties`, keystores ni `src/generated/` si se mantiene el `.gitignore` actual.
