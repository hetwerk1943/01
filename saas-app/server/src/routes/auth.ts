import { Router, Request, Response, NextFunction } from 'express';
import { authLimiter } from '../middleware/rateLimiter';
import {
  RegisterSchema,
  LoginSchema,
  PasswordResetRequestSchema,
  PasswordResetConfirmSchema,
} from '../validators/authValidators';
import * as authService from '../services/authService';
import { signToken } from '../utils/jwt';

const router = Router();

router.use(authLimiter);

router.post('/register', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = RegisterSchema.parse(req.body);
    const user = await authService.register(data.email, data.password, data.name);
    const token = signToken({ userId: user.id, email: user.email });
    res.status(201).json({ token, user });
  } catch (err) {
    next(err);
  }
});

router.post('/login', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = LoginSchema.parse(req.body);
    const user = await authService.login(data.email, data.password);
    const token = signToken({ userId: user.id, email: user.email });
    res.status(200).json({ token, user });
  } catch (err) {
    next(err);
  }
});

router.post('/password/reset/request', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = PasswordResetRequestSchema.parse(req.body);
    const result = await authService.requestPasswordReset(data.email);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

router.post('/password/reset/confirm', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = PasswordResetConfirmSchema.parse(req.body);
    await authService.confirmPasswordReset(data.token, data.newPassword);
    res.status(200).json({ ok: true });
  } catch (err) {
    next(err);
  }
});

export default router;
