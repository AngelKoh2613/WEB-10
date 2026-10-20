import type { NextFunction, Request, Response } from "express";
import { jest } from "@jest/globals";
import { AppError } from "../src/errors/app-error.js";
import { errorHandler } from "../src/errors/error-handler.js";

function captureResponse(): Response & { statusCode: number; body: unknown } {
  const response = {
    statusCode: 0,
    body: undefined as unknown,
    status(code: number) {
      this.statusCode = code;
      return this;
    },
    json(payload: unknown) {
      this.body = payload;
      return this;
    },
  };

  return response as Response & { statusCode: number; body: unknown };
}

describe("errorHandler", () => {
  const req = {} as Request;
  const next = (() => undefined) as NextFunction;

  it("returns the public message for an AppError", () => {
    const res = captureResponse();

    errorHandler(new AppError(400, "VALIDATION_ERROR", "Invalid input"), req, res, next);

    expect(res.statusCode).toBe(400);
    expect(res.body).toEqual({
      error: {
        code: "VALIDATION_ERROR",
        message: "Invalid input",
      },
    });
  });

  it("hides unexpected failures from the client", () => {
    const res = captureResponse();
    const errorSpy = jest.spyOn(console, "error").mockImplementation(() => undefined);

    errorHandler(new Error("database password=secret"), req, res, next);

    expect(res.statusCode).toBe(500);
    expect(res.body).toEqual({
      error: {
        code: "INTERNAL_ERROR",
        message: "Unexpected error",
      },
    });
    expect(JSON.stringify(res.body)).not.toContain("secret");
    expect(errorSpy).toHaveBeenCalledWith("Unhandled error");
    errorSpy.mockRestore();
  });

  it("hides a database error code and its message", () => {
    const res = captureResponse();
    const errorSpy = jest.spyOn(console, "error").mockImplementation(() => undefined);

    errorHandler(
      { code: "P2002", message: "unique secret-token" },
      req,
      res,
      next,
    );

    expect(res.statusCode).toBe(500);
    expect(JSON.stringify(res.body)).not.toContain("secret-token");
    expect(JSON.stringify(res.body)).not.toContain("P2002");
    expect(errorSpy).toHaveBeenCalledWith("Database error");
    errorSpy.mockRestore();
  });
});
