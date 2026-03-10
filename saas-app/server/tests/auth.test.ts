import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import app from '../src/app';

const prisma = new PrismaClient();

beforeAll(async () => {
  await prisma.$connect();
  await prisma.passwordResetToken.deleteMany();
  await prisma.user.deleteMany();
});

afterAll(async () => {
  await prisma.passwordResetToken.deleteMany();
  await prisma.user.deleteMany();
  await prisma.$disconnect();
});

describe('POST /api/auth/register', () => {
  it('should register a new user and return 201 with token', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'test@example.com', password: 'Passw0rd!', name: 'Test User' });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('token');
    expect(res.body.user).toHaveProperty('email', 'test@example.com');
    expect(res.body.user).not.toHaveProperty('passwordHash');
  });

  it('should return 409 for duplicate email', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'test@example.com', password: 'Passw0rd!', name: 'Test User' });

    expect(res.status).toBe(409);
    expect(res.body).toHaveProperty('error');
  });

  it('should return 400 for invalid password (no uppercase)', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'new@example.com', password: 'passw0rd!' });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });
});

describe('POST /api/auth/login', () => {
  it('should login and return 200 with token', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'Passw0rd!' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body.user).toHaveProperty('email', 'test@example.com');
  });

  it('should return 401 for wrong password', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'WrongPassword1' });

    expect(res.status).toBe(401);
    expect(res.body).toHaveProperty('error');
  });

  it('should return 401 for non-existent email', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'nobody@example.com', password: 'Passw0rd!' });

    expect(res.status).toBe(401);
    expect(res.body).toHaveProperty('error');
  });
});

describe('POST /api/auth/password/reset/request', () => {
  it('should return 200 ok for non-existent email (no info leak)', async () => {
    const res = await request(app)
      .post('/api/auth/password/reset/request')
      .send({ email: 'ghost@example.com' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('ok', true);
    expect(res.body).not.toHaveProperty('token');
  });

  it('should return 200 and a dev token for existing email', async () => {
    const res = await request(app)
      .post('/api/auth/password/reset/request')
      .send({ email: 'test@example.com' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('ok', true);
    expect(res.body).toHaveProperty('token');
  });
});

describe('POST /api/auth/password/reset/confirm', () => {
  let resetToken: string;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/password/reset/request')
      .send({ email: 'test@example.com' });
    resetToken = res.body.token as string;
  });

  it('should return 400 for an invalid token', async () => {
    const res = await request(app)
      .post('/api/auth/password/reset/confirm')
      .send({ token: 'invalid-token', newPassword: 'NewPassw0rd!' });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

  it('should reset password with a valid token', async () => {
    const res = await request(app)
      .post('/api/auth/password/reset/confirm')
      .send({ token: resetToken, newPassword: 'NewPassw0rd!' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('ok', true);
  });

  it('should return 400 when reusing an already-used token', async () => {
    const res = await request(app)
      .post('/api/auth/password/reset/confirm')
      .send({ token: resetToken, newPassword: 'AnotherPassw0rd!' });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });
});
