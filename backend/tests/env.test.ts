import { loadEnv } from "../src/config/env.js";

describe("loadEnv", () => {
  it("applies defaults when optional values are absent", () => {
    expect(loadEnv({})).toEqual({
      NODE_ENV: "development",
      PORT: 3000,
    });
  });

  it("rejects a port outside the valid range", () => {
    expect(() => loadEnv({ PORT: "70000" })).toThrow("Invalid environment configuration");
  });

  it("treats an empty database url as unset", () => {
    expect(loadEnv({ DATABASE_URL: "" }).DATABASE_URL).toBeUndefined();
  });

  it("rejects a JWT secret shorter than 32 characters", () => {
    expect(() => loadEnv({ JWT_SECRET: "too-short" })).toThrow("Invalid environment configuration");
  });
});
