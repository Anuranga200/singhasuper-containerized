import { describe, it, expect, beforeEach, vi } from 'vitest';
import jwt from 'jsonwebtoken';
import { authenticateAdmin } from './auth.js';

describe('Auth Middleware - Unit Tests', () => {
  let mockReq, mockRes, mockNext;

  beforeEach(() => {
    mockReq = {
      headers: {},
    };

    mockRes = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    mockNext = vi.fn();
  });

  it('should authenticate valid JWT token', () => {
    // Create valid token
    const token = jwt.sign(
      { username: 'admin', role: 'admin' },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );

    mockReq.headers.authorization = `Bearer ${token}`;

    // Execute middleware
    authenticateAdmin(mockReq, mockRes, mockNext);

    // Should call next() and attach user to request
    expect(mockNext).toHaveBeenCalled();
    expect(mockReq.user).toMatchObject({
      username: 'admin',
      role: 'admin',
    });
  });

  it('should reject missing token', () => {
    // No authorization header
    authenticateAdmin(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.stringContaining('token'),
      })
    );
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('should reject invalid token', () => {
    mockReq.headers.authorization = 'Bearer invalid-token';

    authenticateAdmin(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('should reject expired token', () => {
    // Create expired token
    const token = jwt.sign(
      { username: 'admin' },
      process.env.JWT_SECRET,
      { expiresIn: '-1h' } // Expired 1 hour ago
    );

    mockReq.headers.authorization = `Bearer ${token}`;

    authenticateAdmin(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.stringContaining('expired'),
      })
    );
  });
});