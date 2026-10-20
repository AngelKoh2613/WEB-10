import request from "supertest";
import { createApp } from "../src/app.js";

describe("infrastructure routes", () => {
  const app = createApp();

  it("GET /health returns the service status", async () => {
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      status: "ok",
      service: "secureplan-api",
    });
    expect(response.headers["x-powered-by"]).toBeUndefined();
    expect(response.headers["x-content-type-options"]).toBe("nosniff");
    expect(response.headers["x-frame-options"]).toBe("DENY");
    expect(response.headers["referrer-policy"]).toBe("no-referrer");
    expect(response.headers["content-security-policy"]).toBe("default-src 'none'");
  });

  it("unknown routes return the error envelope", async () => {
    const response = await request(app).get("/api/v1/events");

    expect(response.status).toBe(404);
    expect(response.headers["x-content-type-options"]).toBe("nosniff");
    expect(response.body).toEqual({
      error: {
        code: "NOT_FOUND",
        message: "Route not found",
      },
    });
  });
});
