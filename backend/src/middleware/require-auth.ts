import type { NextFunction, Request, Response } from "express";
import { AppError } from "../errors/app-error.js";
import type { TokenService } from "../auth/tokens.js";

export function createRequireAuth(tokens: TokenService) {
  return async function requireAuth(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    const header = req.header("authorization") ?? "";
    const [scheme, token] = header.split(" ");
    if (scheme !== "Bearer" || token === undefined || token.length === 0) {
      next(new AppError(401, "UNAUTHENTICATED", "Autenticación requerida"));
      return;
    }

    try {
      res.locals.userId = await tokens.verify(token);
      next();
    } catch {
      next(new AppError(401, "UNAUTHENTICATED", "Autenticación requerida"));
    }
  };
}
