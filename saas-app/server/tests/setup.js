"use strict";
/**
 * Jest test setup – sets required environment variables before tests run.
 * These are safe test-only values, not production secrets.
 */
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_for_ci_only';
process.env.JWT_EXPIRES_IN = '1h';
process.env.RESET_TOKEN_TTL_MINUTES = '60';
process.env.CLIENT_ORIGIN = 'http://localhost:5173';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.SMTP_HOST = 'smtp.ethereal.email';
process.env.SMTP_PORT = '587';
process.env.SMTP_USER = '';
process.env.SMTP_PASS = '';
process.env.MAIL_FROM = 'test@example.com';
process.env.RATE_LIMIT_WINDOW_MS = '900000';
process.env.RATE_LIMIT_MAX = '1000';
//# sourceMappingURL=setup.js.map