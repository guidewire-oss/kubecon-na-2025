#!/usr/bin/env python3
"""
Product Catalog API - Flask application with S3 integration
Demonstrates a simple microservice that stores product images in S3
"""
import os
import json
import uuid
from datetime import datetime
from flask import Flask, request, jsonify
import boto3
from botocore.exceptions import ClientError, NoCredentialsError

app = Flask(__name__)

# Configuration
S3_BUCKET = os.environ.get('S3_BUCKET_NAME', 'tenant-atlantis-product-images')
AWS_REGION = os.environ.get('AWS_REGION', 'us-west-2')

# Initialize S3 client
s3_client = boto3.client('s3', region_name=AWS_REGION)

PRODUCTS_PREFIX = 'products'
METADATA_FILENAME = 'product.json'
IMAGE_FILENAME = 'image.jpg'


def build_image_key(product_id: str) -> str:
    return f"{PRODUCTS_PREFIX}/{product_id}/{IMAGE_FILENAME}"


def build_metadata_key(product_id: str) -> str:
    return f"{PRODUCTS_PREFIX}/{product_id}/{METADATA_FILENAME}"


def fetch_product(product_id: str):
    metadata_key = build_metadata_key(product_id)
    try:
        response = s3_client.get_object(Bucket=S3_BUCKET, Key=metadata_key)
        product_data = response['Body'].read().decode('utf-8')
        product = json.loads(product_data)
        product['metadata_s3_key'] = metadata_key
        return product
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', '')
        if error_code in ['NoSuchKey', '404']:
            return None
        raise


def list_product_metadata_keys():
    keys = []
    continuation_token = None
    while True:
        kwargs = {
            'Bucket': S3_BUCKET,
            'Prefix': f"{PRODUCTS_PREFIX}/"
        }
        if continuation_token:
            kwargs['ContinuationToken'] = continuation_token

        response = s3_client.list_objects_v2(**kwargs)

        for obj in response.get('Contents', []):
            key = obj['Key']
            if key.endswith(f"/{METADATA_FILENAME}"):
                keys.append(key)

        continuation_token = response.get('NextContinuationToken')
        if not continuation_token:
            break

    return keys


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'product-catalog-api'
    }), 200


@app.route('/ready', methods=['GET'])
def readiness_check():
    """Readiness check - verifies S3 bucket is accessible"""
    try:
        s3_client.head_bucket(Bucket=S3_BUCKET)
        return jsonify({
            'status': 'ready',
            'timestamp': datetime.utcnow().isoformat(),
            's3_bucket': S3_BUCKET
        }), 200
    except NoCredentialsError:
        return jsonify({
            'status': 'not ready',
            'error': 'AWS credentials not configured'
        }), 503
    except ClientError:
        return jsonify({
            'status': 'not ready',
            'error': 'S3 bucket not accessible'
        }), 503


@app.route('/products', methods=['GET'])
def list_products():
    """List all products"""
    try:
        product_keys = list_product_metadata_keys()
        product_list = []
        for key in product_keys:
            try:
                response = s3_client.get_object(Bucket=S3_BUCKET, Key=key)
                product_data = response['Body'].read().decode('utf-8')
                product = json.loads(product_data)
                product['metadata_s3_key'] = key
                product_list.append(product)
            except ClientError as e:
                # Skip products that cannot be read
                continue

        return jsonify({
            'products': product_list,
            'count': len(product_list)
        }), 200
    except ClientError as e:
        return jsonify({'error': f'Failed to list products: {str(e)}'}), 500


@app.route('/products', methods=['POST'])
def create_product():
    """Create a new product with optional image upload to S3"""
    try:
        data = request.get_json()

        if not data or 'name' not in data:
            return jsonify({'error': 'Product name is required'}), 400

        product_id = str(uuid.uuid4())

        product = {
            'id': product_id,
            'name': data['name'],
            'description': data.get('description', ''),
            'price': data.get('price', 0.0),
            'created_at': datetime.utcnow().isoformat()
        }

        image_key = build_image_key(product_id)

        # Handle image upload - create placeholder if no image provided
        try:
            if data.get('image_data'):
                # Upload provided image data (base64 or URL in real app)
                image_body = data['image_data'].encode('utf-8')
            else:
                # Create a placeholder image object to demonstrate S3 integration
                placeholder_data = {
                    'product_id': product_id,
                    'product_name': data['name'],
                    'note': 'Placeholder - no image uploaded',
                    'created_at': datetime.utcnow().isoformat()
                }
                image_body = json.dumps(placeholder_data).encode('utf-8')

            s3_client.put_object(
                Bucket=S3_BUCKET,
                Key=image_key,
                Body=image_body,
                ContentType='image/jpeg' if data.get('image_data') else 'application/json'
            )
            product['image_s3_key'] = image_key
        except ClientError as e:
            return jsonify({'error': f'Failed to upload image: {str(e)}'}), 500

        metadata_key = build_metadata_key(product_id)

        try:
            s3_client.put_object(
                Bucket=S3_BUCKET,
                Key=metadata_key,
                Body=json.dumps(product).encode('utf-8'),
                ContentType='application/json'
            )
            product['metadata_s3_key'] = metadata_key
        except ClientError as e:
            return jsonify({'error': f'Failed to store product metadata: {str(e)}'}), 500

        stored_product = fetch_product(product_id)

        return jsonify(stored_product or product), 201

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/products/<product_id>', methods=['GET'])
def get_product(product_id):
    """Get a specific product with S3 signed URL for image"""
    product = fetch_product(product_id)

    if not product:
        return jsonify({'error': 'Product not found'}), 404

    # Generate presigned URL for image if it exists
    if 'image_s3_key' in product:
        try:
            url = s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': S3_BUCKET, 'Key': product['image_s3_key']},
                ExpiresIn=3600  # 1 hour
            )
            product['image_url'] = url
        except ClientError as e:
            product['image_url_error'] = str(e)

    return jsonify(product), 200


@app.route('/products/<product_id>', methods=['DELETE'])
def delete_product(product_id):
    """Delete a product and its S3 image"""
    product = fetch_product(product_id)

    if not product:
        return jsonify({'error': 'Product not found'}), 404

    # Delete image from S3 if exists
    if 'image_s3_key' in product:
        try:
            s3_client.delete_object(Bucket=S3_BUCKET, Key=product['image_s3_key'])
        except ClientError:
            pass  # Continue even if S3 delete fails
    metadata_key = build_metadata_key(product_id)
    try:
        s3_client.delete_object(Bucket=S3_BUCKET, Key=metadata_key)
    except ClientError:
        pass

    return jsonify({'message': 'Product deleted'}), 200


@app.route('/', methods=['GET'])
def index():
    """Root endpoint with API information"""
    return jsonify({
        'service': 'Product Catalog API',
        'version': '1.0.0',
        'endpoints': {
            'GET /health': 'Health check',
            'GET /ready': 'Readiness check',
            'GET /products': 'List all products',
            'POST /products': 'Create a product',
            'GET /products/<id>': 'Get a specific product',
            'DELETE /products/<id>': 'Delete a product'
        },
        's3_bucket': S3_BUCKET,
        'region': AWS_REGION
    }), 200


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
