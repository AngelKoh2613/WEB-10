# Flujos

## Flujo actual

1. `main` arranca `ProviderScope` y `SecurePlanApp`.
2. El tema claro se aplica.
3. `AuthGate` muestra `Comprobando sesión` hasta leer el token.
4. Sin sesión, muestra el inicio. Con sesión, `AppShell` lee `appNameProvider`, muestra `SecurePlan` y el estado vacío.

El cascarón aislado está cubierto por `test/app_shell_test.dart`. La puerta de sesión está cubierta por `test/auth_screen_test.dart`.

## Registro e inicio

Implementado en las pantallas y en `/api/auth`. El registro y el inicio se comprobaron contra PostgreSQL desde la API. No se recorrió el flujo en el emulador.

1. La persona crea una cuenta con correo y contraseña.
2. El cliente valida el formato y la política. El servidor vuelve a validar y guarda Argon2id.
3. El servidor emite un access token de 15 minutos. No hay refresh token.
4. El cliente guarda ese token en almacenamiento seguro.
5. El inicio posterior repite la comprobación de contraseña y usa el mismo mensaje si el correo no existe.
6. El cierre borra el token local. El servidor responde `204` y no lo revoca. Si la llamada de cierre falla por red, el token local se borra igualmente.
7. Al volver a abrir la aplicación, un token caducado o rechazado se borra. Si no hay red y el token no está caducado en local, se abre el cascarón sin demostrar que el servidor lo acepte.

## Agenda

Implementado contra la API. No hay SQLite ni bandeja de salida.

1. Con sesión, el calendario muestra el mes y marca los días que tienen eventos.
2. La lista de debajo corresponde al día seleccionado. Se puede ir a meses anteriores y posteriores.
3. Crear y editar piden título, descripción, inicio, fin opcional, categoría y prioridad. El cliente valida y el servidor vuelve a validar.
4. Eliminar pide confirmación. Si el servidor responde error, el evento sigue en la lista y se muestra el mensaje.
5. El borrado en el servidor es físico. No hay recurrencia: cada evento es una sola fecha de inicio.
6. Si la API responde `401`, la aplicación borra el token local y vuelve al inicio. No reintenta la petición.

## Recurrencia

Previsto, como mínimo diaria, semanal y mensual.

1. Al crear el evento, la persona elige no repetir o una de esas tres frecuencias.
2. Puede indicar un intervalo y, o una fecha final, o un número de veces.
3. El calendario expande las ocurrencias en el rango visible. No se materializan todas las fechas futuras en filas infinitas.
4. Un aviso local se programa para la próxima ocurrencia, no para un número ilimitado de fechas.

## Offline y sincronización

Implementado en el cliente y en la API. El detalle está en `Sync.md`.

1. Sin red, crear, editar y borrar quedan en la base cifrada y en la bandeja.
2. Al consultar la agenda se intenta enviar la bandeja y luego leer `GET /api/events/sync`. Un fallo de red no borra los cambios locales.
3. Si el servidor responde `409`, el evento queda en conflicto y la persona elige.
4. Hasta esa elección, la copia local no se pisa.

## Avisos

El formulario ofrece sin recordatorio, 5 minutos, 15 minutos, 1 hora o 1 día. El valor inicial es 15 minutos. `ReminderObserver` recibe los cambios y el plugin `flutter_local_notifications` 22.3.2 reprograma como máximo 20 avisos de los próximos 14 días, con `inexactAllowWhileIdle`. Si Android niega el permiso, la agenda sigue funcionando. No se comprobó la entrega en un dispositivo.

## Exportación

El botón Exportar deja elegir JSON o CSV. El archivo contiene las ocurrencias cargadas del mes visible, en UTF-8, y no tokens ni la bandeja. El aviso de éxito solo aparece si `share_plus` termina. Esa hoja no se abrió en un dispositivo.

## Errores

Previsto sobre el manejador ya existente en cada lado.

- En la API, un fallo no controlado llega al manejador central.
- En el cliente, un fallo de un caso de uso se traduce a `ErrorView` o a un error de campo. No se muestra una traza.
