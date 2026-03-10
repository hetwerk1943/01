/**
 * Request logger middleware – logs method, URL, status, and response time.
 * Uses morgan under the hood with winston integration.
 */
import morgan from 'morgan';
import { Request, Response } from 'express';
import { logger } from '../utils/logger';

// Stream that pipes morgan output into winston
const stream = {
  write: (message: string) => logger.http(message.trim()),
};

// Skip logging in test environment to keep test output clean
const skip = (_req: Request, _res: Response) =>
  process.env.NODE_ENV === 'test';

export const requestLogger = morgan(
  ':method :url :status :res[content-length] - :response-time ms',
  { stream, skip }
);
