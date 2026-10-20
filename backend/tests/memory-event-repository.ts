import { randomUUID } from "node:crypto";
import type {
  EventDraft,
  EventPatch,
  EventRepository,
  ExceptionDraft,
  StoredEvent,
  StoredException,
  StoredTombstone,
} from "../src/events/event-repository.js";

export class MemoryEventRepository implements EventRepository {
  readonly events: StoredEvent[] = [];
  readonly exceptions: StoredException[] = [];
  readonly tombstones: StoredTombstone[] = [];

  async create(input: EventDraft): Promise<StoredEvent> {
    const now = new Date();
    const { id, ...fields } = input;
    const event: StoredEvent = {
      ...fields,
      id: id ?? randomUUID(),
      version: 1,
      createdAt: now,
      updatedAt: now,
    };
    this.events.push(event);
    return event;
  }

  async listByOwner(userId: string): Promise<StoredEvent[]> {
    return this.events
      .filter((event) => event.userId === userId)
      .sort((left, right) => {
        const byStart = left.startsAt.getTime() - right.startsAt.getTime();
        return byStart === 0 ? left.id.localeCompare(right.id) : byStart;
      });
  }

  async findOwned(id: string, userId: string): Promise<StoredEvent | null> {
    return this.events.find((event) => event.id === id && event.userId === userId) ?? null;
  }

  async update(id: string, userId: string, patch: EventPatch): Promise<StoredEvent | null> {
    const event = this.events.find((item) => item.id === id && item.userId === userId);
    if (!event) {
      return null;
    }
    Object.assign(event, patch, { updatedAt: new Date() });
    return event;
  }

  async delete(id: string, userId: string): Promise<boolean> {
    const index = this.events.findIndex((item) => item.id === id && item.userId === userId);
    if (index < 0) {
      return false;
    }
    this.events.splice(index, 1);
    this.exceptions.splice(
      0,
      this.exceptions.length,
      ...this.exceptions.filter((item) => item.eventId !== id),
    );
    return true;
  }

  async listExceptions(userId: string): Promise<StoredException[]> {
    const owned = new Set(this.events.filter((event) => event.userId === userId).map((event) => event.id));
    return this.exceptions.filter((item) => owned.has(item.eventId));
  }

  async saveException(userId: string, input: ExceptionDraft): Promise<boolean> {
    const owned = this.events.some((event) => event.id === input.eventId && event.userId === userId);
    if (!owned) {
      return false;
    }
    const index = this.exceptions.findIndex(
      (item) =>
        item.eventId === input.eventId && item.originalStart.getTime() === input.originalStart.getTime(),
    );
    const row: StoredException = {
      id: index >= 0 ? this.exceptions[index]!.id : randomUUID(),
      ...input,
    };
    if (index >= 0) {
      this.exceptions[index] = row;
    } else {
      this.exceptions.push(row);
    }
    return true;
  }

  async findTombstone(id: string, userId: string): Promise<StoredTombstone | null> {
    return this.tombstones.find((item) => item.id === id && item.userId === userId) ?? null;
  }

  async addTombstone(input: { id: string; userId: string; version: number }): Promise<void> {
    this.tombstones.push({ ...input, deletedAt: new Date() });
  }

  async listTombstones(userId: string): Promise<StoredTombstone[]> {
    return this.tombstones.filter((item) => item.userId === userId);
  }

  async clearExceptions(id: string, userId: string): Promise<void> {
    const owned = this.events.some((event) => event.id === id && event.userId === userId);
    if (!owned) {
      return;
    }
    this.exceptions.splice(
      0,
      this.exceptions.length,
      ...this.exceptions.filter((item) => item.eventId !== id),
    );
  }
}
