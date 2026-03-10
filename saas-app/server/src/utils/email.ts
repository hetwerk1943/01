/**
 * Nodemailer email utility.
 * Sends transactional emails (password reset, etc.).
 */
import nodemailer from 'nodemailer';
import { config } from '../config';
import { logger } from './logger';

// Create reusable transporter
const transporter = nodemailer.createTransport({
  host: config.smtp.host,
  port: config.smtp.port,
  auth: {
    user: config.smtp.user,
    pass: config.smtp.pass,
  },
});

export async function sendPasswordResetEmail(
  to: string,
  token: string
): Promise<void> {
  const resetUrl = `${config.clientOrigin}/reset-password?token=${token}`;

  try {
    await transporter.sendMail({
      from: config.smtp.from,
      to,
      subject: 'Password Reset Request',
      text: `Click the link to reset your password: ${resetUrl}\n\nThis link expires in ${config.resetTokenTtlMinutes} minutes.`,
      html: `
        <p>You requested a password reset.</p>
        <p><a href="${resetUrl}">Reset your password</a></p>
        <p>This link expires in ${config.resetTokenTtlMinutes} minutes.</p>
      `,
    });
    logger.info(`Password reset email sent to ${to}`);
  } catch (err) {
    logger.error(`Failed to send password reset email to ${to}`, err);
    throw err;
  }
}
