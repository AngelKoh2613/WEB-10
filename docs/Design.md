# Diseño de interfaz

Hay un tema claro, tres componentes de estado, las pantallas de sesión y la agenda con calendario. No hay ajustes ni tema oscuro.

## Principios

- Una sola familia visual: Material 3, color semilla `#1B4D4A`, sin mezclar estilos por pantalla.
- El texto usa los estilos del tema para respetar el tamaño de letra del sistema.
- Los botones de acción tienen al menos 48 por 48.
- Cada operación lenta tiene un estado de carga. Cada lista puede estar vacía. Cada fallo recuperable ofrece reintento.
- No se usan colores como única señal: el error lleva icono y texto.
- La interfaz cabe en un teléfono estrecho. Los bloques de texto vacíos y de error limitan su ancho a 420.
- El idioma visible de esta base es español.

## Lo que ya se puede reutilizar

| Componente | Uso |
| --- | --- |
| `AppTheme.light()` | Tema de `MaterialApp` |
| `EmptyView` | Un día sin eventos, y los estados vacíos anteriores |
| `MonthCalendar` | Mes, día seleccionado y marca en los días con eventos |
| `EventFormScreen` | Alta y edición, con validación junto a los campos |
| `AgendaScreen` | Lista del día, carga, error con reintento y confirmación de borrado |
| `ErrorView` | Fallo con título, mensaje y, si hay acción, el botón `Reintentar` |
| `LoadingView` | Espera, con el mensaje expuesto a semántica |

No hay tema oscuro. Añadirlo es una decisión visual pendiente, no un requisito de esta base.

## Estados que cada pantalla futura debe contemplar

- Carga inicial.
- Vacío, con una frase que diga qué falta y no un contenedor en blanco.
- Error de validación junto al campo.
- Error de servidor o de base local, con reintento si la acción se puede repetir.
- Sin conexión: la agenda sigue visible si los datos locales existen. Un aviso breve indica que los cambios esperan sincronización. No bloquear toda la pantalla.
- Conflicto de sincronización: las dos versiones, una acción para conservar cada una. No un diálogo genérico de "error".

`connectivity_plus` no está instalado, así que el aviso de red todavía no tiene un componente.

## Accesibilidad

- `LoadingView` marca el mensaje con `Semantics`.
- Los contrastes salen de `ColorScheme.fromSeed` sobre el color semilla. No se ha medido el contraste con una herramienta externa.
- Los objetivos táctiles del botón relleno están fijados en el tema. Los iconos sueltos de una futura barra deben heredar ese mínimo.
- No hay dependencia de un gesto exclusivo. Las acciones principales serán botones con texto.

## Navegación prevista

`go_router` sigue sin instalarse. El mapa actual es:

- sin sesión: acceso y registro;
- con sesión: agenda y calendario en `AppShell`;
- alta y edición de un evento encima de la agenda, con `Navigator.push`.

El calendario no depende de un paquete nuevo. La cuadrícula mantiene una altura de celda fija para que un ancho grande no la haga desbordar la pantalla, y el conjunto se desplaza si el alto no alcanza.

`MaterialApp` abre `AuthGate`. El registro se apila sobre el inicio. No hay rutas con nombre ni `go_router`.

## Identidad nativa

El nombre visible es SecurePlan en el manifiesto de Android, en `CFBundleDisplayName` de iOS y en el título de la ventana de Windows. El identificador de aplicación es `com.secureplan.mobile` en Android y en los targets de iOS. El ejecutable de Windows sigue llamándose internamente `flutter_application_1`.
