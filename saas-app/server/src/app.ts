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
