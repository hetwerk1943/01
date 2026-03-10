"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
/**
 * Auth integration tests – register, login, forgot/reset password.
 * Uses Supertest against the Express app; DB is mocked with Jest.
 */
const supertest_1 = __importDefault(require("supertest"));
const app_1 = require("../../src/app");
const client_1 = require("../../src/prisma/client");
const bcryptjs_1 = __importDefault(require("bcryptjs"));
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
const app = (0, app_1.createApp)();
const prismaMock = client_1.prisma;
beforeEach(() => {
    jest.clearAllMocks();
});
describe('POST /api/auth/register', () => {
    it('creates a new user and returns a JWT token', async () => {
        const mockUser = {
            id: 'user-1',
            email: 'test@example.com',
            name: 'Test User',
            role: 'USER',
            createdAt: new Date(),
        };
        prismaMock.user.findUnique.mockResolvedValue(null);
        prismaMock.user.create.mockResolvedValue(mockUser);
        const res = await (0, supertest_1.default)(app).post('/api/auth/register').send({
            email: 'test@example.com',
            password: 'Password123!',
            name: 'Test User',
        });
        expect(res.status).toBe(201);
        expect(res.body).toHaveProperty('token');
        expect(res.body.user.email).toBe('test@example.com');
    });
    it('returns 409 when email already registered', async () => {
        prismaMock.user.findUnique.mockResolvedValue({
            id: 'existing',
            email: 'existing@example.com',
        });
        const res = await (0, supertest_1.default)(app).post('/api/auth/register').send({
            email: 'existing@example.com',
            password: 'Password123!',
            name: 'Existing User',
        });
        expect(res.status).toBe(409);
        expect(res.body.message).toMatch(/already registered/i);
    });
    it('returns 400 for invalid email', async () => {
        const res = await (0, supertest_1.default)(app).post('/api/auth/register').send({
            email: 'not-an-email',
            password: 'Password123!',
            name: 'User',
        });
        expect(res.status).toBe(400);
    });
    it('returns 400 for weak password', async () => {
        const res = await (0, supertest_1.default)(app).post('/api/auth/register').send({
            email: 'test@example.com',
            password: 'weak',
            name: 'User',
        });
        expect(res.status).toBe(400);
    });
});
describe('POST /api/auth/login', () => {
    it('returns token for valid credentials', async () => {
        const hashedPw = await bcryptjs_1.default.hash('Password123!', 12);
        prismaMock.user.findUnique.mockResolvedValue({
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
        const res = await (0, supertest_1.default)(app).post('/api/auth/login').send({
            email: 'test@example.com',
            password: 'Password123!',
        });
        expect(res.status).toBe(200);
        expect(res.body).toHaveProperty('token');
        expect(res.body.user).not.toHaveProperty('password');
    });
    it('returns 401 for wrong password', async () => {
        const hashedPw = await bcryptjs_1.default.hash('CorrectPassword123!', 12);
        prismaMock.user.findUnique.mockResolvedValue({
            id: 'user-1',
            email: 'test@example.com',
            password: hashedPw,
            name: 'Test',
            role: 'USER',
        });
        const res = await (0, supertest_1.default)(app).post('/api/auth/login').send({
            email: 'test@example.com',
            password: 'WrongPassword123!',
        });
        expect(res.status).toBe(401);
    });
    it('returns 401 for non-existent user', async () => {
        prismaMock.user.findUnique.mockResolvedValue(null);
        const res = await (0, supertest_1.default)(app).post('/api/auth/login').send({
            email: 'noone@example.com',
            password: 'Password123!',
        });
        expect(res.status).toBe(401);
    });
});
describe('POST /api/auth/forgot-password', () => {
    it('returns 200 even if email not found (anti-enumeration)', async () => {
        prismaMock.user.findUnique.mockResolvedValue(null);
        const res = await (0, supertest_1.default)(app)
            .post('/api/auth/forgot-password')
            .send({ email: 'nobody@example.com' });
        expect(res.status).toBe(200);
        expect(res.body.message).toMatch(/reset link/i);
    });
    it('creates a reset token when email exists', async () => {
        prismaMock.user.findUnique.mockResolvedValue({
            id: 'user-1',
            email: 'test@example.com',
        });
        prismaMock.passwordResetToken.deleteMany.mockResolvedValue({});
        prismaMock.passwordResetToken.create.mockResolvedValue({});
        const res = await (0, supertest_1.default)(app)
            .post('/api/auth/forgot-password')
            .send({ email: 'test@example.com' });
        expect(res.status).toBe(200);
        expect(prismaMock.passwordResetToken.create).toHaveBeenCalled();
    });
});
describe('POST /api/auth/reset-password', () => {
    it('returns 400 for invalid/expired token', async () => {
        prismaMock.passwordResetToken.findUnique.mockResolvedValue(null);
        const res = await (0, supertest_1.default)(app)
            .post('/api/auth/reset-password')
            .send({ token: 'invalid-token', password: 'NewPassword123!' });
        expect(res.status).toBe(400);
    });
    it('resets password with valid token', async () => {
        prismaMock.passwordResetToken.findUnique.mockResolvedValue({
            id: 'token-1',
            token: 'valid-token',
            userId: 'user-1',
            expiresAt: new Date(Date.now() + 60 * 60 * 1000),
            usedAt: null,
        });
        prismaMock.$transaction.mockResolvedValue([{}, {}]);
        const res = await (0, supertest_1.default)(app)
            .post('/api/auth/reset-password')
            .send({ token: 'valid-token', password: 'NewPassword123!' });
        expect(res.status).toBe(200);
        expect(res.body.message).toMatch(/reset successfully/i);
    });
});
describe('GET /api/auth/me', () => {
    it('returns 401 without token', async () => {
        const res = await (0, supertest_1.default)(app).get('/api/auth/me');
        expect(res.status).toBe(401);
    });
    it('returns user info with valid token', async () => {
        // Generate a real token
        const { signToken } = await Promise.resolve().then(() => __importStar(require('../../src/utils/jwt')));
        const token = signToken({
            userId: 'user-1',
            email: 'test@example.com',
            role: 'USER',
        });
        const res = await (0, supertest_1.default)(app)
            .get('/api/auth/me')
            .set('Authorization', `Bearer ${token}`);
        expect(res.status).toBe(200);
        expect(res.body.user.email).toBe('test@example.com');
    });
});
//# sourceMappingURL=auth.test.js.map