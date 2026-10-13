import { Router, type RequestHandler } from "express";
import { z } from "zod";
import { AppError } from "../errors/app-error.js";
import { createRequireAuth } from "../middleware/require-auth.js";
import { AuthService } from "./auth-service.js";
import { TokenService } from "./tokens.js";

const emailField = z.string().trim().toLowerCase().max(254).pipe(z.email());

const registerSchema = z
  .object({
    email: emailField,
    password: z.string().min(10).max(128),
  })
  .strict();

const loginSchema = z
  .object({
    email: emailField,
    password: z.string().min(1).max(128),
  })
  .strict();

function invalidBody(error: z.ZodError): AppError {
  const issue = error.issues[0];
  const field = issue?.path[0];
  if (field === "email") {
    return new AppError(400, "VALIDATION_ERROR", "El correo no es válido");
  }
  if (field === "password") {
    return new AppError(400, "VALIDATION_ERROR", "La contraseña no cumple la política");
  }
  return new AppError(400, "VALIDATION_ERROR", "Datos no válidos");
}

async function readBody<T>(schema: z.ZodType<T>, body: unknown): Promise<T> {
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    throw invalidBody(parsed.error);
  }
  return parsed.data;
}

export function createAuthRouter(deps: {
  service: AuthService;
  tokens: TokenService;
  rateLimit: RequestHandler;
}): Router {
  const router = Router();
  const requireAuth = createRequireAuth(deps.tokens);

  router.post("/register", deps.rateLimit, async (req, res, next) => {
    try {
      const body = await readBody(registerSchema, req.body);
      const result = await deps.service.register(body.email, body.password);
      res.status(201).json(result);
    } catch (error) {
      next(error);
    }
  });

  router.post("/login", deps.rateLimit, async (req, res, next) => {
    try {
      const body = await readBody(loginSchema, req.body);
      const result = await deps.service.login(body.email, body.password);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  });

  router.post("/logout", requireAuth, (_req, res) => {
    res.status(204).send();
  });

  router.get("/session", requireAuth, (_req, res) => {
    const userId = res.locals.userId;
    if (typeof userId !== "string") {
      throw new AppError(401, "UNAUTHENTICATED", "Autenticación requerida");
    }
    res.status(200).json({ userId });
  });

  return router;
}
