import request from "supertest";
import { TokenService } from "../src/auth/tokens.js";
import { createApp } from "../src/app.js";
import { MemoryEventRepository } from "./memory-event-repository.js";

const jwtSecret = "test-jwt-secret-with-32-characters";
const eventId = "11111111-1111-4111-8111-111111111111";

const validEvent = {
  id: eventId,
  title: "Entrega",
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

describe("event sync", () => {
  it("replays the same client id without creating a second event", async () => {
    const { app, events, alice } = await createTestApp();
    const first = await request(app)
      .post("/api/events")
      .set("Authorization", `Bearer ${alice}`)
      .send(validEvent);
    const second = await request(app)
      .post("/api/events")
      .set("Authorization", `Bearer ${alice}`)
      .send(validEvent);

    expect(first.status).toBe(201);
    expect(second.status).toBe(200);
    expect(second.body.id).toBe(eventId);
    expect(events.events).toHaveLength(1);
  });

  it("rejects a stale version and returns the server event", async () => {
    const { app, alice } = await createTestApp();
    await request(app).post("/api/events").set("Authorization", `Bearer ${alice}`).send(validEvent);
    const updated = await request(app)
      .patch(`/api/events/${eventId}`)
      .set("Authorization", `Bearer ${alice}`)
      .send({ title: "Versión nueva", baseVersion: 1 });
    const stale = await request(app)
      .patch(`/api/events/${eventId}`)
      .set("Authorization", `Bearer ${alice}`)
      .send({ title: "Versión vieja", baseVersion: 1 });

    expect(updated.status).toBe(200);
    expect(updated.body.version).toBe(2);
    expect(stale.status).toBe(409);
    expect(stale.body.error.code).toBe("CONFLICT");
    expect(stale.body.server.title).toBe("Versión nueva");
    expect(stale.body.server.version).toBe(2);
  });

  it("keeps a deleted id from coming back", async () => {
    const { app, events, alice } = await createTestApp();
    await request(app).post("/api/events").set("Authorization", `Bearer ${alice}`).send(validEvent);
    const removed = await request(app)
      .delete(`/api/events/${eventId}`)
      .query({ baseVersion: 1 })
      .set("Authorization", `Bearer ${alice}`);
    const revived = await request(app)
      .post("/api/events")
      .set("Authorization", `Bearer ${alice}`)
      .send(validEvent);
    const snapshot = await request(app).get("/api/events/sync").set("Authorization", `Bearer ${alice}`);

    expect(removed.status).toBe(204);
    expect(revived.status).toBe(409);
    expect(events.events).toHaveLength(0);
    expect(snapshot.body.tombstones).toEqual([
      expect.objectContaining({ id: eventId, version: 1 }),
    ]);
  });

  it("does not expose another user's snapshot", async () => {
    const { app, alice, bob } = await createTestApp();
    await request(app).post("/api/events").set("Authorization", `Bearer ${alice}`).send(validEvent);
    const foreign = await request(app).get("/api/events/sync").set("Authorization", `Bearer ${bob}`);

    expect(foreign.status).toBe(200);
    expect(foreign.body.events).toEqual([]);
    expect(foreign.body.tombstones).toEqual([]);
  });
});
