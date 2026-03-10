# SaaS App

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
