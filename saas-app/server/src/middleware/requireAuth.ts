/**
 * requireAuth middleware – validates the Bearer JWT in the Authorization header.
 * Attaches the decoded user payload to req.user.
 */
import { Request, Response, NextFunction } from 'express';
import { verifyToken, JwtPayload } from '../utils/jwt';
import { logger } from '../utils/logger';

// Extend Express Request to carry user payload
declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
    }
  }
}

export function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ message: 'Authorization token missing' });
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    const payload = verifyToken(token);
    req.user = payload;
    next();
  } catch (err) {
    logger.warn('Invalid or expired JWT', { err });
    res.status(401).json({ message: 'Invalid or expired token' });
  }
}
