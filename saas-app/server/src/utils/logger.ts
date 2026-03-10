import pino from 'pino';
import { config } from '../config';

export const logger = pino({
  level: config.nodeEnv === 'test' ? 'silent' : config.nodeEnv === 'production' ? 'info' : 'debug',
});
