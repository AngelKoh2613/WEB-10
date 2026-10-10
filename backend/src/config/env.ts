import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL: z.string().min(1).optional(),
  JWT_SECRET: z.string().min(32).optional(),
});

export type AppEnv = z.infer<typeof envSchema>;

export function loadEnv(source: NodeJS.ProcessEnv): AppEnv {
  const input: Record<string, unknown> = {};

  if (source.NODE_ENV !== undefined) {
    input.NODE_ENV = source.NODE_ENV;
  }
  if (source.PORT !== undefined) {
    input.PORT = source.PORT;
  }
  if (source.DATABASE_URL !== undefined && source.DATABASE_URL.length > 0) {
    input.DATABASE_URL = source.DATABASE_URL;
  }
  if (source.JWT_SECRET !== undefined && source.JWT_SECRET.length > 0) {
    input.JWT_SECRET = source.JWT_SECRET;
  }

  const parsed = envSchema.safeParse(input);
  if (!parsed.success) {
    throw new Error("Invalid environment configuration");
  }

  return parsed.data;
}
