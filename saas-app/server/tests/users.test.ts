import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import app from '../src/app';

const prisma = new PrismaClient();

let testUserId: string;
let testToken: string;

beforeAll(async () => {
  await prisma.$connect();
  await prisma.passwordResetToken.deleteMany();
  await prisma.user.deleteMany();

  // Create test user via registration
  const res = await request(app)
    .post('/api/auth/register')
    .send({ email: 'users-test@example.com', password: 'Passw0rd!', name: 'Users Test' });

  testUserId = res.body.user.id;
  testToken = res.body.token;
});

afterAll(async () => {
  await prisma.passwordResetToken.deleteMany();
  await prisma.user.deleteMany();
  await prisma.$disconnect();
});

describe('GET /api/users/me', () => {
  it('should return 401 without token', async () => {
    const res = await request(app).get('/api/users/me');
    expect(res.status).toBe(401);
  });

  it('should return 401 with an invalid token', async () => {
    const res = await request(app)
      .get('/api/users/me')
      .set('Authorization', 'Bearer not-a-real-token');
    expect(res.status).toBe(401);
  });

  it('should return 200 with user data when authenticated', async () => {
    const res = await request(app)
      .get('/api/users/me')
      .set('Authorization', `Bearer ${testToken}`);

    expect(res.status).toBe(200);
    expect(res.body.user).toHaveProperty('email', 'users-test@example.com');
    expect(res.body.user).not.toHaveProperty('passwordHash');
  });
});

describe('PATCH /api/users/me', () => {
  it('should update name and return 200', async () => {
    const res = await request(app)
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${testToken}`)
      .send({ name: 'Updated Name' });

    expect(res.status).toBe(200);
    expect(res.body.user).toHaveProperty('name', 'Updated Name');
  });

  it('should return 400 for invalid email format', async () => {
    const res = await request(app)
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${testToken}`)
      .send({ email: 'not-an-email' });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });
});

describe('DELETE /api/users/me', () => {
  it('should delete the account and return 204', async () => {
    // Create a throwaway user to delete
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({ email: 'delete-me@example.com', password: 'Passw0rd!', name: 'To Delete' });

    const deleteToken: string = regRes.body.token;

    const res = await request(app)
      .delete('/api/users/me')
      .set('Authorization', `Bearer ${deleteToken}`);

    expect(res.status).toBe(204);

    // Confirm the user is gone
    const gone = await request(app)
      .get('/api/users/me')
      .set('Authorization', `Bearer ${deleteToken}`);
    expect(gone.status).toBe(404);
  });
});
