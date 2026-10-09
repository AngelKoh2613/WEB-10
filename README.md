# SecurePlan Mobile

Monorepositorio de la aplicación de agenda SecurePlan y de su API. Incluye el identificador nativo, la autenticación y el CRUD de eventos con calendario. No incluye sincronización, recurrencia, notificaciones ni exportación.

## Ubicación

| Parte | Ruta actual | Estado |
| --- | --- | --- |
| Cliente Flutter | `mobile/` | Paquete `secureplan_mobile`. Identificador `com.secureplan.mobile`. Sesión con Riverpod. |
| API | `backend/` | Express. `GET /health`, `/api/auth` y `/api/events`. |
| Documentación | `docs/` | Decisiones, contratos y procedimientos. |

El cliente está en `mobile/`. Los dos intentos anteriores de moverlo fallaron porque el directorio estaba en uso; el tercero movió la carpeta completa. El detalle está en [docs/Decisions.md](docs/Decisions.md).

## Lectura recomendada

1. [docs/Development.md](docs/Development.md) para instalar, ejecutar y ver qué se comprobó.
2. [docs/Architecture.md](docs/Architecture.md) para las capas y los límites.
3. [docs/Decisions.md](docs/Decisions.md) para lo ya decidido y lo que sigue pendiente.

No hay repositorio Git en esta carpeta. No se debe hacer push a `main` cuando el repositorio exista.

Las skills de agente están en `.agents/skills/`. El inventario es `skills-lock.json`. Se consultan antes de cada tarea y no se reinstalan si siguen presentes.
