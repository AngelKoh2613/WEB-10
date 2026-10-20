import { getPrismaClient } from "../src/data/prisma-client.js";

describe("getPrismaClient", () => {
  const originalUrl = process.env.DATABASE_URL;

  afterEach(() => {
    if (originalUrl === undefined) {
      delete process.env.DATABASE_URL;
    } else {
      process.env.DATABASE_URL = originalUrl;
    }
  });

  it("does not construct a client when DATABASE_URL is missing", () => {
    delete process.env.DATABASE_URL;

    expect(() => getPrismaClient()).toThrow("DATABASE_URL is not configured");
  });
});
