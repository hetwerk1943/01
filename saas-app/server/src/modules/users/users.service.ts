/**
 * Users service – profile CRUD and password change logic.
 */
import bcrypt from 'bcryptjs';
import { prisma } from '../../prisma/client';
import { createHttpError } from '../../middleware/errorHandler';
import { logger } from '../../utils/logger';

const SALT_ROUNDS = 12;

/** Returns the full user profile (excluding password) */
export async function getProfile(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      email: true,
      name: true,
      bio: true,
      avatarUrl: true,
      role: true,
      isVerified: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  if (!user) throw createHttpError(404, 'User not found');
  return user;
}

/** Updates mutable profile fields (name, bio, avatarUrl) */
export async function updateProfile(
  userId: string,
  data: { name?: string; bio?: string; avatarUrl?: string }
) {
  const user = await prisma.user.update({
    where: { id: userId },
    data,
    select: {
      id: true,
      email: true,
      name: true,
      bio: true,
      avatarUrl: true,
      role: true,
      updatedAt: true,
    },
  });

  logger.info(`Profile updated for user ${userId}`);
  return user;
}

/** Changes password after verifying the current password */
export async function changePassword(
  userId: string,
  currentPassword: string,
  newPassword: string
) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw createHttpError(404, 'User not found');

  const valid = await bcrypt.compare(currentPassword, user.password);
  if (!valid) throw createHttpError(400, 'Current password is incorrect');

  const hashed = await bcrypt.hash(newPassword, SALT_ROUNDS);
  await prisma.user.update({
    where: { id: userId },
    data: { password: hashed },
  });

  logger.info(`Password changed for user ${userId}`);
}

/** Soft-deletes a user account by removing their record */
export async function deleteAccount(userId: string) {
  await prisma.user.delete({ where: { id: userId } });
  logger.info(`User account deleted: ${userId}`);
}

/** Admin: list all users with pagination */
export async function listUsers(page: number, limit: number) {
  const skip = (page - 1) * limit;
  const [users, total] = await prisma.$transaction([
    prisma.user.findMany({
      skip,
      take: limit,
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        isVerified: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    }),
    prisma.user.count(),
  ]);

  return { users, total, page, limit, totalPages: Math.ceil(total / limit) };
}
