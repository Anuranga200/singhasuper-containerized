/**
 * Lambda: singha-fetch-customers
 * ==============================
 * Fetches all non-deleted customers
 * Protected endpoint - requires valid JWT token
 * 
 * Best Practice:
 * - Validate JWT on every request
 * - Return only non-deleted records
 * - Log authorization failures for security audit
 * 
 * Required IAM Permissions:
 * - dynamodb:Scan
 * - ssm:GetParameter
 * - kms:Decrypt
 */

import jwt from 'jsonwebtoken';
import { DynamoDBClient, ScanCommand } from '@aws-sdk/client-dynamodb';
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';
import { unmarshall } from '@aws-sdk/util-dynamodb';

const dynamodb = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const ssm = new SSMClient({ region: process.env.AWS_REGION || 'us-east-1' });

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,OPTIONS'
};

/**
 * Extract JWT from Authorization header
 * Expected format: "Bearer <token>"
 * 
 * @param authHeader - Authorization header value
 * @returns string|null - JWT token or null if invalid format
 */
function extractToken(authHeader) {
  if (!authHeader) {
    console.warn('No Authorization header provided');
    return null;
  }

  const parts = authHeader.split(' ');
  
  // Validate Bearer scheme
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    console.warn('Invalid Authorization header format');
    return null;
  }

  return parts[1];
}

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
 * Verify and validate JWT token
 * 
 * @param token - JWT token to verify
 * @param secret - JWT signing secret
 * @returns object|null - Decoded token or null if invalid
 */
function verifyToken(token, secret) {
  try {
    const decoded = jwt.verify(token, secret);
    return decoded;
  } catch (error) {
    console.error('Token verification failed:', error.message);
    return null;
  }
}

/**
 * Main Lambda handler
 * Validates JWT and returns customers
 */
export const handler = async (event) => {
  try {
    // Extract token from Authorization header
    const token = extractToken(event.headers?.Authorization);

    // Token is required
    if (!token) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ 
          error: 'Missing authorization token' 
        }),
      };
    }

    // Retrieve JWT secret
    const jwtSecret = await getJWTSecret();

    // Verify token validity
    const decoded = verifyToken(token, jwtSecret);
    if (!decoded) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ 
          error: 'Invalid or expired token' 
        }),
      };
    }

    // Log successful authorization
    console.log(`Authorized request from: ${decoded.email}`);

    // Fetch all customers from DynamoDB
    // Filter applied here: isDeleted != true
    const command = new ScanCommand({
      TableName: 'singha-customers',
      FilterExpression: 'attribute_not_exists(isDeleted) OR isDeleted = :false',
      ExpressionAttributeValues: {
        ':false': { BOOL: false }
      }
    });

    const result = await dynamodb.send(command);

    // Convert DynamoDB format to plain JSON
    const customers = (result.Items || []).map(item => unmarshall(item));

    // Success response
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        customers,
        count: customers.length
      }),
    };
  } catch (error) {
    console.error('Error fetching customers:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ 
        error: 'Internal server error' 
      }),
    };
  }
};