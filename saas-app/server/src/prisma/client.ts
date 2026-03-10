/**
 * Prisma client singleton – reuses a single instance across the application.
 * Prevents multiple connections during hot-reloads in development.
 */
import { PrismaClient } from '@prisma/client';
import { logger } from '../utils/logger';

declare global {
  // Allow global in dev to persist across HMR
  // eslint-disable-next-line no-var
  var __prisma: PrismaClient | undefined;
}

export const prisma: PrismaClient =
  global.__prisma ??
  new PrismaClient({
    log: [
      { emit: 'event', level: 'query' },
      { emit: 'event', level: 'error' },
    ],
  });

if (process.env.NODE_ENV !== 'production') {
  global.__prisma = prisma;
}

// Log slow queries in development
prisma.$on('query' as never, (e: { duration: number; query: string }) => {
  if (e.duration > 500) {
    logger.debug(`Slow query (${e.duration}ms): ${e.query}`);
  }
});

prisma.$on('error' as never, (e: { message: string }) => {
  logger.error(`Prisma error: ${e.message}`);
});
