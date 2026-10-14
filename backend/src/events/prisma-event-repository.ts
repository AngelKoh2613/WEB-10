import { getPrismaClient } from "../data/prisma-client.js";
import type { RecurrenceFrequency } from "./recurrence.js";
import type {
  EventCategory,
  EventDraft,
  EventPatch,
  EventPriority,
  EventRepository,
  ExceptionDraft,
  StoredEvent,
  StoredException,
} from "./event-repository.js";

function asFrequency(value: string | null): RecurrenceFrequency | null {
  if (value === "daily" || value === "weekly" || value === "monthly") {
    return value;
  }
  return null;
}

function asStored(event: {
  id: string;
  userId: string;
  title: string;
  description: string | null;
  startsAt: Date;
  endsAt: Date | null;
  category: string;
  priority: string;
  recurrenceFrequency: string | null;
  recurrenceInterval: number;
  recurrenceWeekdays: number[];
  recurrenceUntil: Date | null;
  recurrenceCount: number | null;
  recurrenceOffsetMinutes: number | null;
  version: number;
  reminderMinutes: number | null;
  createdAt: Date;
  updatedAt: Date;
}): StoredEvent {
  return {
    ...event,
    category: event.category as EventCategory,
    priority: event.priority as EventPriority,
    recurrenceFrequency: asFrequency(event.recurrenceFrequency),
  };
}

function asException(exception: {
  id: string;
  eventId: string;
  originalStart: Date;
  excluded: boolean;
  title: string | null;
  description: string | null;
  startsAt: Date | null;
  endsAt: Date | null;
  category: string | null;
  priority: string | null;
}): StoredException {
  return {
    ...exception,
    category: exception.category as EventCategory | null,
    priority: exception.priority as EventPriority | null,
  };
}

export class PrismaEventRepository implements EventRepository {
  async create(input: EventDraft): Promise<StoredEvent> {
    const { id, ...fields } = input;
    const created = await getPrismaClient().event.create({
      data: id === undefined ? fields : { ...fields, id },
    });
    return asStored(created);
  }

  async listByOwner(userId: string): Promise<StoredEvent[]> {
    const events = await getPrismaClient().event.findMany({
      where: { userId },
      orderBy: [{ startsAt: "asc" }, { id: "asc" }],
    });
    return events.map(asStored);
  }

  async findOwned(id: string, userId: string): Promise<StoredEvent | null> {
    const event = await getPrismaClient().event.findFirst({ where: { id, userId } });
    return event ? asStored(event) : null;
  }

  async update(id: string, userId: string, patch: EventPatch): Promise<StoredEvent | null> {
    const result = await getPrismaClient().event.updateMany({
      where: { id, userId },
      data: patch,
    });
    if (result.count === 0) {
      return null;
    }
    const updated = await getPrismaClient().event.findFirst({ where: { id, userId } });
    return updated ? asStored(updated) : null;
  }

  async delete(id: string, userId: string): Promise<boolean> {
    const result = await getPrismaClient().event.deleteMany({ where: { id, userId } });
    return result.count === 1;
  }

  async listExceptions(userId: string): Promise<StoredException[]> {
    const rows = await getPrismaClient().eventException.findMany({
      where: { event: { userId } },
    });
    return rows.map(asException);
  }

  async saveException(userId: string, input: ExceptionDraft): Promise<boolean> {
    const owned = await getPrismaClient().event.findFirst({
      where: { id: input.eventId, userId },
      select: { id: true },
    });
    if (!owned) {
      return false;
    }
    await getPrismaClient().eventException.upsert({
      where: {
        eventId_originalStart: { eventId: input.eventId, originalStart: input.originalStart },
      },
      create: input,
      update: {
        excluded: input.excluded,
        title: input.title,
        description: input.description,
        startsAt: input.startsAt,
        endsAt: input.endsAt,
        category: input.category,
        priority: input.priority,
      },
    });
    return true;
  }

  async clearExceptions(id: string, userId: string): Promise<void> {
    await getPrismaClient().eventException.deleteMany({
      where: { eventId: id, event: { userId } },
    });
  }

  async findTombstone(id: string, userId: string) {
    return getPrismaClient().eventTombstone.findFirst({ where: { id, userId } });
  }

  async addTombstone(input: { id: string; userId: string; version: number }): Promise<void> {
    await getPrismaClient().eventTombstone.create({ data: input });
  }

  async listTombstones(userId: string) {
    return getPrismaClient().eventTombstone.findMany({ where: { userId } });
  }
}
