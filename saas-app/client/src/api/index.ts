/**
 * Auth API calls.
 */
import api from './client';
import type { AuthResponse } from '../types';

export const authApi = {
  register: (data: { email: string; password: string; name: string }) =>
    api.post<AuthResponse>('/auth/register', data),

  login: (data: { email: string; password: string }) =>
    api.post<AuthResponse>('/auth/login', data),

  forgotPassword: (email: string) =>
    api.post('/auth/forgot-password', { email }),

  resetPassword: (token: string, password: string) =>
    api.post('/auth/reset-password', { token, password }),

  me: () => api.get('/auth/me'),
};

/**
 * Users API calls.
 */
export const usersApi = {
  getProfile: () => api.get('/users/profile'),

  updateProfile: (data: { name?: string; bio?: string; avatarUrl?: string }) =>
    api.patch('/users/profile', data),

  changePassword: (data: { currentPassword: string; newPassword: string }) =>
    api.post('/users/change-password', data),

  deleteAccount: () => api.delete('/users/account'),

  listUsers: (page = 1, limit = 20) =>
    api.get('/users', { params: { page, limit } }),
};
