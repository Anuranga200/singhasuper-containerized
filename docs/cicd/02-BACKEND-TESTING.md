# Backend Testing Infrastructure Setup

## Why Testing Matters in CI/CD

**Without tests**: You're deploying blind. Bugs reach production.
**With tests**: Catch bugs before deployment. Deploy with confidence.

**Industry Standard**: 60-80% code coverage for backend services.

## Current State Analysis

Your backend currently has:
- ❌ No test framework
- ❌ No test files
- ❌ No test scripts in package.json
- ✅ Well-structured code (easy to test)

## Step 1: Install Testing Dependencies

Navigate to server directory and install Vitest:

```bash
cd server
npm install --save-dev vitest @vitest/ui c8
npm install --save-dev supertest  # For API testing
npm install --save-dev @types/supertest  # TypeScript types
```

**Why Vitest?**
- **Fast**: Native ESM support, parallel execution
- **Modern**: Better DX than Jest
- **Consistent**: Same framework as frontend
- **Coverage**: Built-in coverage with c8

**Why Supertest?**
- **API Testing**: Test HTTP endpoints without running server
- **Integration**: Works seamlessly with Express
- **Assertions**: Clean API for testing responses

## Step 2: Create Vitest Configuration

Create `server/vitest.config.js`:

```javascript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Use Node.js environment (not jsdom like frontend)
    environment: 'node',
    
    // Global test utilities
    globals: true,
    
    // Setup file for test initialization
    setupFiles: ['./src/test/setup.js'],
    
    // Test file patterns
    include: ['src/**/*.{test,spec}.{js,ts}'],
    
    // Coverage configuration
    coverage: {
      provider: 'c8',
      reporter: ['text', 'json', 'html', 'lcov'],
      exclude: [
        'node_modules/',
        'src/test/',
        '**/*.test.js',
        '**/*.spec.js',
      ],
      // Minimum coverage thresholds
      lines: 60,
      functions: 60,
      branches: 60,
      statements: 60,
    },
    
    // Test timeout (for slow integration tests)
    testTimeout: 10000,
    
    // Retry flaky tests once
    retry: 1,
  },
});
```

**Configuration Explained**:
- `environment: 'node'`: Backend runs in Node, not browser
- `globals: true`: Use `describe`, `it`, `expect` without imports
- `coverage.lines: 60`: Fail if coverage below 60%
- `testTimeout: 10000`: 10 seconds for DB tests
- `retry: 1`: Retry flaky tests once (network issues, etc.)

## Step 3: Update package.json Scripts

Add to `server/package.json`:

```json
{
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "migrate": "node src/db/migrate.js",
    "seed": "node src/db/seed.js",
    "verify": "node verify-tables.js",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest run --coverage",
    "test:integration": "vitest run --grep integration"
  }
}
```

**Script Purposes**:
- `test`: Run all tests once (for CI)
- `test:watch`: Watch mode for development
- `test:ui`: Visual test UI (great for debugging)
- `test:coverage`: Generate coverage report
- `test:integration`: Run only integration tests

## Step 4: Create Test Setup File

Create `server/src/test/setup.js`:

```javascript
import { beforeAll, afterAll, beforeEach, afterEach } from 'vitest';
import dotenv from 'dotenv';

// Load test environment variables
dotenv.config({ path: '.env.test' });

// Global test setup
beforeAll(async () => {
  console.log('🧪 Starting test suite...');
  // Setup test database connection
  // Initialize test data
});

afterAll(async () => {
  console.log('✅ Test suite completed');
  // Close database connections
  // Cleanup resources
});

// Reset state between tests
beforeEach(async () => {
  // Clear test data
  // Reset mocks
});

afterEach(async () => {
  // Cleanup after each test
});

// Global test utilities
global.testUtils = {
  // Add helper functions here
  createTestUser: async (data) => {
    // Helper to create test user
  },
  cleanupTestData: async () => {
    // Helper to cleanup test data
  },
};
```

## Step 5: Create Test Environment File

Create `server/.env.test`:

```bash
# Test Environment Configuration
NODE_ENV=test

# Test Database (separate from dev/prod!)
DB_HOST=localhost
DB_PORT=3306
DB_USER=test_user
DB_PASSWORD=test_password
DB_NAME=singha_loyalty_test

# Test JWT Secret
JWT_SECRET=test-jwt-secret-min-32-characters-long

# Test Server Port
PORT=3001

# Disable logging in tests
LOG_LEVEL=error
```

**Why separate test environment?**
- **Isolation**: Don't pollute dev database
- **Speed**: Can truncate tables without worry
- **Parallel**: Run tests in parallel safely
- **CI**: GitHub Actions will use this

## Step 6: Create Test Database Configuration

Create `server/src/config/database.test.js`:

