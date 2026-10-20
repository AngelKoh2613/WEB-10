import request from "supertest";
import { TokenService } from "../src/auth/tokens.js";
import { createApp } from "../src/app.js";
import { MemoryEventRepository } from "./memory-event-repository.js";

const jwtSecret = "test-jwt-secret-with-32-characters";

const validEvent = {
  title: "Revisión del proyecto",
  description: "Preparar la demostración",
  startsAt: "2026-10-13T15:00:00.000Z",
  endsAt: "2026-10-13T16:00:00.000Z",
  category: "estudio",
  priority: "high",
};

async function createTestApp() {
  const events = new MemoryEventRepository();
  const tokens = new TokenService(jwtSecret);
  const alice = await tokens.sign("alice-id");
  const bob = await tokens.sign("bob-id");
  const app = createApp({ events, jwtSecret });
  return { app, events, alice: alice.accessToken, bob: bob.accessToken };
}

describe("events", () => {
  it("creates a valid event owned by the authenticated user", async () => {
    const { app, events, alice } = await createTestApp();

    const response = await request(app)
      .post("/api/events")
      .set("Authorization", `Bearer ${alice}`)
      .send({ ...validEvent, userId: "bob-id" });

    expect(response.status).toBe(400);
    expect(events.events).toHaveLength(0);

    const created = await request(app)
      .post("/api/events")
      .set("Authorization", `Bearer ${alice}`)
      .send(validEvent);

    expect(created.status).toBe(201);
    expect(created.body.userId).toBeUndefined();
    expect(created.body.title).toBe("Revisión del proyecto");
    expect(created.body.category).toBe("estudio");
    expect(created.body.priority).toBe("high");
    expect(created.body.id).toEqual(expect.any(String));
    expect(events.events[0]?.userId).toBe("alice-id");
    expect(JSON.stringify(created.body)).not.toContain("alice-id");
  });

  it("rejects invalid titles, categories, priorities and intervals", async () => {
    const { app, alice } = await createTestApp();
    const auth = { Authorization: `Bearer ${alice}` };

    const emptyTitle = await request(app)
      .post("/api/events")
      .set(auth)
      .send({
        ...validEvent,
        title: "   ",
      });
    const longDescription = await request(app)
      .post("/api/events")
      .set(auth)
      .send({ ...validEvent, description: "x".repeat(4001) });
    const badCategory = await request(app)
      .post("/api/events")
      .set(auth)
      .send({
        ...validEvent,
        category: "urgente",
      });
    const badPriority = await request(app)
      .post("/api/events")
      .set(auth)
      .send({
        ...validEvent,
        priority: "urgent",
      });
    const backwards = await request(app)
      .post("/api/events")
      .set(auth)
      .send({
        ...validEvent,
        endsAt: "2026-10-13T14:00:00.000Z",
      });
    const sameInstant = await request(app)
      .post("/api/events")
      .set(auth)
      .send({
        ...validEvent,
        endsAt: validEvent.startsAt,
      });
    const localDate = await request(app)
      .post("/api/events")
      .set(auth)
      .send({
        ...validEvent,
        startsAt: "2026-10-13T15:00:00",
      });

    for (const response of [
      emptyTitle,
      longDescription,
      badCategory,
      badPriority,
      backwards,
      sameInstant,
      localDate,
    ]) {
      expect(response.status).toBe(400);
      expect(response.body.error.code).toBe("VALIDATION_ERROR");
    }
  });

  it("lists, reads, updates and deletes only the authenticated user's events", async () => {
    const { app, alice, bob } = await createTestApp();
    const created = await request(app)
      .post("/api/events")
      .set("Authorization", `Bearer ${alice}`)
      .send(validEvent);
    const id = created.body.id as string;

    await request(app)
      .post("/api/events")
      .set("Authorization", `Bearer ${bob}`)
      .send({ ...validEvent, title: "Evento de Bob" });

    const aliceList = await request(app).get("/api/events").set("Authorization", `Bearer ${alice}`);
    const bobList = await request(app).get("/api/events").set("Authorization", `Bearer ${bob}`);
    const aliceRead = await request(app)
      .get(`/api/events/${id}`)
      .set("Authorization", `Bearer ${alice}`);
    const bobRead = await request(app)
      .get(`/api/events/${id}`)
      .set("Authorization", `Bearer ${bob}`);
    const bobUpdate = await request(app)
      .patch(`/api/events/${id}`)
      .set("Authorization", `Bearer ${bob}`)
      .send({ title: "Tomado", baseVersion: 1 });
    const bobDelete = await request(app)
      .delete(`/api/events/${id}`)
      .query({ baseVersion: 1 })
      .set("Authorization", `Bearer ${bob}`);
    const aliceUpdate = await request(app)
      .patch(`/api/events/${id}`)
      .set("Authorization", `Bearer ${alice}`)
      .send({ title: "Revisión actualizada", priority: "medium", baseVersion: 1 });
    const missing = await request(app)
      .get("/api/events/00000000-0000-4000-8000-000000000000")
      .set("Authorization", `Bearer ${alice}`);
    const aliceDelete = await request(app)
      .delete(`/api/events/${id}`)
      .query({ baseVersion: 2 })
      .set("Authorization", `Bearer ${alice}`);
    const afterDelete = await request(app)
      .get(`/api/events/${id}`)
      .set("Authorization", `Bearer ${alice}`);

    expect(aliceList.status).toBe(200);
    expect(aliceList.body.events.map((event: { title: string }) => event.title)).toEqual([
      "Revisión del proyecto",
    ]);
    expect(bobList.body.events.map((event: { title: string }) => event.title)).toEqual([
      "Evento de Bob",
    ]);
    expect(aliceRead.status).toBe(200);
    expect(aliceRead.body.title).toBe("Revisión del proyecto");
    expect(bobRead.status).toBe(404);
    expect(bobUpdate.status).toBe(404);
    expect(bobDelete.status).toBe(404);
    expect(bobRead.body).toEqual(bobUpdate.body);
    expect(JSON.stringify(bobRead.body)).not.toContain("Revisión del proyecto");
    expect(aliceUpdate.status).toBe(200);
    expect(aliceUpdate.body.title).toBe("Revisión actualizada");
    expect(aliceUpdate.body.priority).toBe("medium");
    expect(missing.status).toBe(404);
    expect(missing.body.error.code).toBe("NOT_FOUND");
    expect(aliceDelete.status).toBe(204);
    expect(afterDelete.status).toBe(404);
  });

  it("rejects anonymous requests and a malformed identifier", async () => {
    const { app, alice } = await createTestApp();

    const missingToken = await request(app).get("/api/events");
    const badToken = await request(app)
      .post("/api/events")
      .set("Authorization", "Bearer no-token")
      .send(validEvent);
    const badId = await request(app)
      .get("/api/events/not-a-uuid")
      .set("Authorization", `Bearer ${alice}`);

    expect(missingToken.status).toBe(401);
    expect(missingToken.body.error.code).toBe("UNAUTHENTICATED");
    expect(badToken.status).toBe(401);
    expect(badId.status).toBe(400);
    expect(badId.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("expands a series and keeps occurrence edits separate from the series", async () => {
    const { app, alice, bob } = await createTestApp();
    const created = await request(app)
      .post("/api/events")
      .set("Authorization", `Bearer ${alice}`)
      .send({
        ...validEvent,
        startsAt: "2026-10-13T15:00:00.000Z",
        endsAt: "2026-10-13T16:00:00.000Z",
        recurrence: {
          frequency: "daily",
          interval: 1,
          count: 3,
          offsetMinutes: 0,
        },
      });
    const id = created.body.id as string;
    const listed = await request(app)
      .get("/api/events")
      .query({ from: "2026-10-13T00:00:00.000Z", to: "2026-10-16T00:00:00.000Z" })
      .set("Authorization", `Bearer ${alice}`);
    const second = "2026-10-14T15:00:00.000Z";
    const edited = await request(app)
      .patch(`/api/events/${id}`)
      .set("Authorization", `Bearer ${alice}`)
      .send({
        scope: "occurrence",
        occurrenceStart: second,
        title: "Solo el jueves",
        baseVersion: 1,
      });
    const afterEdit = await request(app)
      .get("/api/events")
      .query({ from: "2026-10-13T00:00:00.000Z", to: "2026-10-16T00:00:00.000Z" })
      .set("Authorization", `Bearer ${alice}`);
    const seriesEdit = await request(app)
      .patch(`/api/events/${id}`)
      .set("Authorization", `Bearer ${alice}`)
      .send({ scope: "series", title: "Toda la serie", baseVersion: 2 });
    const excluded = await request(app)
      .delete(`/api/events/${id}`)
      .query({
        scope: "occurrence",
        occurrenceStart: "2026-10-13T15:00:00.000Z",
        baseVersion: 3,
      })
      .set("Authorization", `Bearer ${alice}`);
    const afterExclude = await request(app)
      .get("/api/events")
      .query({ from: "2026-10-13T00:00:00.000Z", to: "2026-10-16T00:00:00.000Z" })
      .set("Authorization", `Bearer ${alice}`);
    const foreign = await request(app)
      .patch(`/api/events/${id}`)
      .query({ scope: "series" })
      .set("Authorization", `Bearer ${bob}`)
      .send({ scope: "series", title: "Ajeno", baseVersion: 4 });
    const removed = await request(app)
      .delete(`/api/events/${id}`)
      .query({ scope: "series", baseVersion: 4 })
      .set("Authorization", `Bearer ${alice}`);
    const afterSeriesDelete = await request(app)
      .get("/api/events")
      .query({ from: "2026-10-13T00:00:00.000Z", to: "2026-10-16T00:00:00.000Z" })
      .set("Authorization", `Bearer ${alice}`);

    expect(created.status).toBe(201);
    expect(created.body.recurrence.frequency).toBe("daily");
    expect(listed.status).toBe(200);
    expect(listed.body.events.map((event: { startsAt: string }) => event.startsAt)).toEqual([
      "2026-10-13T15:00:00.000Z",
      "2026-10-14T15:00:00.000Z",
      "2026-10-15T15:00:00.000Z",
    ]);
    expect(edited.status).toBe(200);
    expect(edited.body.title).toBe("Solo el jueves");
    expect(afterEdit.body.events.map((event: { title: string }) => event.title)).toEqual([
      "Revisión del proyecto",
      "Solo el jueves",
      "Revisión del proyecto",
    ]);
    expect(seriesEdit.status).toBe(200);
    expect(seriesEdit.body.title).toBe("Toda la serie");
    expect(excluded.status).toBe(204);
    expect(afterExclude.body.events.map((event: { startsAt: string }) => event.startsAt)).toEqual([
      "2026-10-14T15:00:00.000Z",
      "2026-10-15T15:00:00.000Z",
    ]);
    expect(afterExclude.body.events.every((event: { title: string }) => event.title === "Toda la serie")).toBe(
      true,
    );
    expect(foreign.status).toBe(404);
    expect(JSON.stringify(foreign.body)).not.toContain("Toda la serie");
    expect(removed.status).toBe(204);
    expect(afterSeriesDelete.body.events).toEqual([]);
  });

  it("rejects incoherent recurrence and an excessive range", async () => {
    const { app, alice } = await createTestApp();
    const auth = { Authorization: `Bearer ${alice}` };
    const bothLimits = await request(app)
      .post("/api/events")
      .set(auth)
      .send({
        ...validEvent,
        recurrence: {
          frequency: "daily",
          interval: 1,
          count: 2,
          until: "2026-10-20T15:00:00.000Z",
          offsetMinutes: 0,
        },
      });
    const missingScope = await request(app)
      .post("/api/events")
      .set(auth)
      .send({
        ...validEvent,
        recurrence: { frequency: "weekly", interval: 1, weekdays: [2], count: 2, offsetMinutes: 0 },
      });
    const created = missingScope.status === 201 ? missingScope.body.id : "";
    const silent = await request(app)
      .patch(`/api/events/${created}`)
      .set(auth)
      .send({ title: "Sin alcance", baseVersion: 1 });
    const silentDelete = await request(app)
      .delete(`/api/events/${created}`)
      .query({ baseVersion: 1 })
      .set(auth);
    const huge = await request(app)
      .get("/api/events")
      .query({ from: "2026-01-01T00:00:00.000Z", to: "2026-06-01T00:00:00.000Z" })
      .set(auth);

    expect(bothLimits.status).toBe(400);
    expect(missingScope.status).toBe(201);
    expect(silent.status).toBe(400);
    expect(silentDelete.status).toBe(400);
    expect(silent.body.error.message).toBe(
      "Indica si el cambio es solo de este evento o de toda la serie",
    );
    expect(huge.status).toBe(400);
  });
});
