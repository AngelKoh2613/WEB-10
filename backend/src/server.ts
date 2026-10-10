import "dotenv/config";
import { PrismaUserRepository } from "./auth/prisma-user-repository.js";
import { PrismaEventRepository } from "./events/prisma-event-repository.js";
import { createApp } from "./app.js";
import { loadEnv } from "./config/env.js";

const env = loadEnv(process.env);

if (
  env.NODE_ENV === "production" &&
  (env.JWT_SECRET === undefined || env.DATABASE_URL === undefined)
) {
  console.error("Authentication configuration is incomplete");
  process.exit(1);
}

const configured = env.DATABASE_URL !== undefined && env.JWT_SECRET !== undefined;

const app = createApp({
  users: configured ? new PrismaUserRepository() : undefined,
  events: configured ? new PrismaEventRepository() : undefined,
  jwtSecret: env.JWT_SECRET,
});

app.listen(env.PORT, () => {
  console.log(`SecurePlan API listening on port ${env.PORT}`);
});
