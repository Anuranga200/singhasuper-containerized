/**
 * Lambda: singha-delete-customer
 * ==============================
 * Soft deletes a customer (marks as deleted, doesn't remove)
 * Protected endpoint - requires valid JWT token
 * 
 * Best Practice: Soft Delete instead of Hard Delete
 * - Preserves data for auditing and recovery
 * - Sets isDeleted flag and deletedAt timestamp
 * - Can be restored if needed
 * 
 * Required IAM Permissions:
 * - dynamodb:UpdateItem
 * - ssm:GetParameter
 * - kms:Decrypt
 */

import jwt from 'jsonwebtoken';
import { DynamoDBClient, UpdateItemCommand } from '@aws-sdk/client-dynamodb';
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';

const dynamodb = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const ssm = new SSMClient({ region: process.env.AWS_REGION || 'us-east-1' });

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
};

/**
 * Extract JWT from Authorization header
 */
function extractToken(authHeader) {
  if (!authHeader) {
    console.warn('No Authorization header provided');
    return null;
  }

  const parts = authHeader.split(' ');
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
 * Verify JWT token
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
 * Soft deletes a customer by setting isDeleted flag
 */
export const handler = async (event) => {
  try {
    // Extract JWT token
    const token = extractToken(event.headers?.Authorization);

    // Authorization check
    if (!token) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ 
          error: 'Missing authorization token' 
        }),
      };
    }

    // Verify token
    const jwtSecret = await getJWTSecret();
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

    // Extract customer ID from URL path
    const { id } = event.pathParameters;

    if (!id) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ 
          error: 'Customer ID is required' 
        }),
      };
    }

    // Log deletion attempt for audit trail
    console.log(`Soft delete requested for customer ${id} by ${decoded.email}`);

    // Update customer record: set isDeleted = true and add deletedAt timestamp
    // This is a SOFT DELETE - data is preserved for recovery/auditing
    const command = new UpdateItemCommand({
      TableName: 'singha-customers',
      Key: {
        id: { S: id }
      },
      UpdateExpression: 'SET isDeleted = :true, deletedAt = :now, deletedBy = :admin',
      ExpressionAttributeValues: {
        ':true': { BOOL: true },
        ':now': { S: new Date().toISOString() },
        ':admin': { S: decoded.email }
      },
      // Return the updated item (optional)
      ReturnValues: 'ALL_NEW'
    });

    const result = await dynamodb.send(command);

    // Success response
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        message: `Customer ${id} has been soft deleted`,
        // Optional: return the updated item
        // item: unmarshall(result.Attributes)
      }),
    };
  } catch (error) {
    console.error('Error deleting customer:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ 
        error: 'Internal server error' 
      }),
    };
  }
};