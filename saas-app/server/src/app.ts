/**
 * Express application factory – creates and configures the Express app.
 * Separated from server startup to allow easy testing with Supertest.
 */
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { config } from './config';
import { requestLogger } from './middleware/requestLogger';
import { rateLimiter } from './middleware/rateLimiter';
import { errorHandler } from './middleware/errorHandler';
import authRoutes from './modules/auth/auth.routes';
import usersRoutes from './modules/users/users.routes';

export function createApp() {
  const app = express();

  // Security headers
  app.use(helmet());

  // CORS
  app.use(
    cors({
      origin: config.clientOrigin,
      credentials: true,
    })
  );

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

  // Request logging
  app.use(requestLogger);

  // Global rate limiter
  app.use(rateLimiter);

  // Health check – no auth required
  app.get('/health', (_req, res) => {
    res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  // API routes
  app.use('/api/auth', authRoutes);
  app.use('/api/users', usersRoutes);

  // 404 handler
  app.use((_req, res) => {
    res.status(404).json({ message: 'Route not found' });
  });

  // Global error handler (must be last)
  app.use(errorHandler);

  return app;
}
import express from 'express';
import pinoHttp from 'pino-http';
import { logger } from './utils/logger';
import authRouter from './routes/auth';
import usersRouter from './routes/users';
import { errorHandler } from './middleware/errorHandler';

const app = express();

app.use(pinoHttp({ logger }));
app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.use('/api/auth', authRouter);
app.use('/api/users', usersRouter);

app.use(errorHandler);

export default app;
