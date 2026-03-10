const nodeEnv = process.env.NODE_ENV ?? 'development';

if (nodeEnv === 'production' && !process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET environment variable must be set in production');
}

export const config = {
  port: parseInt(process.env.PORT ?? '4000', 10),
  nodeEnv,
  jwtSecret: process.env.JWT_SECRET ?? 'dev-secret-change-in-production',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  databaseUrl: process.env.DATABASE_URL ?? '',
  bcryptSaltRounds: 10,
  passwordResetExpiryMs: 60 * 60 * 1000, // 1 hour
};
