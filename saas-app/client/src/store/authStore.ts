/**
 * Zustand auth store – manages authentication state (token + user).
 * Persists token to localStorage for session persistence.
 */
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { User } from '../types';

interface AuthState {
  token: string | null;
  user: Pick<User, 'id' | 'email' | 'name' | 'role' | 'createdAt'> | null;
  setAuth: (
    token: string,
    user: Pick<User, 'id' | 'email' | 'name' | 'role' | 'createdAt'>
  ) => void;
  logout: () => void;
  isAuthenticated: () => boolean;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      token: null,
      user: null,

      setAuth: (token, user) => set({ token, user }),

      logout: () => set({ token: null, user: null }),

      isAuthenticated: () => !!get().token,
    }),
    {
      name: 'saas-auth', // localStorage key
      partialize: (state) => ({ token: state.token, user: state.user }),
    }
  )
);
