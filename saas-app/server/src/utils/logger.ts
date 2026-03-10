/**
 * Winston logger configuration.
 * Logs JSON in production, human-readable in development.
 */
import winston from 'winston';
import { config } from '../config';

const { combine, timestamp, printf, colorize, errors } = winston.format;

const devFormat = combine(
  colorize(),
  timestamp({ format: 'HH:mm:ss' }),
  errors({ stack: true }),
  printf(({ level, message, timestamp, stack }) =>
    stack
      ? `${timestamp} [${level}] ${message}\n${stack}`
      : `${timestamp} [${level}] ${message}`
  )
);

const prodFormat = combine(
  timestamp(),
  errors({ stack: true }),
  winston.format.json()
);

export const logger = winston.createLogger({
  level: config.env === 'production' ? 'info' : 'debug',
  format: config.env === 'production' ? prodFormat : devFormat,
  transports: [new winston.transports.Console()],
import pino from 'pino';
import { config } from '../config';

export const logger = pino({
  level: config.nodeEnv === 'test' ? 'silent' : config.nodeEnv === 'production' ? 'info' : 'debug',
});
