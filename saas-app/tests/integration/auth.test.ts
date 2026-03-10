/**
 * Auth integration tests – register, login, forgot/reset password.
 * Uses Supertest against the Express app; DB is mocked with Jest.
 */
import request from 'supertest';
import { createApp } from '../../src/app';
import { prisma } from '../../src/prisma/client';
import bcrypt from 'bcryptjs';

// Mock Prisma and email utility to isolate tests from DB/SMTP
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

jest.mock('../../src/utils/email', () => ({
  sendPasswordResetEmail: jest.fn().mockResolvedValue(undefined),
}));

const app = createApp();
const prismaMock = prisma as jest.Mocked<typeof prisma>;

beforeEach(() => {
  jest.clearAllMocks();
});

describe('POST /api/auth/register', () => {
  it('creates a new user and returns a JWT token', async () => {
    const mockUser = {
      id: 'user-1',
      email: 'test@example.com',
      name: 'Test User',
      role: 'USER' as const,
      createdAt: new Date(),
    };

    (prismaMock.user.findUnique as jest.Mock).mockResolvedValue(null);
    (prismaMock.user.create as jest.Mock).mockResolvedValue(mockUser);

    const res = await request(app).post('/api/auth/register').send({
      email: 'test@example.com',
      password: 'Password123!',
      name: 'Test User',
    });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('token');
    expect(res.body.user.email).toBe('test@example.com');
  });

  it('returns 409 when email already registered', async () => {
    (prismaMock.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'existing',
      email: 'existing@example.com',
    });

    const res = await request(app).post('/api/auth/register').send({
      email: 'existing@example.com',
      password: 'Password123!',
      name: 'Existing User',
    });

    expect(res.status).toBe(409);
    expect(res.body.message).toMatch(/already registered/i);
  });

  it('returns 400 for invalid email', async () => {
    const res = await request(app).post('/api/auth/register').send({
      email: 'not-an-email',
      password: 'Password123!',
      name: 'User',
    });

    expect(res.status).toBe(400);
  });

  it('returns 400 for weak password', async () => {
    const res = await request(app).post('/api/auth/register').send({
      email: 'test@example.com',
      password: 'weak',
      name: 'User',
    });

    expect(res.status).toBe(400);
  });
});

describe('POST /api/auth/login', () => {
  it('returns token for valid credentials', async () => {
    const hashedPw = await bcrypt.hash('Password123!', 12);
    (prismaMock.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      email: 'test@example.com',
      password: hashedPw,
      name: 'Test User',
      bio: null,
      avatarUrl: null,
      role: 'USER',
      isVerified: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const res = await request(app).post('/api/auth/login').send({
      email: 'test@example.com',
      password: 'Password123!',
    });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body.user).not.toHaveProperty('password');
  });

  it('returns 401 for wrong password', async () => {
    const hashedPw = await bcrypt.hash('CorrectPassword123!', 12);
    (prismaMock.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      email: 'test@example.com',
      password: hashedPw,
      name: 'Test',
      role: 'USER',
    });

    const res = await request(app).post('/api/auth/login').send({
      email: 'test@example.com',
      password: 'WrongPassword123!',
    });

    expect(res.status).toBe(401);
  });

  it('returns 401 for non-existent user', async () => {
    (prismaMock.user.findUnique as jest.Mock).mockResolvedValue(null);

    const res = await request(app).post('/api/auth/login').send({
      email: 'noone@example.com',
      password: 'Password123!',
    });

    expect(res.status).toBe(401);
  });
});

describe('POST /api/auth/forgot-password', () => {
  it('returns 200 even if email not found (anti-enumeration)', async () => {
    (prismaMock.user.findUnique as jest.Mock).mockResolvedValue(null);

    const res = await request(app)
      .post('/api/auth/forgot-password')
      .send({ email: 'nobody@example.com' });

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/reset link/i);
  });

  it('creates a reset token when email exists', async () => {
    (prismaMock.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      email: 'test@example.com',
    });
    (prismaMock.passwordResetToken.deleteMany as jest.Mock).mockResolvedValue({});
    (prismaMock.passwordResetToken.create as jest.Mock).mockResolvedValue({});

    const res = await request(app)
      .post('/api/auth/forgot-password')
      .send({ email: 'test@example.com' });

    expect(res.status).toBe(200);
    expect(prismaMock.passwordResetToken.create).toHaveBeenCalled();
  });
});

describe('POST /api/auth/reset-password', () => {
  it('returns 400 for invalid/expired token', async () => {
    (prismaMock.passwordResetToken.findUnique as jest.Mock).mockResolvedValue(null);

    const res = await request(app)
      .post('/api/auth/reset-password')
      .send({ token: 'invalid-token', password: 'NewPassword123!' });

    expect(res.status).toBe(400);
  });

  it('resets password with valid token', async () => {
    (prismaMock.passwordResetToken.findUnique as jest.Mock).mockResolvedValue({
      id: 'token-1',
      token: 'valid-token',
      userId: 'user-1',
      expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      usedAt: null,
    });
    (prismaMock.$transaction as jest.Mock).mockResolvedValue([{}, {}]);

    const res = await request(app)
      .post('/api/auth/reset-password')
      .send({ token: 'valid-token', password: 'NewPassword123!' });

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/reset successfully/i);
  });
});

describe('GET /api/auth/me', () => {
  it('returns 401 without token', async () => {
    const res = await request(app).get('/api/auth/me');
    expect(res.status).toBe(401);
  });

  it('returns user info with valid token', async () => {
    // Generate a real token
    const { signToken } = await import('../../src/utils/jwt');
    const token = signToken({
      userId: 'user-1',
      email: 'test@example.com',
      role: 'USER',
    });

    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe('test@example.com');
  });
});