```javascript
import mysql from 'mysql2/promise';
import dotenv from 'dotenv';

dotenv.config({ path: '.env.test' });

export const createTestConnection = async () => {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
  });

  return connection;
};

export const setupTestDatabase = async () => {
  const connection = await createTestConnection();
  
  // Run migrations
  await connection.query(`
    CREATE TABLE IF NOT EXISTS customers (
      id INT AUTO_INCREMENT PRIMARY KEY,
      phone VARCHAR(20) UNIQUE NOT NULL,
      name VARCHAR(255) NOT NULL,
      email VARCHAR(255),
      points INT DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  await connection.query(`
    CREATE TABLE IF NOT EXISTS transactions (
      id INT AUTO_INCREMENT PRIMARY KEY,
      customer_id INT NOT NULL,
      points INT NOT NULL,
      type ENUM('earn', 'redeem') NOT NULL,
      description TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (customer_id) REFERENCES customers(id)
    )
  `);

  return connection;
};

export const cleanupTestDatabase = async (connection) => {
  await connection.query('DELETE FROM transactions');
  await connection.query('DELETE FROM customers');
};

export const closeTestConnection = async (connection) => {
  await connection.end();
};
```


## Step 7: Write Unit Tests for Controllers

Create `server/src/controllers/customerController.test.js`:

```javascript
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
```

**Test Structure Explained**:
- `describe`: Group related tests
- `beforeEach`: Setup before each test (fresh mocks)
- `it`: Individual test case
- `expect`: Assertions
- `vi.fn()`: Vitest mock function

**AAA Pattern**:
1. **Arrange**: Setup test data
2. **Act**: Execute function
3. **Assert**: Verify results

## Step 8: Write Integration Tests

Create `server/src/controllers/customerController.integration.test.js`:

```javascript
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
```

**Integration Test Benefits**:
- **Real Database**: Tests actual SQL queries
- **Full Stack**: Tests routes + controllers + database
- **Confidence**: If these pass, API works

## Step 9: Write Middleware Tests

Create `server/src/middleware/auth.test.js`:

```javascript
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
```

## Step 10: Run Tests Locally

```bash
# Run all tests
cd server
npm test

# Run with coverage
npm run test:coverage

# Run in watch mode (for development)
npm run test:watch

# Run only integration tests
npm run test:integration
```

**Expected Output**:
```
✓ src/controllers/customerController.test.js (8 tests) 234ms
✓ src/controllers/customerController.integration.test.js (5 tests) 456ms
✓ src/middleware/auth.test.js (4 tests) 123ms

Test Files  3 passed (3)
     Tests  17 passed (17)
  Start at  10:30:00
  Duration  813ms

 % Coverage report from c8
--------------------|---------|----------|---------|---------|
File                | % Stmts | % Branch | % Funcs | % Lines |
--------------------|---------|----------|---------|---------|
All files           |   68.42 |    62.50 |   70.00 |   68.42 |
 controllers        |   75.00 |    66.67 |   80.00 |   75.00 |
  customerController|   75.00 |    66.67 |   80.00 |   75.00 |
 middleware         |   85.71 |    75.00 |   100.0 |   85.71 |
  auth.js           |   85.71 |    75.00 |   100.0 |   85.71 |
--------------------|---------|----------|---------|---------|
```

## Step 11: Setup GitHub Actions MySQL Service

This will be used in CI workflow (we'll create this in next phase):

```yaml
services:
  mysql:
    image: mysql:8.0
    env:
      MYSQL_ROOT_PASSWORD: test_password
      MYSQL_DATABASE: singha_loyalty_test
      MYSQL_USER: test_user
      MYSQL_PASSWORD: test_password
    ports:
      - 3306:3306
    options: >-
      --health-cmd="mysqladmin ping --silent"
      --health-interval=10s
      --health-timeout=5s
      --health-retries=3
```

## Troubleshooting

### Issue: Tests timeout

**Solution**: Increase timeout in vitest.config.js:
```javascript
testTimeout: 30000, // 30 seconds
```

### Issue: Database connection fails

**Solution**: Check MySQL is running:
```bash
# Windows
net start MySQL80

# Or use Docker
docker run -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=test_password mysql:8.0
```

### Issue: Coverage below threshold

**Solution**: Write more tests or adjust threshold temporarily:
```javascript
coverage: {
  lines: 50, // Lower threshold temporarily
}
```

## Best Practices

1. **Test Naming**: Use descriptive names
   - ✅ `should return 404 if customer not found`
   - ❌ `test1`

2. **Test Independence**: Each test should work alone
   - Don't rely on test execution order
   - Clean up after each test

3. **Mock External Services**: Don't call real APIs in tests
   - Mock AWS, payment gateways, etc.

4. **Fast Tests**: Keep tests fast (< 5 seconds total)
   - Use in-memory database for unit tests
   - Limit integration tests

5. **Coverage ≠ Quality**: 100% coverage doesn't mean bug-free
   - Focus on critical paths
   - Test edge cases

## Next Steps

✅ Backend testing infrastructure complete!

Proceed to: [CI Workflow Implementation](./03-CI-WORKFLOW.md)
