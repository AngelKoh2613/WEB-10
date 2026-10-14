import { Router } from "express";
import { z } from "zod";
import { AppError } from "../errors/app-error.js";
import { createRequireAuth } from "../middleware/require-auth.js";
import { TokenService } from "../auth/tokens.js";
import { eventCategories, eventPriorities, type EventRepository } from "./event-repository.js";
import { recurrenceFrequencies } from "./recurrence.js";
import { EventService, type EventInput, type EventUpdate } from "./event-service.js";

const instantField = z.iso.datetime({ offset: true });
const titleField = z.string().trim().min(1).max(200);
const descriptionField = z
  .string()
  .trim()
  .max(4000)
  .transform((value) => (value.length === 0 ? null : value));
const categoryField = z.enum(eventCategories);
const priorityField = z.enum(eventPriorities);

const recurrenceSchema = z
  .object({
    frequency: z.enum(recurrenceFrequencies),
    interval: z.number().int().min(1).max(99),
    weekdays: z.array(z.number().int().min(0).max(6)).max(7).optional(),
    until: instantField.optional(),
    count: z.number().int().min(1).max(366).optional(),
    offsetMinutes: z.number().int().min(-840).max(840),
  })
  .strict()
  .transform((value) => ({
    frequency: value.frequency,
    interval: value.interval,
    weekdays: value.weekdays ?? [],
    until: value.until ?? null,
    count: value.count ?? null,
    offsetMinutes: value.offsetMinutes,
  }));

const reminderField = z.union([z.literal(5), z.literal(15), z.literal(60), z.literal(1440), z.null()]);

const createSchema = z
  .object({
    id: z.uuid().optional(),
    title: titleField,
    description: z.union([descriptionField, z.null()]).optional(),
    startsAt: instantField,
    endsAt: z.union([instantField, z.null()]).optional(),
    category: categoryField,
    priority: priorityField,
    recurrence: recurrenceSchema.nullable().optional(),
    reminderMinutes: reminderField.optional(),
  })
  .strict();

const updateSchema = z
  .object({
    title: titleField.optional(),
    description: z.union([descriptionField, z.null()]).optional(),
    startsAt: instantField.optional(),
    endsAt: z.union([instantField, z.null()]).optional(),
    category: categoryField.optional(),
    priority: priorityField.optional(),
    recurrence: recurrenceSchema.nullable().optional(),
    scope: z.enum(["occurrence", "series"]).optional(),
    occurrenceStart: instantField.optional(),
    reminderMinutes: reminderField.optional(),
    baseVersion: z.number().int().min(1),
  })
  .strict()
  .refine(
    (value) =>
      Object.keys(value).some(
        (key) => key !== "scope" && key !== "occurrenceStart" && key !== "baseVersion",
      ),
    { path: ["body"] },
  );

function invalidBody(): AppError {
  return new AppError(400, "VALIDATION_ERROR", "Datos no válidos");
}

function readOwner(userId: unknown): string {
  if (typeof userId !== "string" || userId.length === 0) {
    throw new AppError(401, "UNAUTHENTICATED", "Autenticación requerida");
  }
  return userId;
}

export function createEventRouter(deps: { events: EventRepository; tokens: TokenService }): Router {
  const router = Router();
  const requireAuth = createRequireAuth(deps.tokens);
  const service = new EventService(deps.events);
  router.use(requireAuth);

  router.get("/sync", async (_req, res, next) => {
    try {
      res.status(200).json(await service.snapshot(readOwner(res.locals.userId)));
    } catch (error) {
      next(error);
    }
  });

  router.get("/", async (req, res, next) => {
    try {
      res.status(200).json(await service.list(readOwner(res.locals.userId), readRange(req.query)));
    } catch (error) {
      next(error);
    }
  });

  router.get("/:id", async (req, res, next) => {
    try {
      const id = readId(req.params.id);
      res
        .status(200)
        .json(await service.read(readOwner(res.locals.userId), id, readOccurrence(req.query)));
    } catch (error) {
      next(error);
    }
  });

  router.post("/", async (req, res, next) => {
    try {
      const body = readCreate(req.body);
      const created = await service.create(readOwner(res.locals.userId), body);
      res.status(created.replayed ? 200 : 201).json(created.event);
    } catch (error) {
      next(error);
    }
  });

  router.patch("/:id", async (req, res, next) => {
    try {
      const id = readId(req.params.id);
      const body = readUpdate(req.body);
      const updated = await service.update(readOwner(res.locals.userId), id, body);
      res.status(200).json(updated);
    } catch (error) {
      next(error);
    }
  });

  router.delete("/:id", async (req, res, next) => {
    try {
      const id = readId(req.params.id);
      await service.remove(readOwner(res.locals.userId), id, readDeletion(req.query));
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  });

  return router;
}

function readId(value: string | string[] | undefined): string {
  const id = Array.isArray(value) ? value[0] : value;
  if (!z.uuid().safeParse(id).success) {
    throw new AppError(400, "VALIDATION_ERROR", "El identificador no es válido");
  }
  return id ?? "";
}

function readCreate(body: unknown): EventInput {
  const parsed = createSchema.safeParse(body);
  if (!parsed.success) {
    throw invalidBody();
  }
  return parsed.data;
}

function readUpdate(body: unknown): EventUpdate {
  const parsed = updateSchema.safeParse(body);
  if (!parsed.success) {
    throw invalidBody();
  }
  return parsed.data;
}

function readRange(query: unknown): { from: Date; to: Date } | undefined {
  const source = query && typeof query === "object" ? query : {};
  const from = "from" in source ? source.from : undefined;
  const to = "to" in source ? source.to : undefined;
  if (from === undefined && to === undefined) {
    return undefined;
  }
  const parsed = z.object({ from: instantField, to: instantField }).safeParse({ from, to });
  if (!parsed.success) {
    throw invalidBody();
  }
  return { from: new Date(parsed.data.from), to: new Date(parsed.data.to) };
}

function readOccurrence(query: unknown): string | undefined {
  const source = query && typeof query === "object" ? query : {};
  if (!("occurrenceStart" in source) || source.occurrenceStart === undefined) {
    return undefined;
  }
  const parsed = instantField.safeParse(source.occurrenceStart);
  if (!parsed.success) {
    throw invalidBody();
  }
  return parsed.data;
}

function readDeletion(query: unknown): {
  scope?: "occurrence" | "series";
  occurrenceStart?: string;
  baseVersion: number;
} {
  const source = query && typeof query === "object" ? query : {};
  const parsed = z
    .object({
      scope: z.enum(["occurrence", "series"]).optional(),
      occurrenceStart: instantField.optional(),
      baseVersion: z.coerce.number().int().min(1),
    })
    .safeParse({
      scope: "scope" in source ? source.scope : undefined,
      occurrenceStart: "occurrenceStart" in source ? source.occurrenceStart : undefined,
      baseVersion: "baseVersion" in source ? source.baseVersion : undefined,
    });
  if (!parsed.success) {
    throw invalidBody();
  }
  if (parsed.data.scope === "occurrence" && parsed.data.occurrenceStart === undefined) {
    throw invalidBody();
  }
  if (parsed.data.scope === "series" && parsed.data.occurrenceStart !== undefined) {
    throw invalidBody();
  }
  return parsed.data;
}
