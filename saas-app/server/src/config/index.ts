/**
 * Application configuration – reads environment variables with validation.
 * All required variables throw at startup if missing.
 */
import dotenv from 'dotenv';
dotenv.config();

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export const config = {
  env: process.env.NODE_ENV ?? 'development',
  port: parseInt(process.env.PORT ?? '4000', 10),

  jwtSecret: required('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',

  resetTokenTtlMinutes: parseInt(
    process.env.RESET_TOKEN_TTL_MINUTES ?? '60',
    10
  ),

  clientOrigin: process.env.CLIENT_ORIGIN ?? 'http://localhost:5173',

  smtp: {
    host: process.env.SMTP_HOST ?? 'smtp.ethereal.email',
    port: parseInt(process.env.SMTP_PORT ?? '587', 10),
    user: process.env.SMTP_USER ?? '',
    pass: process.env.SMTP_PASS ?? '',
    from: process.env.MAIL_FROM ?? 'noreply@example.com',
  },

  rateLimit: {
    windowMs: parseInt(
      process.env.RATE_LIMIT_WINDOW_MS ?? '900000',
      10
    ),
    max: parseInt(process.env.RATE_LIMIT_MAX ?? '100', 10),
  },
};
