import { AppError } from "../errors/app-error.js";
import {
  toPublicEvent,
  type EventCategory,
  type EventDraft,
  type EventPatch,
  type EventPriority,
  type EventRepository,
  type OccurrenceView,
  type StoredEvent,
  type StoredException,
} from "./event-repository.js";
import {
  occurrencesInRange,
  recurrenceError,
  seriesStarts,
  type RecurrenceFrequency,
  type RecurrenceRule,
} from "./recurrence.js";

const maxRangeMs = 62 * 86_400_000;

export type RecurrenceInput = {
  frequency: RecurrenceFrequency;
  interval: number;
  weekdays: number[];
  until: string | null;
  count: number | null;
  offsetMinutes: number;
};

export type EventInput = {
  id?: string;
  title: string;
  description?: string | null;
  startsAt: string;
  endsAt?: string | null;
  category: EventCategory;
  priority: EventPriority;
  recurrence?: RecurrenceInput | null;
  reminderMinutes?: number | null;
};

export type EventUpdate = Partial<EventInput> & {
  scope?: "occurrence" | "series";
  occurrenceStart?: string;
  baseVersion: number;
};

export type EventRange = { from: Date; to: Date };

function parseInstant(value: string): Date {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new AppError(400, "VALIDATION_ERROR", "La fecha no es válida");
  }
  return parsed;
}

export function assertInterval(startsAt: Date, endsAt: Date | null): void {
  if (endsAt && endsAt.getTime() <= startsAt.getTime()) {
    throw new AppError(400, "VALIDATION_ERROR", "La hora de fin debe ser posterior al inicio");
  }
}

function emptyRecurrence(): Pick<
  EventDraft,
  | "recurrenceFrequency"
  | "recurrenceInterval"
  | "recurrenceWeekdays"
  | "recurrenceUntil"
  | "recurrenceCount"
  | "recurrenceOffsetMinutes"
> {
  return {
    recurrenceFrequency: null,
    recurrenceInterval: 1,
    recurrenceWeekdays: [],
    recurrenceUntil: null,
    recurrenceCount: null,
    recurrenceOffsetMinutes: null,
  };
}

function ruleFrom(event: StoredEvent): RecurrenceRule | null {
  if (event.recurrenceFrequency === null || event.recurrenceOffsetMinutes === null) {
    return null;
  }
  return {
    frequency: event.recurrenceFrequency,
    interval: event.recurrenceInterval,
    weekdays: event.recurrenceWeekdays,
    until: event.recurrenceUntil,
    count: event.recurrenceCount,
    offsetMinutes: event.recurrenceOffsetMinutes,
  };
}

function fieldsFromRule(rule: RecurrenceRule | null) {
  if (!rule) {
    return emptyRecurrence();
  }
  return {
    recurrenceFrequency: rule.frequency,
    recurrenceInterval: rule.interval,
    recurrenceWeekdays: rule.weekdays,
    recurrenceUntil: rule.until,
    recurrenceCount: rule.count,
    recurrenceOffsetMinutes: rule.offsetMinutes,
  };
}

function parseRule(startsAt: Date, recurrence: RecurrenceInput | null | undefined): RecurrenceRule | null {
  if (!recurrence) {
    return null;
  }
  const rule: RecurrenceRule = {
    frequency: recurrence.frequency,
    interval: recurrence.interval,
    weekdays: recurrence.weekdays,
    until: recurrence.until ? parseInstant(recurrence.until) : null,
    count: recurrence.count,
    offsetMinutes: recurrence.offsetMinutes,
  };
  const error = recurrenceError(startsAt, rule);
  if (error) {
    throw new AppError(400, "VALIDATION_ERROR", error);
  }
  return rule;
}

export class EventService {
  constructor(private readonly events: EventRepository) {}

