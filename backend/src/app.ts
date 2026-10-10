import express from "express";
import { AuthService } from "./auth/auth-service.js";
import { createAuthRouter } from "./auth/auth-routes.js";
import { TokenService } from "./auth/tokens.js";
import type { UserRepository } from "./auth/user-repository.js";
import { createEventRouter } from "./events/event-routes.js";
import type { EventRepository } from "./events/event-repository.js";
import { errorHandler } from "./errors/error-handler.js";
import { createAuthRateLimit } from "./middleware/auth-rate-limit.js";
import { notFoundHandler } from "./middleware/not-found.js";
import { securityHeaders } from "./middleware/security-headers.js";

export type CreateAppOptions = {
  users?: UserRepository;
  events?: EventRepository;
  jwtSecret?: string;
  rateLimit?: { limit: number; windowMs: number };
};

export function createApp(options: CreateAppOptions = {}): express.Express {
  const app = express();
  app.disable("x-powered-by");
  app.use(securityHeaders);
  app.use(express.json({ limit: "1mb" }));

  app.get("/health", (_req, res) => {
    res.status(200).json({
      status: "ok",
      service: "secureplan-api",
    });
  });

  const secret = options.jwtSecret ?? "";
  const tokens = secret.length >= 32 ? new TokenService(secret) : undefined;

  if (options.users && tokens) {
    const service = new AuthService(options.users, tokens);
    const rateLimit = createAuthRateLimit({
      limit: options.rateLimit?.limit ?? 10,
      windowMs: options.rateLimit?.windowMs ?? 15 * 60 * 1000,
    });
    app.use("/api/auth", createAuthRouter({ service, tokens, rateLimit }));
  } else {
    app.use("/api/auth", (_req, res) => {
      res.status(503).json({
        error: {
          code: "SERVICE_UNAVAILABLE",
          message: "La autenticación no está disponible",
        },
      });
    });
  }

  if (options.events && tokens) {
    app.use("/api/events", createEventRouter({ events: options.events, tokens }));
  } else {
    app.use("/api/events", (_req, res) => {
      res.status(503).json({
        error: {
          code: "SERVICE_UNAVAILABLE",
          message: "La agenda no está disponible",
        },
      });
    });
  }

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
