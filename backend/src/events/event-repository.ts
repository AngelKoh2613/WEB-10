import type { RecurrenceFrequency } from "./recurrence.js";

export const eventCategories = ["personal", "trabajo", "estudio", "otro"] as const;
export const eventPriorities = ["low", "medium", "high"] as const;

export type EventCategory = (typeof eventCategories)[number];
export type EventPriority = (typeof eventPriorities)[number];

export type StoredEvent = {
  id: string;
  userId: string;
  title: string;
  description: string | null;
  startsAt: Date;
  endsAt: Date | null;
  category: EventCategory;
  priority: EventPriority;
  recurrenceFrequency: RecurrenceFrequency | null;
  recurrenceInterval: number;
  recurrenceWeekdays: number[];
  recurrenceUntil: Date | null;
  recurrenceCount: number | null;
  recurrenceOffsetMinutes: number | null;
  version: number;
  reminderMinutes: number | null;
  createdAt: Date;
  updatedAt: Date;
};

export type EventDraft = {
  id?: string;
  userId: string;
  title: string;
  description: string | null;
  startsAt: Date;
  endsAt: Date | null;
  category: EventCategory;
  priority: EventPriority;
  recurrenceFrequency: RecurrenceFrequency | null;
  recurrenceInterval: number;
  recurrenceWeekdays: number[];
  recurrenceUntil: Date | null;
  recurrenceCount: number | null;
  recurrenceOffsetMinutes: number | null;
  reminderMinutes: number | null;
};

export type EventPatch = Partial<Omit<EventDraft, "userId" | "id">> & {
  version?: number;
};

export type StoredException = {
  id: string;
  eventId: string;
  originalStart: Date;
  excluded: boolean;
  title: string | null;
  description: string | null;
  startsAt: Date | null;
  endsAt: Date | null;
  category: EventCategory | null;
  priority: EventPriority | null;
};

export type ExceptionDraft = Omit<StoredException, "id">;

export type OccurrenceView = {
  originalStart: Date;
  startsAt: Date;
  endsAt: Date | null;
  title: string;
  description: string | null;
  category: EventCategory;
  priority: EventPriority;
};

export type StoredTombstone = {
  id: string;
  userId: string;
  version: number;
  deletedAt: Date;
};

export type EventRepository = {
  create(input: EventDraft): Promise<StoredEvent>;
  listByOwner(userId: string): Promise<StoredEvent[]>;
  findOwned(id: string, userId: string): Promise<StoredEvent | null>;
  update(id: string, userId: string, patch: EventPatch): Promise<StoredEvent | null>;
  delete(id: string, userId: string): Promise<boolean>;
  listExceptions(userId: string): Promise<StoredException[]>;
  saveException(userId: string, input: ExceptionDraft): Promise<boolean>;
  clearExceptions(id: string, userId: string): Promise<void>;
  findTombstone(id: string, userId: string): Promise<StoredTombstone | null>;
  addTombstone(input: { id: string; userId: string; version: number }): Promise<void>;
  listTombstones(userId: string): Promise<StoredTombstone[]>;
};

export function toPublicEvent(event: StoredEvent, view?: OccurrenceView) {
  const shown: OccurrenceView = view ?? {
    originalStart: event.startsAt,
    startsAt: event.startsAt,
    endsAt: event.endsAt,
    title: event.title,
    description: event.description,
    category: event.category,
    priority: event.priority,
  };
  return {
    id: event.id,
    occurrenceStart: shown.originalStart.toISOString(),
    title: shown.title,
    description: shown.description,
    startsAt: shown.startsAt.toISOString(),
    endsAt: shown.endsAt ? shown.endsAt.toISOString() : null,
    category: shown.category,
    priority: shown.priority,
    createdAt: event.createdAt.toISOString(),
    updatedAt: event.updatedAt.toISOString(),
    version: event.version,
    reminderMinutes: event.reminderMinutes,
    recurrence:
      event.recurrenceFrequency === null || event.recurrenceOffsetMinutes === null
        ? null
        : {
            frequency: event.recurrenceFrequency,
            interval: event.recurrenceInterval,
            weekdays: event.recurrenceWeekdays,
            until: event.recurrenceUntil ? event.recurrenceUntil.toISOString() : null,
            count: event.recurrenceCount,
            offsetMinutes: event.recurrenceOffsetMinutes,
          },
  };
}