  async create(userId: string, input: EventInput) {
    if (input.id) {
      const buried = await this.events.findTombstone(input.id, userId);
      if (buried) {
        throw new AppError(409, "CONFLICT", "El evento ya no existe");
      }
      const existing = await this.events.findOwned(input.id, userId);
      if (existing) {
        return { event: toPublicEvent(existing), replayed: true };
      }
    }
    const startsAt = parseInstant(input.startsAt);
    const endsAt = input.endsAt ? parseInstant(input.endsAt) : null;
    assertInterval(startsAt, endsAt);
    const draft: EventDraft = {
      id: input.id,
      userId,
      title: input.title,
      description: input.description ?? null,
      startsAt,
      endsAt,
      category: input.category,
      priority: input.priority,
      reminderMinutes: input.reminderMinutes === undefined ? 15 : input.reminderMinutes,
      ...fieldsFromRule(parseRule(startsAt, input.recurrence)),
    };
    return { event: toPublicEvent(await this.events.create(draft)), replayed: false };
  }

  async list(userId: string, range?: EventRange) {
    const stored = await this.events.listByOwner(userId);
    if (!range) {
      return { events: stored.map((event) => toPublicEvent(event)) };
    }
    const span = range.to.getTime() - range.from.getTime();
    if (span <= 0 || span > maxRangeMs) {
      throw new AppError(400, "VALIDATION_ERROR", "El rango solicitado es demasiado grande");
    }
    const exceptions = await this.events.listExceptions(userId);
    const events = stored.flatMap((event) => this.project(event, exceptions, range));
    if (events.length > 500) {
      throw new AppError(400, "VALIDATION_ERROR", "El rango solicitado es demasiado grande");
    }
    events.sort((left, right) => {
      const byStart = left.startsAt.localeCompare(right.startsAt);
      return byStart === 0 ? left.occurrenceStart.localeCompare(right.occurrenceStart) : byStart;
    });
    return { events };
  }

  async read(userId: string, id: string, occurrenceStart?: string) {
    const event = await this.findOwned(userId, id);
    if (!occurrenceStart) {
      return toPublicEvent(event);
    }
    const original = parseInstant(occurrenceStart);
    const exceptions = await this.events.listExceptions(userId);
    this.assertOccurrence(event, original, exceptions);
    return toPublicEvent(event, this.viewFor(event, original, exceptions));
  }

  async snapshot(userId: string) {
    const [events, exceptions, tombstones] = await Promise.all([
      this.events.listByOwner(userId),
      this.events.listExceptions(userId),
      this.events.listTombstones(userId),
    ]);
    if (events.length > 500) {
      throw new AppError(400, "VALIDATION_ERROR", "Hay demasiados eventos para sincronizar");
    }
    return {
      events: events.map((event) => toPublicEvent(event)),
      exceptions: exceptions.map((item) => ({
        id: item.id,
        eventId: item.eventId,
        originalStart: item.originalStart.toISOString(),
        excluded: item.excluded,
        title: item.title,
        description: item.description,
        startsAt: item.startsAt ? item.startsAt.toISOString() : null,
        endsAt: item.endsAt ? item.endsAt.toISOString() : null,
        category: item.category,
        priority: item.priority,
      })),
      tombstones: tombstones.map((item) => ({
        id: item.id,
        version: item.version,
        deletedAt: item.deletedAt.toISOString(),
      })),
    };
  }

