/**
 * Prisma seed – populates the database with sample users for development.
 * Run: npx ts-node prisma/seed.ts
 */
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const hashed = await bcrypt.hash('Password123!', 12);

  // Create admin user
  const admin = await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: {},
    create: {
      email: 'admin@example.com',
      password: hashed,
      name: 'Admin User',
      bio: 'Platform administrator',
      role: 'ADMIN',
      isVerified: true,
    },
  });

  // Create regular demo user
  const demo = await prisma.user.upsert({
    where: { email: 'demo@example.com' },
    update: {},
    create: {
      email: 'demo@example.com',
      password: hashed,
      name: 'Demo User',
      bio: 'A sample SaaS user',
      role: 'USER',
      isVerified: true,
    },
  });

  console.log('Seeded users:', { admin: admin.email, demo: demo.email });
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
