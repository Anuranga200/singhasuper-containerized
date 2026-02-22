import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';
import customerRoutes from '../routes/customer.js';
import { setupTestDatabase, cleanupTestDatabase, closeTestConnection } from '../config/database.test.js';

describe('Customer API - Integration Tests', () => {
  let app;
  let connection;

  beforeAll(async () => {
    // Setup test database
    connection = await setupTestDatabase();

    // Create Express app
    app = express();
    app.use(express.json());
    
    // Attach database to request
    app.use((req, res, next) => {
      req.db = connection;
      next();
    });

    // Mount routes
    app.use('/api/customers', customerRoutes);
  });

  afterAll(async () => {
    await closeTestConnection(connection);
  });

  beforeEach(async () => {
    // Clean database before each test
    await cleanupTestDatabase(connection);
  });

  describe('POST /api/customers/register', () => {
    it('should register a new customer', async () => {
      const response = await request(app)
        .post('/api/customers/register')
        .send({
          phone: '0812345678',
          name: 'John Doe',
          email: 'john@example.com',
        })
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.customer).toMatchObject({
        phone: '0812345678',
        name: 'John Doe',
        points: 0,
      });

      // Verify in database
      const [rows] = await connection.query(
        'SELECT * FROM customers WHERE phone = ?',
        ['0812345678']
      );
      expect(rows).toHaveLength(1);
      expect(rows[0].name).toBe('John Doe');
    });

    it('should reject duplicate phone numbers', async () => {
      // Register first customer
      await request(app)
        .post('/api/customers/register')
        .send({
          phone: '0812345678',
          name: 'John Doe',
        })
        .expect(201);

      // Try to register again with same phone
      const response = await request(app)
        .post('/api/customers/register')
        .send({
          phone: '0812345678',
          name: 'Jane Doe',
        })
        .expect(409);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('already exists');
    });

    it('should validate required fields', async () => {
      const response = await request(app)
        .post('/api/customers/register')
        .send({
          name: 'John Doe',
          // phone is missing
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/customers/:phone/points', () => {
    it('should return customer points', async () => {
      // Create test customer
      await connection.query(
        'INSERT INTO customers (phone, name, points) VALUES (?, ?, ?)',
        ['0812345678', 'John Doe', 150]
      );

      const response = await request(app)
        .get('/api/customers/0812345678/points')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.customer.points).toBe(150);
    });

    it('should return 404 for non-existent customer', async () => {
      await request(app)
        .get('/api/customers/0899999999/points')
        .expect(404);
    });
  });
});