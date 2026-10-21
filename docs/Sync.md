# Sincronización

La bandeja, el identificador idempotente y el conflicto por versión están implementados. No se instaló `connectivity_plus`: un cambio de red no se toma como prueba de que el servidor responde. La agenda consulta la API y clasifica el error real.

## Papel de cada almacén

- SQLite cifrado es lo que la interfaz lee. La agenda tiene que abrirse sin red.
- La bandeja de salida vive en esa misma base y conserva las operaciones todavía no aceptadas por el servidor.
- PostgreSQL es el estado compartido y la referencia cuando el servidor acepta un cambio.
- Una operación no se borra de la bandeja hasta recibir una respuesta definitiva de éxito o un conflicto que el usuario ya resolvió.

## Operación pendiente

Cada cambio local crea un registro de bandeja:

- `operationId` nuevo, UUID.
- identidad del evento, también UUID creado en el cliente.
- `upsert` o `delete`.
- `baseVersion` que el cliente tenía. Una creación usa `0`.
- el payload necesario para reproducir el cambio.
- contador de intentos.

El mismo `operationId` se reenvía si la respuesta se pierde. El servidor guarda los `operationId` ya aplicados por usuario y, si lo recibe de nuevo, devuelve el resultado original sin repetir el efecto.

## Orden y recuperación

- La bandeja se envía en orden de `createdAt`.
- Si una operación no puede seguir por conflicto, las posteriores del mismo `entityId` esperan. Las de otros eventos pueden continuar.
- Si la aplicación se cierra a mitad del envío, al volver a abrir se retoman las operaciones que sigan en la bandeja.
- Un `500` o un corte de red incrementan `attemptCount` y se reintentan con espera creciente. No se reintenta de inmediato un `400` de validación: eso requiere corrección, no otro envío idéntico.
- `connectivity_plus` 7.3.2 es la biblioteca prevista para enterarse de la red. No está instalada. Un cambio de red no debe ser el único disparador: al abrir la aplicación también se intenta vaciar la bandeja.

## Conflictos

Propuesta pendiente de confirmación, porque cambiarla con datos reales es costoso:

- El servidor incrementa `version` en cada cambio aceptado.
- El cliente envía `baseVersion`.
- Si `baseVersion` no es la versión actual, el servidor no escribe y responde `409` con `CONFLICT` y el evento vigente en `server`.
- El cliente no elige un ganador en silencio. Muestra las dos versiones y solo la resolución del usuario genera una operación nueva.

Alternativa más simple, no recomendada: el último `updatedAt` gana. Pierde cambios sin avisar y no cumple el requisito de manejo explícito de conflictos.

La edición de una sola ocurrencia de un evento repetido queda fuera de esta regla hasta que `Database.md` cierre cómo se representa esa excepción.

## Relojes

No se usa el reloj del dispositivo como autoridad de orden entre dos usuarios. Para un solo dueño, `version` evita depender de relojes desincronizados. `startsAt` es la hora del evento, no la hora de la sincronización.

## Qué debe existir antes de programar esto

1. SQLite cifrado abierto en Android y, si se mantiene ese destino, en Windows.
2. Tablas de evento y de bandeja.
3. Sesión capaz de llamar a la API.
4. Confirmación de la política de `version` y `409`.
5. El endpoint de lote, que hoy no existe.
