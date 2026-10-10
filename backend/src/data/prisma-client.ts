import { PrismaPg } from "@prisma/adapter-pg";
import { Pool } from "pg";
import { PrismaClient } from "../generated/prisma/client.js";

let prisma: PrismaClient | undefined;

/**
 * Lazy singleton for the Prisma client.
 * The server entrypoint does not call this function, so booting the API
 * does not open a database connection.
 */
export function getPrismaClient(): PrismaClient {
  if (prisma) {
    return prisma;
  }

  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error("DATABASE_URL is not configured");
  }

  const pool = new Pool({ connectionString });
  prisma = new PrismaClient({
    adapter: new PrismaPg(pool, { disposeExternalPool: true }),
  });
  return prisma;
}

export async function disconnectPrisma(): Promise<void> {
  const current = prisma;
  prisma = undefined;
  await current?.$disconnect();
}
