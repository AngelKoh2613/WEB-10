import { jest } from "@jest/globals";
import request from "supertest";

jest.setTimeout(30000);
import { TokenService } from "../src/auth/tokens.js";
import { isUniqueConstraintError } from "../src/auth/user-repository.js";
import { createApp } from "../src/app.js";
import { MemoryUserRepository } from "./memory-user-repository.js";

const jwtSecret = "test-jwt-secret-with-32-characters";
const password = "CorrectHorse1";

function createTestApp(options?: {
  users?: MemoryUserRepository;
  rateLimit?: { limit: number; windowMs: number };
}) {
  const users = options?.users ?? new MemoryUserRepository();
  const app = createApp({
    users,
    jwtSecret,
    rateLimit: options?.rateLimit,
  });
  return { app, users };
}

describe("authentication", () => {
  it("registers a user and never returns the password hash", async () => {
    const { app, users } = createTestApp();

    const response = await request(app).post("/api/auth/register").send({
      email: "Ana@Example.com",
      password,
    });

    expect(response.status).toBe(201);
    expect(response.body.user).toEqual({
      id: users.users[0]?.id,
      email: "ana@example.com",
    });
    expect(response.body.accessToken).toEqual(expect.any(String));
    expect(response.body.expiresAt).toEqual(expect.any(String));
    expect(JSON.stringify(response.body)).not.toContain(password);
    expect(JSON.stringify(response.body)).not.toContain("passwordHash");
    expect(users.users[0]?.passwordHash.startsWith("$argon2id$")).toBe(true);
    expect(users.users[0]?.passwordHash).not.toBe(password);
  });

  it("rejects an invalid email and a weak password", async () => {
    const { app } = createTestApp();

    const invalidEmail = await request(app).post("/api/auth/register").send({
      email: "not-an-email",
      password,
    });
    const weakPassword = await request(app).post("/api/auth/register").send({
      email: "ana@example.com",
      password: "short",
    });

    expect(invalidEmail.status).toBe(400);
    expect(invalidEmail.body.error.code).toBe("VALIDATION_ERROR");
    expect(weakPassword.status).toBe(400);
    expect(weakPassword.body.error.code).toBe("VALIDATION_ERROR");
    expect(JSON.stringify(weakPassword.body)).not.toContain("short");
  });

  it("rejects a duplicate email without echoing the address", async () => {
    const { app } = createTestApp();
    await request(app).post("/api/auth/register").send({
      email: "ana@example.com",
      password,
    });

    const duplicate = await request(app).post("/api/auth/register").send({
      email: "ANA@example.com",
      password,
    });

    expect(duplicate.status).toBe(409);
    expect(duplicate.body).toEqual({
      error: {
        code: "CONFLICT",
        message: "No se pudo completar el registro",
      },
    });
    expect(JSON.stringify(duplicate.body)).not.toContain("ana@example.com");
  });

  it("logs in with normalized email and rejects unknown users and bad passwords the same way", async () => {
    const { app } = createTestApp();
    await request(app).post("/api/auth/register").send({
      email: "ana@example.com",
      password,
    });

    const success = await request(app).post("/api/auth/login").send({
      email: " Ana@Example.com ",
      password,
    });
    const unknown = await request(app).post("/api/auth/login").send({
      email: "missing@example.com",
      password,
    });
    const wrongPassword = await request(app).post("/api/auth/login").send({
      email: "ana@example.com",
      password: "WrongPassword1",
    });

    expect(success.status).toBe(200);
    expect(success.body.user.email).toBe("ana@example.com");
    expect(unknown.status).toBe(401);
    expect(wrongPassword.status).toBe(401);
    expect(unknown.body).toEqual(wrongPassword.body);
    expect(unknown.body.error.code).toBe("INVALID_CREDENTIALS");
  });

  it("rejects expired and malformed tokens and protects the session route", async () => {
    const { app, users } = createTestApp();
    const registered = await request(app).post("/api/auth/register").send({
      email: "ana@example.com",
      password,
    });
    const tokens = new TokenService(jwtSecret);
    const expired = await tokens.sign(
      users.users[0]?.id ?? "missing",
      Math.floor(Date.now() / 1000) - 10,
    );

    const missing = await request(app).get("/api/auth/session");
    const malformed = await request(app)
      .get("/api/auth/session")
      .set("Authorization", "Bearer not-a-token");
    const expiredResponse = await request(app)
      .get("/api/auth/session")
      .set("Authorization", `Bearer ${expired.accessToken}`);
    const current = await request(app)
      .get("/api/auth/session")
      .set("Authorization", `Bearer ${registered.body.accessToken}`);

    expect(missing.status).toBe(401);
    expect(malformed.status).toBe(401);
    expect(expiredResponse.status).toBe(401);
    expect(malformed.body).toEqual(expiredResponse.body);
    expect(current.status).toBe(200);
    expect(current.body).toEqual({ userId: users.users[0]?.id });
  });

  it("accepts logout without revoking the access token on the server", async () => {
    const { app } = createTestApp();
    const registered = await request(app).post("/api/auth/register").send({
      email: "ana@example.com",
      password,
    });
    const token = registered.body.accessToken as string;

    const logout = await request(app)
      .post("/api/auth/logout")
      .set("Authorization", `Bearer ${token}`);
    const session = await request(app)
      .get("/api/auth/session")
      .set("Authorization", `Bearer ${token}`);

    expect(logout.status).toBe(204);
    expect(logout.text).toBe("");
    expect(session.status).toBe(200);
  });

  it("limits repeated authentication attempts", async () => {
    const { app } = createTestApp({ rateLimit: { limit: 2, windowMs: 60_000 } });

    await request(app).post("/api/auth/login").send({ email: "ana@example.com", password });
    await request(app).post("/api/auth/login").send({ email: "ana@example.com", password });
    const limited = await request(app).post("/api/auth/login").send({
      email: "ana@example.com",
      password,
    });

    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe("TOO_MANY_REQUESTS");
  });

  it("hides unexpected repository failures", async () => {
    const users = new MemoryUserRepository();
    users.failOnCreate = new Error("password=secret connection failed");
    const { app } = createTestApp({ users });

    const response = await request(app).post("/api/auth/register").send({
      email: "ana@example.com",
      password,
    });

    expect(response.status).toBe(500);
    expect(response.body.error.code).toBe("INTERNAL_ERROR");
    expect(JSON.stringify(response.body)).not.toContain("secret");
  });

  it("recognizes a PostgreSQL unique violation without opening a database", () => {
    expect(isUniqueConstraintError({ code: "P2002" })).toBe(true);
    expect(isUniqueConstraintError(new Error("duplicate"))).toBe(false);
  });
});
