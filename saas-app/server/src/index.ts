/**
 * Server entry point – starts the Express HTTP server.
 * Do NOT import app from here in tests – use createApp() from app.ts.
 */
import { createApp } from './app';
import { config } from './config';
import { logger } from './utils/logger';
import { prisma } from './prisma/client';

async function main() {
  // Verify database connection
  await prisma.$connect();
  logger.info('Database connected');

  const app = createApp();

  const server = app.listen(config.port, () => {
    logger.info(
      `Server running in ${config.env} mode on port ${config.port}`
    );
  });

  // Graceful shutdown
  const shutdown = async (signal: string) => {
    logger.info(`Received ${signal}, shutting down gracefully...`);
    server.close(async () => {
      await prisma.$disconnect();
      logger.info('Server closed');
      process.exit(0);
    });
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

main().catch((err) => {
  logger.error('Failed to start server', err);
  process.exit(1);
});
