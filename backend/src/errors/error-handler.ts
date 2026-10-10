import type { NextFunction, Request, Response } from "express";
import { AppError } from "./app-error.js";

function isDatabaseError(error: unknown): boolean {
  if (typeof error !== "object" || error === null || !("code" in error)) {
    return false;
  }
  const code = error.code;
  return typeof code === "string" && /^P\d{4}$/.test(code);
}

export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void {
  if (err instanceof AppError) {
    res.status(err.status).json({
      error: {
        code: err.code,
        message: err.message,
      },
      ...err.details,
    });
    return;
  }

  if (isDatabaseError(err)) {
    console.error("Database error");
    res.status(500).json({
      error: {
        code: "INTERNAL_ERROR",
        message: "Unexpected error",
      },
    });
    return;
  }

  console.error("Unhandled error");
  res.status(500).json({
    error: {
      code: "INTERNAL_ERROR",
      message: "Unexpected error",
    },
  });
}
