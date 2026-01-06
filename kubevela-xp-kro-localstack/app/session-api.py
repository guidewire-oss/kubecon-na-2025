"""
Session Management API using AWS DynamoDB
A simple REST API for managing user sessions with automatic TTL expiration
"""

import os
import json
import time
import logging
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration from environment variables
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'user-sessions')
AWS_REGION = os.environ.get('AWS_REGION', 'us-west-2')
SESSION_TTL_HOURS = int(os.environ.get('SESSION_TTL_HOURS', '24'))
LOCALSTACK_ENDPOINT = os.environ.get('LOCALSTACK_ENDPOINT')

# Initialize DynamoDB client
# For LocalStack, use endpoint_url; for real AWS, it will be None
dynamodb_kwargs = {
    'region_name': AWS_REGION,
}

if LOCALSTACK_ENDPOINT:
    dynamodb_kwargs['endpoint_url'] = LOCALSTACK_ENDPOINT
    # LocalStack uses dummy credentials
    dynamodb_kwargs['aws_access_key_id'] = os.environ.get('AWS_ACCESS_KEY_ID', 'test')
    dynamodb_kwargs['aws_secret_access_key'] = os.environ.get('AWS_SECRET_ACCESS_KEY', 'test')

dynamodb = boto3.resource('dynamodb', **dynamodb_kwargs)
table = dynamodb.Table(TABLE_NAME)

logger.info(f"Initialized Session API with table: {TABLE_NAME}, region: {AWS_REGION}")


def get_ttl_timestamp(hours_from_now):
    """Calculate Unix timestamp for TTL expiration"""
    expiration_time = datetime.utcnow() + timedelta(hours=hours_from_now)
    return int(expiration_time.timestamp())


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'session-api',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/ready', methods=['GET'])
def ready():
    """Readiness check - service is ready once Flask is running"""
    # In LocalStack demo, just check that the service is up
    # Table availability is eventually consistent
    return jsonify({
        'status': 'ready',
        'service': 'session-api',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/sessions', methods=['POST'])
def create_session():
    """Create a new user session"""
    try:
        data = request.get_json()

        if not data or 'userId' not in data:
            return jsonify({'error': 'userId is required'}), 400

        user_id = data['userId']
        session_data = data.get('data', {})

        # Generate session ID
        session_id = f"session-{user_id}-{int(time.time())}"

        # Calculate TTL
        ttl = get_ttl_timestamp(SESSION_TTL_HOURS)

        # Create session item
        item = {
            'id': session_id,
            'userId': user_id,
            'data': json.dumps(session_data),
            'createdAt': datetime.utcnow().isoformat(),
            'ttl': ttl
        }

        # Put item in DynamoDB
        table.put_item(Item=item)

        logger.info(f"Created session {session_id} for user {user_id}")

        return jsonify({
            'sessionId': session_id,
            'userId': user_id,
            'expiresAt': datetime.fromtimestamp(ttl).isoformat(),
            'data': session_data
        }), 201

    except Exception as e:
        logger.error(f"Error creating session: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/sessions/<session_id>', methods=['GET'])
def get_session(session_id):
    """Retrieve a session by ID"""
    try:
        response = table.get_item(Key={'id': session_id})

        if 'Item' not in response:
            return jsonify({'error': 'Session not found'}), 404

        item = response['Item']

        # Check if session has expired
        if int(item['ttl']) < int(time.time()):
            return jsonify({'error': 'Session has expired'}), 410

        return jsonify({
            'sessionId': item['id'],
            'userId': item['userId'],
            'data': json.loads(item['data']),
            'createdAt': item['createdAt'],
            'expiresAt': datetime.fromtimestamp(int(item['ttl'])).isoformat()
        }), 200

    except Exception as e:
        logger.error(f"Error retrieving session {session_id}: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/sessions/<session_id>', methods=['PUT'])
def update_session(session_id):
    """Update a session's data"""
    try:
        data = request.get_json()

        if not data:
            return jsonify({'error': 'Request body is required'}), 400

        session_data = data.get('data', {})

        # Update the session data
        response = table.update_item(
            Key={'id': session_id},
            UpdateExpression='SET #data = :data, updatedAt = :updated',
            ConditionExpression='attribute_exists(id)',
            ExpressionAttributeNames={'#data': 'data'},
            ExpressionAttributeValues={
                ':data': json.dumps(session_data),
                ':updated': datetime.utcnow().isoformat()
            },
            ReturnValues='ALL_NEW'
        )

        item = response['Attributes']

        logger.info(f"Updated session {session_id}")

        return jsonify({
            'sessionId': item['id'],
            'userId': item['userId'],
            'data': json.loads(item['data']),
            'updatedAt': item.get('updatedAt', item['createdAt'])
        }), 200

    except ClientError as e:
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            return jsonify({'error': 'Session not found'}), 404
        logger.error(f"Error updating session {session_id}: {str(e)}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Error updating session {session_id}: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/sessions/<session_id>', methods=['DELETE'])
def delete_session(session_id):
    """Delete a session"""
    try:
        table.delete_item(Key={'id': session_id})

        logger.info(f"Deleted session {session_id}")

        return jsonify({'message': 'Session deleted successfully'}), 200

    except Exception as e:
        logger.error(f"Error deleting session {session_id}: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/sessions/user/<user_id>', methods=['GET'])
def get_user_sessions(user_id):
    """Get all sessions for a specific user"""
    try:
        # Query using GSI (if created) or scan with filter
        response = table.scan(
            FilterExpression='userId = :uid',
            ExpressionAttributeValues={':uid': user_id}
        )

        items = response.get('Items', [])
        current_time = int(time.time())

        # Filter out expired sessions
        active_sessions = [
            {
                'sessionId': item['id'],
                'userId': item['userId'],
                'data': json.loads(item['data']),
                'createdAt': item['createdAt'],
                'expiresAt': datetime.fromtimestamp(int(item['ttl'])).isoformat()
            }
            for item in items
            if int(item['ttl']) > current_time
        ]

        return jsonify({
            'userId': user_id,
            'sessionCount': len(active_sessions),
            'sessions': active_sessions
        }), 200

    except Exception as e:
        logger.error(f"Error retrieving sessions for user {user_id}: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/sessions', methods=['GET'])
def list_sessions():
    """List all active sessions (admin endpoint)"""
    try:
        response = table.scan()
        items = response.get('Items', [])
        current_time = int(time.time())

        # Filter out expired sessions
        active_sessions = [
            {
                'sessionId': item['id'],
                'userId': item['userId'],
                'createdAt': item['createdAt'],
                'expiresAt': datetime.fromtimestamp(int(item['ttl'])).isoformat()
            }
            for item in items
            if int(item['ttl']) > current_time
        ]

        return jsonify({
            'sessionCount': len(active_sessions),
            'sessions': active_sessions
        }), 200

    except Exception as e:
        logger.error(f"Error listing sessions: {str(e)}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
