/**
 * Lambda: singha-refresh-token
 * ============================
 * Validates refresh token and issues new access token
 * 
 * Best Practice: Short-lived access tokens + long-lived refresh tokens
 * Prevents unauthorized access if access token is compromised
 * Refresh token rotation on each refresh
 * 
 * Required IAM Permissions:
 * - ssm:GetParameter
 * - kms:Decrypt
 */

import jwt from 'jsonwebtoken';
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';

const ssm = new SSMClient({ region: process.env.AWS_REGION || 'us-east-1' });

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,POST'
};

/**
 * Retrieve JWT secret from Parameter Store
 */
async function getJWTSecret() {
  try {
    const command = new GetParameterCommand({
      Name: '/singha/jwt/secret',
      WithDecryption: true
    });
    const result = await ssm.send(command);
    return result.Parameter.Value;
  } catch (error) {
    console.error('Error retrieving JWT secret:', error);
    throw new Error('Failed to retrieve JWT secret');
  }
}

/**
 * Generate JWT token
 */
function generateToken(email, secret, expiresIn) {
  return jwt.sign(
    {
      email,
      role: 'admin',
      userId: 'admin-001',
    },
    secret,
    { expiresIn }
  );
}

/**
 * Main Lambda handler
 * Validates refresh token and issues new tokens
 */
export const handler = async (event) => {
  try {
    // Parse request body
    const { refreshToken } = JSON.parse(event.body || '{}');

    // Input validation
    if (!refreshToken) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ 
          error: 'Refresh token is required' 
        }),
      };
    }

    // Retrieve JWT secret
    const jwtSecret = await getJWTSecret();

    // Verify and decode refresh token
    let decoded;
    try {
      decoded = jwt.verify(refreshToken, jwtSecret);
    } catch (error) {
      // Token verification failed (invalid or expired)
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ 
          error: 'Invalid or expired refresh token' 
        }),
      };
    }

    // Extract email from decoded token
    const email = decoded.email;

    // Generate new access token (1 hour)
    const newAccessToken = generateToken(email, jwtSecret, '1h');

    // Generate new refresh token (7 days) - token rotation
    const newRefreshToken = generateToken(email, jwtSecret, '7d');

    // Success response
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        token: newAccessToken,
        refreshToken: newRefreshToken,
      }),
    };
  } catch (error) {
    console.error('Token refresh error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ 
        error: 'Internal server error' 
      }),
    };
  }
};