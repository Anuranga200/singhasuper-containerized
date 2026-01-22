import { DynamoDB } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocument } from '@aws-sdk/lib-dynamodb';

const dynamodb = DynamoDBDocument.from(new DynamoDB({}));

// Helper function to validate NIC format (Sri Lankan NIC)
function validateNIC(nic) {
  // Old format: 9 digits + V (e.g., 123456789V)
  // New format: 12 digits (e.g., 200012345678)
  const oldFormat = /^[0-9]{9}[vVxX]$/;
  const newFormat = /^[0-9]{12}$/;
  return oldFormat.test(nic) || newFormat.test(nic);
}

// Helper function to validate phone number (Sri Lankan format)
function validatePhone(phone) {
  // Formats: 0771234567, +94771234567, 94771234567
  const phoneRegex = /^(?:\+94|94|0)?[1-9][0-9]{8}$/;
  return phoneRegex.test(phone);
}

// Helper function to validate name
function validateName(name) {
  // Only letters, spaces, minimum 2 characters
  const nameRegex = /^[a-zA-Z\s]{2,50}$/;
  return nameRegex.test(name);
}

// ✅ CHANGE 1: Added CORS headers constant
const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'OPTIONS,POST'
};

export const handler = async (event) => {
  try {
    const { nicNumber, fullName, phoneNumber } = JSON.parse(event.body);

    // Validate inputs
    if (!nicNumber || !fullName || !phoneNumber) {
      return {
        statusCode: 400,
        headers: corsHeaders, // ✅ CHANGE 2: Replaced inline headers
        body: JSON.stringify({ error: 'Missing required fields' }),
      };
    }

    // Validate NIC format
    if (!validateNIC(nicNumber)) {
      return {
        statusCode: 400,
        headers: corsHeaders, // ✅ CHANGE 3: Replaced inline headers
        body: JSON.stringify({ error: 'Invalid NIC format' }),
      };
    }

    // Validate phone number
    if (!validatePhone(phoneNumber)) {
      return {
        statusCode: 400,
        headers: corsHeaders, // ✅ CHANGE 4: Replaced inline headers
        body: JSON.stringify({ error: 'Invalid phone number format' }),
      };
    }

    // Validate name
    if (!validateName(fullName)) {
      return {
        statusCode: 400,
        headers: corsHeaders, // ✅ CHANGE 5: Replaced inline headers
        body: JSON.stringify({ error: 'Invalid name format' }),
      };
    }

    // Sanitize inputs (prevent injection)
    const sanitizedNIC = nicNumber.trim().toUpperCase();
    const sanitizedName = fullName.trim();
    const sanitizedPhone = phoneNumber.trim();

    // Check for duplicate NIC
    const nicQuery = await dynamodb.query({
      TableName: 'singha-customers',
      IndexName: 'nicNumber-index',
      KeyConditionExpression: 'nicNumber = :nic',
      ExpressionAttributeValues: { ':nic': sanitizedNIC },
    });

    if (nicQuery.Items.length > 0) {
      return {
        statusCode: 400,
        headers: corsHeaders, // ✅ CHANGE 6: Replaced inline headers
        body: JSON.stringify({ error: 'This NIC number is already registered.' }),
      };
    }

    // Check for duplicate phone number (optional)
    const phoneQuery = await dynamodb.scan({
      TableName: 'singha-customers',
      FilterExpression: 'phoneNumber = :phone',
      ExpressionAttributeValues: { ':phone': sanitizedPhone },
    });

    if (phoneQuery.Items.length > 0) {
      return {
        statusCode: 400,
        headers: corsHeaders, // ✅ CHANGE 7: Replaced inline headers
        body: JSON.stringify({ error: 'This phone number is already registered.' }),
      };
    }

    // Generate loyalty number (ensure uniqueness)
    let loyaltyNumber;
    let isUnique = false;
    
    while (!isUnique) {
      loyaltyNumber = Math.floor(1000 + Math.random() * 9000).toString();
      
      // Check if loyalty number already exists
      const loyaltyCheck = await dynamodb.scan({
        TableName: 'singha-customers',
        FilterExpression: 'loyaltyNumber = :loyalty',
        ExpressionAttributeValues: { ':loyalty': loyaltyNumber },
      });
      
      if (loyaltyCheck.Items.length === 0) {
        isUnique = true;
      }
    }

    // Create customer
    const customer = {
      id: Date.now().toString(),
      nicNumber: sanitizedNIC,
      fullName: sanitizedName,
      phoneNumber: sanitizedPhone,
      loyaltyNumber,
      registeredAt: new Date().toISOString(),
    };

    await dynamodb.put({
      TableName: 'singha-customers',
      Item: customer,
    });

    return {
      statusCode: 200,
      headers: corsHeaders, // ✅ CHANGE 8: Replaced inline headers
      body: JSON.stringify({ success: true, loyaltyNumber }),
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders, // ✅ CHANGE 9: Replaced inline headers
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};