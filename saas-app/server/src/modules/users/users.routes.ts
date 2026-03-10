/**
 * Users routes – all routes require authentication.
 */
import { Router } from 'express';
import * as usersController from './users.controller';
import { requireAuth } from '../../middleware/requireAuth';

const router = Router();

// All users routes are protected
router.use(requireAuth);

// GET  /api/users/profile        – get own profile
router.get('/profile', usersController.getProfile);

// PATCH /api/users/profile       – update own profile
router.patch('/profile', usersController.updateProfile);

// POST /api/users/change-password
router.post('/change-password', usersController.changePassword);

// DELETE /api/users/account      – delete own account
router.delete('/account', usersController.deleteAccount);

// GET /api/users                 – admin: list all users
router.get('/', usersController.listUsers);

export default router;
