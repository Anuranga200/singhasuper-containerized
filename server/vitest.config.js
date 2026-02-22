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