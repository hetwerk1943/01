# SaaS App

A production-ready, full-stack SaaS web application built with modern technologies.

## Tech Stack

| Layer       | Technology                                    |
|-------------|-----------------------------------------------|
| Frontend    | React 18 + TypeScript + TailwindCSS + Vite    |
| Backend     | Node.js + Express + TypeScript                |
| Database    | PostgreSQL 16                                 |
| ORM         | Prisma 5                                      |
| Auth        | JWT (jsonwebtoken) + bcryptjs                 |
| Validation  | Zod                                           |
| Testing     | Jest + Supertest                              |
| DevOps      | Docker + Docker Compose + GitHub Actions CI   |

## Features

- **User registration & login** with JWT authentication
- **Password reset** via email token
- **User profile CRUD** (name, bio, avatar)
- **Password change** from the profile page
- **Dashboard** with account overview
- **Admin user list** (role-based access)
- **Rate limiting** (global + strict auth limiter)
- **Request logging** via morgan + winston
- **Centralized error handling** with consistent JSON responses
- **Input validation** on all endpoints using Zod schemas

## Directory Structure

```
saas-app/
├── client/                  # React frontend (Vite)
│   ├── src/
│   │   ├── api/             # Axios API calls
│   │   ├── components/      # Shared UI components
│   │   ├── pages/           # Route page components
│   │   ├── store/           # Zustand auth store
│   │   └── types/           # TypeScript interfaces
│   └── ...
├── server/                  # Express API
│   ├── src/
│   │   ├── config/          # App configuration
│   │   ├── middleware/       # Auth, error, logger, rate limiter
│   │   ├── modules/
│   │   │   ├── auth/        # Register / login / reset password
│   │   │   └── users/       # Profile CRUD
│   │   ├── prisma/          # Prisma client singleton
│   │   └── utils/           # JWT helpers, logger, email, validators
│   └── prisma/
│       ├── schema.prisma    # Database schema
│       └── seed.ts          # Sample data
├── database/                # DB docs / raw SQL reference
├── docker/                  # Dockerfiles + nginx config
├── tests/                   # Integration tests (Jest + Supertest)
│   └── integration/
├── .github/workflows/       # CI/CD GitHub Actions
├── docker-compose.yml
├── .env.example
└── README.md
```

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) ≥ 24
- [Docker Compose](https://docs.docker.com/compose/install/) ≥ 2

### 1. Clone and configure

```bash
git clone https://github.com/hetwerk1943/01
cd 01/saas-app

# Copy and review environment variables
cp .env.example .env
```

### 2. Start everything with Docker Compose

```bash
docker compose up --build
```

This starts:
- **PostgreSQL** on port `5432`
- **Express API** on port `4000` (runs Prisma migrations automatically)
- **React client** on port `80` (served by nginx)

Open [http://localhost](http://localhost) in your browser.

**Demo credentials (created by seed):**

| Email               | Password       | Role  |
|---------------------|----------------|-------|
| admin@example.com   | Password123!   | ADMIN |
| demo@example.com    | Password123!   | USER  |

### 3. Local development (without Docker)

**Backend:**

```bash
cd server
npm install
cp .env.example .env   # set DATABASE_URL to your local Postgres
npx prisma migrate dev --name init
npx prisma db seed
npm run dev            # starts on http://localhost:4000
```

**Frontend:**

```bash
cd client
npm install
npm run dev            # starts on http://localhost:5173
```

## Running Tests

```bash
cd server
npm test
```

Tests mock the Prisma client and email utility – no database required.

## API Reference

All API endpoints are prefixed with `/api`.

### Auth endpoints

#### `POST /api/auth/register`
Register a new user.

```json
// Request body
{
  "email": "user@example.com",
  "password": "Password123!",
  "name": "Jane Doe"
}

// Response 201
{
  "user": { "id": "...", "email": "...", "name": "...", "role": "USER", "createdAt": "..." },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

#### `POST /api/auth/login`
Authenticate an existing user.

```json
// Request body
{
  "email": "user@example.com",
  "password": "Password123!"
}

// Response 200
{
  "user": { "id": "...", "email": "...", ... },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

#### `GET /api/auth/me`  *(requires Bearer token)*
Return the currently authenticated user's JWT payload.

```json
// Response 200
{
  "user": { "userId": "...", "email": "...", "role": "USER" }
}
```

#### `POST /api/auth/forgot-password`
Send a password reset email.

```json
// Request body
{ "email": "user@example.com" }

// Response 200 (always, to prevent email enumeration)
{ "message": "If that email is registered, a reset link was sent." }
```

#### `POST /api/auth/reset-password`
Reset password using the token from the email.

```json
// Request body
{ "token": "<uuid-token>", "password": "NewPassword123!" }

// Response 200
{ "message": "Password reset successfully" }
```

### Users endpoints *(all require `Authorization: Bearer <token>`)*

#### `GET /api/users/profile`
Get the authenticated user's full profile.

```json
// Response 200
{
  "user": { "id": "...", "email": "...", "name": "...", "bio": null, "avatarUrl": null, ... }
}
```

#### `PATCH /api/users/profile`
Update mutable profile fields.

```json
// Request body (all fields optional)
{ "name": "New Name", "bio": "Hello!", "avatarUrl": "https://..." }

// Response 200
{ "user": { ... } }
```

#### `POST /api/users/change-password`
Change password from the profile settings.

```json
// Request body
{ "currentPassword": "OldPassword1!", "newPassword": "NewPassword1!" }

// Response 200
{ "message": "Password changed successfully" }
```

#### `DELETE /api/users/account`
Permanently delete the authenticated user's account.

```json
// Response 200
{ "message": "Account deleted successfully" }
```

#### `GET /api/users` *(ADMIN only)*
List all users with pagination.

```
GET /api/users?page=1&limit=20

// Response 200
{
  "users": [...],
  "total": 42,
  "page": 1,
  "limit": 20,
  "totalPages": 3
}
```

### Health check

#### `GET /health`
Returns server status (no auth required).

```json
{ "status": "ok", "timestamp": "2026-01-01T00:00:00.000Z" }
```

## Environment Variables

See [`.env.example`](.env.example) for all available configuration options.

| Variable                 | Description                                | Default                  |
|--------------------------|--------------------------------------------|--------------------------|
| `DATABASE_URL`           | PostgreSQL connection string               | *required*               |
| `JWT_SECRET`             | Secret for signing JWTs                    | *required*               |
| `JWT_EXPIRES_IN`         | JWT expiry duration                        | `7d`                     |
| `RESET_TOKEN_TTL_MINUTES`| Password reset token TTL                  | `60`                     |
| `CLIENT_ORIGIN`          | Allowed CORS origin                        | `http://localhost:5173`  |
| `SMTP_HOST`              | SMTP server hostname                       | `smtp.ethereal.email`    |
| `RATE_LIMIT_MAX`         | Max requests per window                    | `100`                    |

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push/PR touching `saas-app/**`:

1. **Backend job** – installs deps, generates Prisma client, runs migrations against a test Postgres service, builds TypeScript, runs Jest tests.
2. **Frontend job** – installs deps, runs `npm run build` (includes TypeScript type-checking via tsc).
A production-ready SaaS application scaffold built with Node.js, Express, Prisma, React, and TypeScript.

## Stack

- **Backend**: Node.js, Express, TypeScript, Prisma ORM, PostgreSQL
- **Frontend**: React 18, TypeScript, Vite, TailwindCSS, React Router v6
- **Auth**: JWT, bcryptjs, password reset flow
- **Testing**: Jest, Supertest
- **Infrastructure**: Docker, Docker Compose, GitHub Actions CI

## Quick Start with Docker

```bash
cp .env.example .env
docker-compose up --build
```

- Client: http://localhost:3000
- Server: http://localhost:4000
- DB: localhost:5432

## Local Development

### Prerequisites
- Node.js 20+
- PostgreSQL 16+

### Install & Run

```bash
# 1. Install database deps and generate Prisma client
cd database && npm install && npm run generate && npm run migrate && npm run seed
cd ..

# 2. Install and start server
cd server && npm install && npm run generate && npm run dev
cd ..

# 3. Install and start client
cd client && npm install && npm run dev
```

## API Examples

### Register
```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"Passw0rd!","name":"Alice"}'
```

### Login
```bash
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"Passw0rd!"}'
```

### Get Me
```bash
curl http://localhost:4000/api/users/me \
  -H "Authorization: Bearer <token>"
```

### Update Me
```bash
curl -X PATCH http://localhost:4000/api/users/me \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name":"Bob"}'
```
