/**
 * Auth routes – mounts all authentication endpoints under /api/auth.
 */
import { Router } from 'express';
import * as authController from './auth.controller';
import { requireAuth } from '../../middleware/requireAuth';
import { authRateLimiter } from '../../middleware/rateLimiter';

const router = Router();

// POST /api/auth/register
router.post('/register', authRateLimiter, authController.register);

// POST /api/auth/login
router.post('/login', authRateLimiter, authController.login);

// POST /api/auth/forgot-password
router.post('/forgot-password', authRateLimiter, authController.forgotPassword);

// POST /api/auth/reset-password
router.post('/reset-password', authController.resetPassword);

// GET /api/auth/me  (protected)
router.get('/me', requireAuth, authController.me);

export default router;