  async update(userId: string, id: string, input: EventUpdate) {
    const current = await this.findOwned(userId, id);
    this.assertVersion(current, input.baseVersion);
    const recurring = ruleFrom(current) !== null;
    if (input.scope === "occurrence") {
      return this.replaceOccurrence(userId, current, input);
    }
    if (recurring && input.scope !== "series") {
      throw new AppError(
        400,
        "VALIDATION_ERROR",
        "Indica si el cambio es solo de este evento o de toda la serie",
      );
    }
    if (!recurring && input.scope !== undefined) {
      throw new AppError(400, "VALIDATION_ERROR", "Datos no válidos");
    }

    const startsAt = input.startsAt ? parseInstant(input.startsAt) : current.startsAt;
    const endsAt =
      input.endsAt === undefined
        ? current.endsAt
        : input.endsAt === null
          ? null
          : parseInstant(input.endsAt);
    assertInterval(startsAt, endsAt);
    const rule =
      input.recurrence === undefined ? parseRule(startsAt, this.inputFrom(current)) : parseRule(startsAt, input.recurrence);
    const patch: EventPatch = {
      startsAt,
      endsAt,
      version: current.version + 1,
      ...fieldsFromRule(rule),
    };
    if (input.reminderMinutes !== undefined) {
      patch.reminderMinutes = input.reminderMinutes;
    }
    if (input.title !== undefined) {
      patch.title = input.title;
    }
    if (input.description !== undefined) {
      patch.description = input.description;
    }
    if (input.category !== undefined) {
      patch.category = input.category;
    }
    if (input.priority !== undefined) {
      patch.priority = input.priority;
    }
    const updated = await this.events.update(id, userId, patch);
    if (!updated) {
      throw new AppError(404, "NOT_FOUND", "Evento no encontrado");
    }
    if (recurring || input.recurrence) {
      await this.events.clearExceptions(id, userId);
    }
    return toPublicEvent(updated);
  }

  async remove(
    userId: string,
    id: string,
    deletion: { scope?: "occurrence" | "series"; occurrenceStart?: string; baseVersion: number },
  ): Promise<void> {
    const current = await this.findOwned(userId, id);
    this.assertVersion(current, deletion.baseVersion);
    const recurring = ruleFrom(current) !== null;
    if (!recurring || deletion.scope === "series") {
      if (deletion.scope === "occurrence") {
        throw new AppError(400, "VALIDATION_ERROR", "Datos no válidos");
      }
      await this.events.addTombstone({ id, userId, version: current.version });
      const deleted = await this.events.delete(id, userId);
      if (!deleted) {
        throw new AppError(404, "NOT_FOUND", "Evento no encontrado");
      }
      return;
    }
    if (deletion.scope !== "occurrence" || !deletion.occurrenceStart) {
      throw new AppError(
        400,
        "VALIDATION_ERROR",
        "Indica si quieres excluir este evento o eliminar la serie",
      );
    }
    const original = parseInstant(deletion.occurrenceStart);
    this.assertOccurrence(current, original, await this.events.listExceptions(userId));
    await this.events.update(current.id, userId, { version: current.version + 1 });
    const saved = await this.events.saveException(userId, {
      eventId: current.id,
      originalStart: original,
      excluded: true,
      title: null,
      description: null,
      startsAt: null,
      endsAt: null,
      category: null,
      priority: null,
    });
    if (!saved) {
      throw new AppError(404, "NOT_FOUND", "Evento no encontrado");
    }
  }

  private async replaceOccurrence(userId: string, current: StoredEvent, input: EventUpdate) {
    if (!input.occurrenceStart || input.recurrence !== undefined || ruleFrom(current) === null) {
      throw new AppError(400, "VALIDATION_ERROR", "Datos no válidos");
    }
    const original = parseInstant(input.occurrenceStart);
    const exceptions = await this.events.listExceptions(userId);
    this.assertOccurrence(current, original, exceptions);
    const base = this.viewFor(current, original, exceptions);
    const startsAt = input.startsAt ? parseInstant(input.startsAt) : base.startsAt;
    const endsAt =
      input.endsAt === undefined ? base.endsAt : input.endsAt === null ? null : parseInstant(input.endsAt);
    assertInterval(startsAt, endsAt);
    const next: OccurrenceView = {
      originalStart: original,
      title: input.title ?? base.title,
      description: input.description === undefined ? base.description : input.description,
      startsAt,
      endsAt,
      category: input.category ?? base.category,
      priority: input.priority ?? base.priority,
    };
    await this.events.update(current.id, userId, { version: current.version + 1 });
    const saved = await this.events.saveException(userId, {
      eventId: current.id,
      originalStart: original,
      excluded: false,
      title: next.title,
      description: next.description,
      startsAt: next.startsAt,
      endsAt: next.endsAt,
      category: next.category,
      priority: next.priority,
    });
    if (!saved) {
      throw new AppError(404, "NOT_FOUND", "Evento no encontrado");
    }
    return toPublicEvent({ ...current, version: current.version + 1 }, next);
  }

