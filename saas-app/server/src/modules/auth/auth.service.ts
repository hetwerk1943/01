/**
 * Auth service – handles registration, login, and password reset business logic.
 */
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import { prisma } from '../../prisma/client';
import { signToken } from '../../utils/jwt';
import { sendPasswordResetEmail } from '../../utils/email';
import { createHttpError } from '../../middleware/errorHandler';
import { config } from '../../config';
import { logger } from '../../utils/logger';

const SALT_ROUNDS = 12;

export async function register(
  email: string,
  password: string,
  name: string
) {
  // Check for existing user
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    throw createHttpError(409, 'Email already registered');
  }

  const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);

  const user = await prisma.user.create({
    data: { email, password: hashedPassword, name },
    select: { id: true, email: true, name: true, role: true, createdAt: true },
  });

  logger.info(`New user registered: ${email}`);
  const token = signToken({ userId: user.id, email: user.email, role: user.role });
  return { user, token };
}

export async function login(email: string, password: string) {
  const user = await prisma.user.findUnique({ where: { email } });

  if (!user) {
    throw createHttpError(401, 'Invalid credentials');
  }

  const valid = await bcrypt.compare(password, user.password);
  if (!valid) {
    throw createHttpError(401, 'Invalid credentials');
  }

  logger.info(`User logged in: ${email}`);
  const token = signToken({ userId: user.id, email: user.email, role: user.role });

  const { password: _pw, ...safeUser } = user;
  return { user: safeUser, token };
}

export async function forgotPassword(email: string) {
  // Always return success to avoid email enumeration
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) return;

  // Invalidate previous unused tokens
  await prisma.passwordResetToken.deleteMany({
    where: { userId: user.id, usedAt: null },
  });

  const token = uuidv4();
  const expiresAt = new Date(
    Date.now() + config.resetTokenTtlMinutes * 60 * 1000
  );

  await prisma.passwordResetToken.create({
    data: { token, userId: user.id, expiresAt },
  });

  await sendPasswordResetEmail(email, token);
}

export async function resetPassword(token: string, newPassword: string) {
  const record = await prisma.passwordResetToken.findUnique({
    where: { token },
  });

  if (!record || record.usedAt || record.expiresAt < new Date()) {
    throw createHttpError(400, 'Invalid or expired reset token');
  }

  const hashed = await bcrypt.hash(newPassword, SALT_ROUNDS);

  await prisma.$transaction([
    prisma.user.update({
      where: { id: record.userId },
      data: { password: hashed },
    }),
    prisma.passwordResetToken.update({
      where: { id: record.id },
      data: { usedAt: new Date() },
    }),
  ]);

  logger.info(`Password reset for user ${record.userId}`);
}
