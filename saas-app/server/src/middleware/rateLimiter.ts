/**
 * Rate limiter middleware – protects the API from brute-force and abuse.
 * Configurable via environment variables.
 */
import rateLimit from 'express-rate-limit';
import { config } from '../config';

export const rateLimiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    message: 'Too many requests, please try again later.',
  },
});

/** Stricter limiter for auth endpoints to prevent brute-force */
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    message: 'Too many auth attempts, please try again in 15 minutes.',
  },
});
