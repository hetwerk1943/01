/**
 * Users controller – HTTP layer for user profile endpoints.
 */
import { Request, Response, NextFunction } from 'express';
import * as usersService from './users.service';
import {
  updateProfileSchema,
  changePasswordSchema,
} from '../../utils/validators';

/** GET /api/users/profile */
export async function getProfile(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const user = await usersService.getProfile(req.user!.userId);
    res.status(200).json({ user });
  } catch (err) {
    next(err);
  }
}

/** PATCH /api/users/profile */
export async function updateProfile(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const data = updateProfileSchema.parse(req.body);
    const user = await usersService.updateProfile(req.user!.userId, data);
    res.status(200).json({ user });
  } catch (err) {
    next(err);
  }
}

/** POST /api/users/change-password */
export async function changePassword(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const { currentPassword, newPassword } = changePasswordSchema.parse(
      req.body
    );
    await usersService.changePassword(
      req.user!.userId,
      currentPassword,
      newPassword
    );
    res.status(200).json({ message: 'Password changed successfully' });
  } catch (err) {
    next(err);
  }
}

/** DELETE /api/users/account */
export async function deleteAccount(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    await usersService.deleteAccount(req.user!.userId);
    res.status(200).json({ message: 'Account deleted successfully' });
  } catch (err) {
    next(err);
  }
}

/** GET /api/users – admin only */
export async function listUsers(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    if (req.user!.role !== 'ADMIN') {
      res.status(403).json({ message: 'Forbidden' });
      return;
    }
    const page = parseInt((req.query.page as string) ?? '1', 10);
    const limit = parseInt((req.query.limit as string) ?? '20', 10);
    const result = await usersService.listUsers(page, limit);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}