  private assertVersion(current: StoredEvent, baseVersion: number): void {
    if (baseVersion !== current.version) {
      throw new AppError(409, "CONFLICT", "El evento cambió en el servidor", {
        server: toPublicEvent(current),
      });
    }
  }

  private viewFor(event: StoredEvent, original: Date, exceptions: StoredException[]): OccurrenceView {
    const existing = exceptions.find(
      (item) => item.eventId === event.id && item.originalStart.getTime() === original.getTime() && !item.excluded,
    );
    const duration = event.endsAt ? event.endsAt.getTime() - event.startsAt.getTime() : null;
    if (existing) {
      return {
        originalStart: original,
        title: existing.title ?? event.title,
        description: existing.description,
        startsAt: existing.startsAt ?? original,
        endsAt: existing.endsAt,
        category: existing.category ?? event.category,
        priority: existing.priority ?? event.priority,
      };
    }
    return {
      originalStart: original,
      title: event.title,
      description: event.description,
      startsAt: original,
      endsAt: duration === null ? null : new Date(original.getTime() + duration),
      category: event.category,
      priority: event.priority,
    };
  }

  private assertOccurrence(event: StoredEvent, original: Date, exceptions: StoredException[]): void {
    const rule = ruleFrom(event);
    if (!rule) {
      throw new AppError(404, "NOT_FOUND", "Evento no encontrado");
    }
    const known = seriesStarts(event.startsAt, rule).some((item) => item.getTime() === original.getTime());
    const excluded = exceptions.some(
      (item) =>
        item.eventId === event.id &&
        item.originalStart.getTime() === original.getTime() &&
        item.excluded,
    );
    if (!known || excluded) {
      throw new AppError(404, "NOT_FOUND", "Evento no encontrado");
    }
  }

  private project(event: StoredEvent, exceptions: StoredException[], range: EventRange) {
    const owned = exceptions.filter((item) => item.eventId === event.id);
    return occurrencesInRange({
      startsAt: event.startsAt,
      endsAt: event.endsAt,
      recurrence: ruleFrom(event),
      exceptions: owned,
      rangeStart: range.from,
      rangeEnd: range.to,
    }).map((item) => {
      const exception = owned.find(
        (candidate) => candidate.originalStart.getTime() === item.originalStart.getTime() && !candidate.excluded,
      );
      return toPublicEvent(event, {
        originalStart: item.originalStart,
        startsAt: item.startsAt,
        endsAt: item.endsAt,
        title: exception?.title ?? event.title,
        description: exception ? exception.description : event.description,
        category: exception?.category ?? event.category,
        priority: exception?.priority ?? event.priority,
      });
    });
  }

  private inputFrom(event: StoredEvent): RecurrenceInput | null {
    const rule = ruleFrom(event);
    if (!rule) {
      return null;
    }
    return {
      frequency: rule.frequency,
      interval: rule.interval,
      weekdays: rule.weekdays,
      until: rule.until ? rule.until.toISOString() : null,
      count: rule.count,
      offsetMinutes: rule.offsetMinutes,
    };
  }

  private async findOwned(userId: string, id: string) {
    const event = await this.events.findOwned(id, userId);
    if (!event) {
      throw new AppError(404, "NOT_FOUND", "Evento no encontrado");
    }
    return event;
  }
}
