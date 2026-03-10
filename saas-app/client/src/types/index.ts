/**
 * Shared TypeScript types used across the client.
 */

export interface User {
  id: string;
  email: string;
  name: string;
  bio?: string | null;
  avatarUrl?: string | null;
  role: 'USER' | 'ADMIN';
  isVerified: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AuthResponse {
  user: Pick<User, 'id' | 'email' | 'name' | 'role' | 'createdAt'>;
  token: string;
}

export interface ApiError {
  message: string;
  errors?: { field: string; message: string }[];
}

export interface PaginatedUsers {
  users: Pick<User, 'id' | 'email' | 'name' | 'role' | 'isVerified' | 'createdAt'>[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}
