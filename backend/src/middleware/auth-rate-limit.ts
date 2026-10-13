import type { NextFunction, Request, Response } from "express";

type Bucket = {
  count: number;
  resetAt: number;
};

export function createAuthRateLimit(options: {
  limit: number;
  windowMs: number;
  now?: () => number;
}) {
  const buckets = new Map<string, Bucket>();
  const now = options.now ?? Date.now;

  return function authRateLimit(req: Request, res: Response, next: NextFunction): void {
    const key = req.ip && req.ip.length > 0 ? req.ip : "unknown";
    const current = now();
    const existing = buckets.get(key);

    if (!existing || current >= existing.resetAt) {
      buckets.set(key, { count: 1, resetAt: current + options.windowMs });
      next();
      return;
    }

    if (existing.count >= options.limit) {
      res.status(429).json({
        error: {
          code: "TOO_MANY_REQUESTS",
          message: "Demasiados intentos. Espera antes de reintentar.",
        },
      });
      return;
    }

    existing.count += 1;
    next();
  };
}
