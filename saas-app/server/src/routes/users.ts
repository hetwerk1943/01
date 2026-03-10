import { Router, Request, Response, NextFunction } from 'express';
import { authenticate } from '../middleware/auth';
import { apiLimiter } from '../middleware/rateLimiter';
import { UpdateUserSchema } from '../validators/userValidators';
import * as userService from '../services/userService';

const router = Router();

router.use(apiLimiter);
router.use(authenticate);

router.get('/me', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await userService.getUser(req.user!.userId);
    res.status(200).json({ user });
  } catch (err) {
    next(err);
  }
});

router.patch('/me', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = UpdateUserSchema.parse(req.body);
    const user = await userService.updateUser(req.user!.userId, data);
    res.status(200).json({ user });
  } catch (err) {
    next(err);
  }
});

router.delete('/me', async (req: Request, res: Response, next: NextFunction) => {
  try {
    await userService.deleteUser(req.user!.userId);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

export default router;
