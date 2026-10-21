# Demostración

Recorrido de la máquina de desarrollo y resultado de la validación en el emulador Android `Medium_Phone_API_35` (API 35), el 14 de octubre de 2026. No hubo un teléfono físico. iOS no se compiló.

## Preparar el servidor

Desde `backend/`:

```powershell
Copy-Item .env.example .env
```

Sustituye `replace-me` y el secreto JWT en `.env`. No copies ese archivo a ningún informe.

```powershell
docker compose up -d
npx prisma migrate deploy
npm run dev
```

`GET http://127.0.0.1:3000/health` debe responder `200` con `status` `ok`. El contenedor es `secureplan-postgres`, en el puerto `5434`. En esta validación Docker Desktop se arrancó, el contenedor quedó `healthy`, no había migraciones pendientes y la API respondió en el puerto `3000`.

## Preparar el cliente

Desde `mobile/`, en el mismo ordenador que la API:

```powershell
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000
```

El emulador no llega al anfitrión por `localhost`. El APK de esta validación se compiló con el mecanismo ya existente:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

El paquete es `com.secureplan.mobile`, versión `0.1.0`. El manifiesto de depuración declara `INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` y `VIBRATE`. El APK incluye `libsqlite3mc.so`. El binario anterior, del 13 de octubre a las 20:04, se había compilado sin esa URL.

## Resultado en el emulador

Cuenta temporal creada durante la prueba y borrada al terminar, junto con sus eventos. La aplicación se instaló, abrió en el inicio de sesión y no se cerró sola.

1. El registro correcto entra en la agenda. Antes de la corrección, la pantalla de registro permanecía encima aunque la cuenta ya existía; había que pulsar atrás. Ahora esa ruta se cierra al tener éxito.
2. Crear, editar y volver a abrir la aplicación conserva el evento. Eliminar pide confirmación. Cerrar sesión vuelve al inicio de sesión y deja de mostrar los títulos.
3. Un JWT caducado (15 minutos) devuelve al inicio de sesión sin mostrar la agenda.
4. Con el modo avión del emulador, el alta queda marcada como `Pendiente`, sobrevive a cerrar la aplicación y no aparece en PostgreSQL. Al recuperar la red y abrir de nuevo, se crea una sola fila. El estado deja de decir `Pendiente` solo después de esa confirmación.
5. Si el servidor tiene otra versión, la agenda muestra `Conflicto` y los botones «Usar servidor» y «Usar mi versión». Elegir el servidor sustituye el título local y no duplica la fila.
6. Con la API inalcanzable, el inicio de sesión dice «No hay conexión con el servidor». No aparece un volcado de pila.
7. La base local es `files/agenda-<userId>.sqlite`. Su cabecera no es `SQLite format 3`, el título no está en claro y `sqlite3` del sistema responde `file is not a database`. La clave `agenda-key-<userId>` y el token están en `FlutterSecureStorage`, sin la contraseña ni un JWT en texto claro. Cerrar y abrir la aplicación vuelve a leer el archivo. No se inyectó una clave incorrecta dentro del proceso de Android.
8. Android pidió el permiso de notificaciones al entrar en la agenda. Se autorizó. Un evento a las 15:28 con aviso de 5 minutos mostró «SecurePlan» y «Recordatorio prueba» a las 15:23. Editar la hora movió la alarma a las 15:35 y retiró la notificación visible. Eliminar el evento canceló la alarma. Tras reiniciar la aplicación no volvió a programarse. No se reinició el emulador para comprobar el arranque.
9. Exportar abre la hoja del sistema, «Sharing 1 file», con `secureplan-eventos-2026-10-14.json` y el mismo nombre en `.csv`. Hay destinos (Quick Share, Drive, Gmail). El JSON usa `format` `secureplan-events` y no incluye token, clave ni datos de sincronización. El CSV antepone `'` al título `=1+1 cafe edit`. No se escribió un acento desde el teclado del emulador.

## Recorrido de las pruebas automáticas

1. Registrar una cuenta nueva. La contraseña necesita de 10 a 128 caracteres, una letra y un dígito, y no puede ser igual al correo. No hay una cuenta sembrada.
2. Iniciar sesión. El token queda en el almacenamiento seguro, no en preferencias.
3. Crear un evento único y verlo en el día elegido.
4. Editarlo y eliminarlo. La eliminación pide confirmación.
5. Crear una serie diaria, semanal o mensual. Un mes sin el día elegido se omite.
6. Al editar o borrar una serie, elegir solo esa fecha o toda la serie.
7. Cerrar la base local y volver a abrirla conserva el evento y la operación pendiente.
8. Con la red simulada como caída, el alta queda pendiente y no se envía. Al recuperar la respuesta del servidor, se envía una sola vez.
9. Si otra versión cambió el evento, la copia local se conserva y se marca como conflicto.
10. Exportar el mes visible a JSON o CSV. El archivo no lleva el token. Un título que empieza por `=` se precede con un apóstrofo.
11. Cerrar sesión borra el token del dispositivo. El JWT sigue siendo válido hasta que caduque, como máximo 15 minutos.
12. Otro usuario no puede leer, cambiar ni borrar el evento. La API responde `404`.

## Lo que no queda verificado

- El rearranque del emulador y la reprogramación de avisos tras `BOOT_COMPLETED`.
- Una clave incorrecta dentro del proceso de Android, para comprobar que el archivo no se borra.
- Caracteres acentuados escritos desde el teclado del emulador y vueltos a leer en el archivo exportado.
- iOS. El identificador `com.secureplan.mobile` está en el proyecto, pero no hay compilación de iOS.
- `npm audit` sigue con 24 avisos (4 altos, transitivos de las herramientas de Prisma). No se ejecutó `npm audit fix --force`.
