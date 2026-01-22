/**
 * Lambda: singha-admin-login
 * =========================
 * Authenticates admin user and returns JWT tokens
 * 
 * Uses AWS Parameter Store for credentials (encrypted)
 * Generates both short-lived (1h) and long-lived (7d) tokens
 * 
 * Required IAM Permissions:
 * - ssm:GetParameter
 * - kms:Decrypt (for encrypted parameters)
 */

import jwt from 'jsonwebtoken';
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';

const ssm = new SSMClient({ region: process.env.AWS_REGION || 'us-east-1' });

// CORS headers for all responses
const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
};

/**
 * Retrieve credentials from Parameter Store
 * Best Practice: Never hardcode credentials
 * Credentials are encrypted in Parameter Store
 * 
 * @param parameterName - Parameter name in SSM
 * @returns Promise<string> - Parameter value
 */
async function getParameter(parameterName) {
  try {
    const command = new GetParameterCommand({
      Name: parameterName,
      WithDecryption: true // Decrypt if using SecureString type
    });
    const result = await ssm.send(command);
    return result.Parameter.Value;
  } catch (error) {
    console.error(`Error retrieving parameter ${parameterName}:`, error);
    throw new Error('Failed to retrieve credentials');
  }
}

/**
 * Retrieve JWT secret from Parameter Store
 * Best Practice: Store secrets encrypted in Parameter Store
 * 
 * @returns Promise<string> - JWT signing secret
 */
async function getJWTSecret() {
  return await getParameter('/singha/jwt/secret');
}

/**
 * Generate JWT token with claims
 * 
 * @param email - Admin email
 * @param secret - JWT signing secret
 * @param expiresIn - Token expiration time (e.g., '1h')
 * @returns string - Signed JWT token
 */
function generateToken(email, secret, expiresIn) {
  return jwt.sign(
    {
      email,
      role: 'admin',
      userId: 'admin-001',
      // Standard claims
      iat: Math.floor(Date.now() / 1000), // issued at
    },
    secret,
    { expiresIn }
  );
}

/**
 * Main Lambda handler
 * Validates credentials and returns JWT tokens
 */
export const handler = async (event) => {
  try {
    // Parse request body
    const { email, password } = JSON.parse(event.body || '{}');

    // Input validation
    if (!email || !password) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ 
          error: 'Email and password are required' 
        }),
      };
    }

    // Retrieve admin credentials from Parameter Store
    const validEmail = await getParameter('/singha/admin/email');
    const validPassword = await getParameter('/singha/admin/password');

    // Compare credentials (in production, use bcrypt for password comparison)
    if (email !== validEmail || password !== validPassword) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ 
          error: 'Invalid email or password.' 
        }),
      };
    }

    // Retrieve JWT secret
    const jwtSecret = await getJWTSecret();

    // Generate access token (short-lived: 1 hour)
    const accessToken = generateToken(email, jwtSecret, '1h');

    // Generate refresh token (long-lived: 7 days)
    const refreshToken = generateToken(email, jwtSecret, '7d');

    // Success response
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        token: accessToken,
        refreshToken: refreshToken,
      }),
    };
  } catch (error) {
    console.error('Login error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ 
        error: 'Internal server error' 
      }),
    };
  }
};