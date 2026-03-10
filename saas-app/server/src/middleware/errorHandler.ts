/**
 * Global error handler middleware – catches all errors thrown in route handlers.
 * Returns consistent JSON error responses.
 */
import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { logger } from '../utils/logger';

export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  // Zod validation errors
  if (err instanceof ZodError) {
    res.status(400).json({
      message: 'Validation error',
      errors: err.errors.map((e) => ({
        field: e.path.join('.'),
        message: e.message,
      })),
    });
    return;
  }

  // Generic Error
  if (err instanceof Error) {
    logger.error(err.message, { stack: err.stack });
    const status = (err as { status?: number }).status ?? 500;
    res.status(status).json({
      message:
        status === 500
          ? 'Internal server error'
          : err.message,
    });
    return;
  }

  // Unknown
  logger.error('Unknown error', { err });
  res.status(500).json({ message: 'Internal server error' });
}

/** Convenience helper – creates an Error with an HTTP status code */
export function createHttpError(status: number, message: string): Error & { status: number } {
  const err = new Error(message) as Error & { status: number };
  err.status = status;
  return err;
}
