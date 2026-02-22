import { describe, it, expect, beforeEach, vi } from 'vitest';
import { registerCustomer, getCustomerPoints } from './customerController.js';

describe('Customer Controller - Unit Tests', () => {
  let mockReq, mockRes, mockConnection;

  beforeEach(() => {
    // Setup mock request
    mockReq = {
      body: {},
      params: {},
      db: null,
    };

    // Setup mock response
    mockRes = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    // Setup mock database connection
    mockConnection = {
      query: vi.fn(),
    };

    mockReq.db = mockConnection;
  });

  describe('registerCustomer', () => {
    it('should register a new customer successfully', async () => {
      // Arrange
      mockReq.body = {
        phone: '0812345678',
        name: 'John Doe',
        email: 'john@example.com',
      };

      mockConnection.query.mockResolvedValueOnce([{ insertId: 1 }]);

      // Act
      await registerCustomer(mockReq, mockRes);

      // Assert
      expect(mockRes.status).toHaveBeenCalledWith(201);
      expect(mockRes.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          customer: expect.objectContaining({
            id: 1,
            phone: '0812345678',
          }),
        })
      );
    });

    it('should return 400 if phone number is missing', async () => {
      // Arrange
      mockReq.body = {
        name: 'John Doe',
        // phone is missing
      };

      // Act
      await registerCustomer(mockReq, mockRes);

      // Assert
      expect(mockRes.status).toHaveBeenCalledWith(400);
      expect(mockRes.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: false,
          error: expect.stringContaining('phone'),
        })
      );
    });

    it('should return 409 if phone number already exists', async () => {
      // Arrange
      mockReq.body = {
        phone: '0812345678',
        name: 'John Doe',
      };

      mockConnection.query.mockRejectedValueOnce({
        code: 'ER_DUP_ENTRY',
      });

      // Act
      await registerCustomer(mockReq, mockRes);

      // Assert
      expect(mockRes.status).toHaveBeenCalledWith(409);
      expect(mockRes.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: false,
          error: expect.stringContaining('already exists'),
        })
      );
    });
  });

  describe('getCustomerPoints', () => {
    it('should return customer points successfully', async () => {
      // Arrange
      mockReq.params = { phone: '0812345678' };
      mockConnection.query.mockResolvedValueOnce([
        [{ id: 1, phone: '0812345678', name: 'John Doe', points: 100 }],
      ]);

      // Act
      await getCustomerPoints(mockReq, mockRes);

      // Assert
      expect(mockRes.status).toHaveBeenCalledWith(200);
      expect(mockRes.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          customer: expect.objectContaining({
            points: 100,
          }),
        })
      );
    });

    it('should return 404 if customer not found', async () => {
      // Arrange
      mockReq.params = { phone: '0899999999' };
      mockConnection.query.mockResolvedValueOnce([[]]);

      // Act
      await getCustomerPoints(mockReq, mockRes);

      // Assert
      expect(mockRes.status).toHaveBeenCalledWith(404);
    });
  });
});