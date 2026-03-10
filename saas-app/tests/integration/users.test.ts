/**
 * Users integration tests – profile CRUD, password change.
 */
import request from 'supertest';
import { createApp } from '../../src/app';
import { prisma } from '../../src/prisma/client';
import { signToken } from '../../src/utils/jwt';
import bcrypt from 'bcryptjs';

jest.mock('../../src/prisma/client', () => ({
  prisma: {
    user: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      count: jest.fn(),
      findMany: jest.fn(),
    },
    passwordResetToken: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      deleteMany: jest.fn(),
    },
    $transaction: jest.fn(),
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $on: jest.fn(),
  },
}));

const app = createApp();
const prismaMock = prisma as jest.Mocked<typeof prisma>;

// Helper to get a valid auth token
const makeToken = (overrides = {}) =>
  signToken({ userId: 'user-1', email: 'test@example.com', role: 'USER', ...overrides });

beforeEach(() => jest.clearAllMocks());

describe('GET /api/users/profile', () => {
  it('returns user profile', async () => {
    const mockUser = {
      id: 'user-1',
      email: 'test@example.com',
      name: 'Test User',
      bio: 'Hello world',
      avatarUrl: null,
      role: 'USER',
      isVerified: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    (prismaMock.user.findUnique as jest.Mock).mockResolvedValue(mockUser);

    const res = await request(app)
      .get('/api/users/profile')
      .set('Authorization', `Bearer ${makeToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe('test@example.com');
  });

  it('returns 401 without token', async () => {
    const res = await request(app).get('/api/users/profile');
    expect(res.status).toBe(401);
  });

  it('returns 404 if user does not exist', async () => {
    (prismaMock.user.findUnique as jest.Mock).mockResolvedValue(null);

    const res = await request(app)
      .get('/api/users/profile')
      .set('Authorization', `Bearer ${makeToken()}`);

    expect(res.status).toBe(404);
  });
});

describe('PATCH /api/users/profile', () => {
  it('updates user profile fields', async () => {
    const updated = {
      id: 'user-1',
      email: 'test@example.com',
      name: 'Updated Name',
      bio: 'New bio',
      avatarUrl: null,
      role: 'USER',
      updatedAt: new Date(),
    };

    (prismaMock.user.update as jest.Mock).mockResolvedValue(updated);

    const res = await request(app)
      .patch('/api/users/profile')
      .set('Authorization', `Bearer ${makeToken()}`)
      .send({ name: 'Updated Name', bio: 'New bio' });

    expect(res.status).toBe(200);
    expect(res.body.user.name).toBe('Updated Name');
  });

  it('returns 400 for invalid avatarUrl', async () => {
    const res = await request(app)
      .patch('/api/users/profile')
      .set('Authorization', `Bearer ${makeToken()}`)
      .send({ avatarUrl: 'not-a-url' });

    expect(res.status).toBe(400);
  });
});

describe('POST /api/users/change-password', () => {
  it('changes password with correct current password', async () => {
    const hashedPw = await bcrypt.hash('OldPassword123!', 12);
    (prismaMock.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      password: hashedPw,
    });
    (prismaMock.user.update as jest.Mock).mockResolvedValue({});

    const res = await request(app)
      .post('/api/users/change-password')
      .set('Authorization', `Bearer ${makeToken()}`)
      .send({
        currentPassword: 'OldPassword123!',
        newPassword: 'NewPassword123!',
      });

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/changed/i);
  });

  it('returns 400 if current password is wrong', async () => {
    const hashedPw = await bcrypt.hash('ActualPassword123!', 12);
    (prismaMock.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      password: hashedPw,
    });

    const res = await request(app)
      .post('/api/users/change-password')
      .set('Authorization', `Bearer ${makeToken()}`)
      .send({
        currentPassword: 'WrongPassword123!',
        newPassword: 'NewPassword123!',
      });

    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/incorrect/i);
  });
});

describe('DELETE /api/users/account', () => {
  it('deletes user account', async () => {
    (prismaMock.user.delete as jest.Mock).mockResolvedValue({});

    const res = await request(app)
      .delete('/api/users/account')
      .set('Authorization', `Bearer ${makeToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/deleted/i);
  });
});

describe('GET /api/users (admin list)', () => {
  it('returns 403 for non-admin user', async () => {
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${makeToken({ role: 'USER' })}`);

    expect(res.status).toBe(403);
  });

  it('returns user list for admin', async () => {
    const mockUsers = [
      { id: 'u1', email: 'a@b.com', name: 'A', role: 'USER', isVerified: true, createdAt: new Date() },
    ];
    (prismaMock.$transaction as jest.Mock).mockResolvedValue([mockUsers, 1]);

    const res = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${makeToken({ role: 'ADMIN' })}`);

    expect(res.status).toBe(200);
    expect(res.body.users).toHaveLength(1);
    expect(res.body.total).toBe(1);
  });
});
