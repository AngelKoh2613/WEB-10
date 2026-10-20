import { randomUUID } from "node:crypto";
import { jest } from "@jest/globals";
import { config as loadDotenv } from "dotenv";
import request from "supertest";
import { PrismaUserRepository } from "../src/auth/prisma-user-repository.js";
import { disconnectPrisma, getPrismaClient } from "../src/data/prisma-client.js";
import { PrismaEventRepository } from "../src/events/prisma-event-repository.js";
import { createApp } from "../src/app.js";

const enabled = process.env.RUN_DB_INTEGRATION === "1";
const describeDb = enabled ? describe : describe.skip;

describeDb("postgres persistence", () => {
  jest.setTimeout(30000);

  const password = "CorrectHorse1";
  const emailA = `phase1-a-${randomUUID()}@secureplan.test`;
  const emailB = `phase1-b-${randomUUID()}@secureplan.test`;
  let app: ReturnType<typeof createApp>;

  beforeAll(() => {
    loadDotenv({ override: true, quiet: true });
    const secret = process.env.JWT_SECRET;
    if (!process.env.DATABASE_URL || secret === undefined || secret.length < 32) {
      throw new Error("Database integration is not configured");
    }
    app = createApp({
      users: new PrismaUserRepository(),
      events: new PrismaEventRepository(),
      jwtSecret: secret,
    });
  });

  afterAll(async () => {
    const prisma = getPrismaClient();
    await prisma.user.deleteMany({
      where: { email: { in: [emailA, emailB] } },
    });
    await disconnectPrisma();
  });

  it("persists register, login and event changes, and hides another user's event", async () => {
    const registered = await request(app).post("/api/auth/register").send({
      email: emailA,
      password,
    });

    expect(registered.status).toBe(201);
    expect(JSON.stringify(registered.body)).not.toContain(password);
    expect(JSON.stringify(registered.body)).not.toContain("passwordHash");
    expect(registered.body.user.email).toBe(emailA);

    const stored = await getPrismaClient().user.findUnique({ where: { email: emailA } });
    expect(stored?.passwordHash.startsWith("$argon2id$")).toBe(true);
    expect(stored?.passwordHash).not.toBe(password);

    const login = await request(app).post("/api/auth/login").send({
      email: emailA,
      password,
    });
    expect(login.status).toBe(200);
    const tokenA = login.body.accessToken as string;
    expect(tokenA.split(".").length).toBe(3);

    const created = await request(app)
      .post("/api/events")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        title: "Persistencia fase 1",
        description: "Registro temporal de desarrollo",
        startsAt: "2026-10-14T15:00:00.000Z",
        endsAt: "2026-10-14T16:00:00.000Z",
        category: "estudio",
        priority: "medium",
      });
    expect(created.status).toBe(201);
    const eventId = created.body.id as string;

    const listed = await request(app).get("/api/events").set("Authorization", `Bearer ${tokenA}`);
    expect(listed.status).toBe(200);
    expect(listed.body.events.map((event: { id: string }) => event.id)).toContain(eventId);

    const updated = await request(app)
      .patch(`/api/events/${eventId}`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ title: "Persistencia actualizada", baseVersion: 1 });
    expect(updated.status).toBe(200);

    const row = await getPrismaClient().event.findFirst({
      where: { id: eventId, userId: stored?.id },
    });
    expect(row?.title).toBe("Persistencia actualizada");

    const other = await request(app).post("/api/auth/register").send({
      email: emailB,
      password,
    });
    const otherToken = other.body.accessToken as string;
    const forbiddenRead = await request(app)
      .get(`/api/events/${eventId}`)
      .set("Authorization", `Bearer ${otherToken}`);
    const forbiddenUpdate = await request(app)
      .patch(`/api/events/${eventId}`)
      .set("Authorization", `Bearer ${otherToken}`)
      .send({ title: "Ajeno", baseVersion: 1 });
    const forbiddenDelete = await request(app)
      .delete(`/api/events/${eventId}`)
      .query({ baseVersion: 1 })
      .set("Authorization", `Bearer ${otherToken}`);

    expect(forbiddenRead.status).toBe(404);
    expect(forbiddenUpdate.status).toBe(404);
    expect(forbiddenDelete.status).toBe(404);
    expect(JSON.stringify(forbiddenRead.body)).not.toContain("Persistencia");

    const removed = await request(app)
      .delete(`/api/events/${eventId}`)
      .query({ baseVersion: 2 })
      .set("Authorization", `Bearer ${tokenA}`);
    expect(removed.status).toBe(204);

    const afterDelete = await request(app)
      .get(`/api/events/${eventId}`)
      .set("Authorization", `Bearer ${tokenA}`);
    expect(afterDelete.status).toBe(404);
    const remaining = await getPrismaClient().event.findFirst({ where: { id: eventId } });
    expect(remaining).toBeNull();
  });

  it("stores one monthly series and persists occurrence changes", async () => {
    const login = await request(app).post("/api/auth/login").send({ email: emailA, password });
    const token = login.body.accessToken as string;
    const other = await request(app).post("/api/auth/login").send({ email: emailB, password });
    const otherToken = other.body.accessToken as string;
    const created = await request(app)
      .post("/api/events")
      .set("Authorization", `Bearer ${token}`)
      .send({
        title: "Cierre de mes",
        startsAt: "2024-01-31T15:00:00.000Z",
        endsAt: "2024-01-31T16:00:00.000Z",
        category: "trabajo",
        priority: "high",
        recurrence: { frequency: "monthly", interval: 1, count: 3, offsetMinutes: 0 },
      });
    const id = created.body.id as string;
    const february = await request(app)
      .get("/api/events")
      .query({ from: "2024-02-01T00:00:00.000Z", to: "2024-03-01T00:00:00.000Z" })
      .set("Authorization", `Bearer ${token}`);
    const march = await request(app)
      .get("/api/events")
      .query({ from: "2024-03-01T00:00:00.000Z", to: "2024-04-01T00:00:00.000Z" })
      .set("Authorization", `Bearer ${token}`);
    const edited = await request(app)
      .patch(`/api/events/${id}`)
      .set("Authorization", `Bearer ${token}`)
      .send({
        scope: "occurrence",
        occurrenceStart: "2024-03-31T15:00:00.000Z",
        title: "Cierre movido",
        baseVersion: 1,
      });
    const marchAgain = await request(app)
      .get("/api/events")
      .query({ from: "2024-03-01T00:00:00.000Z", to: "2024-04-01T00:00:00.000Z" })
      .set("Authorization", `Bearer ${token}`);
    const may = await request(app)
      .get("/api/events")
      .query({ from: "2024-05-01T00:00:00.000Z", to: "2024-06-01T00:00:00.000Z" })
      .set("Authorization", `Bearer ${token}`);
    const hidden = await request(app)
      .delete(`/api/events/${id}`)
      .query({
        scope: "occurrence",
        occurrenceStart: "2024-03-31T15:00:00.000Z",
        baseVersion: 2,
      })
      .set("Authorization", `Bearer ${otherToken}`);
    const removed = await request(app)
      .delete(`/api/events/${id}`)
      .query({ scope: "series", baseVersion: 2 })
      .set("Authorization", `Bearer ${token}`);
    const row = await getPrismaClient().event.findFirst({ where: { id } });
    const exceptions = await getPrismaClient().eventException.count({ where: { eventId: id } });

    expect(created.status).toBe(201);
    expect(february.body.events).toEqual([]);
    expect(march.body.events.map((event: { startsAt: string }) => event.startsAt)).toEqual([
      "2024-03-31T15:00:00.000Z",
    ]);
    expect(edited.status).toBe(200);
    expect(marchAgain.body.events[0].title).toBe("Cierre movido");
    expect(may.body.events[0].title).toBe("Cierre de mes");
    expect(hidden.status).toBe(404);
    expect(removed.status).toBe(204);
    expect(row).toBeNull();
    expect(exceptions).toBe(0);
  });
});
