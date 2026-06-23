import json
import boto3
import hashlib
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    try:
        method = event.get('httpMethod', 'GET')

        # ── GET Request ──────────────────────────────────────
        if method == 'GET':
            params = event.get('queryStringParameters') or {}
            incoming_data = params.get('data', '')

            if not incoming_data:
                # Return all stored unique records
                result = table.scan()
                items = result.get('Items', [])
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'total_unique_records': len(items),
                        'records': items
                    })
                }

            # Check if specific data exists
            data_hash = hashlib.sha256(incoming_data.encode()).hexdigest()
            response = table.get_item(Key={'data_hash': data_hash})

            if 'Item' in response:
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps('✅ Data EXISTS in the database!')
                }
            return {
                'statusCode': 404,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps('❌ Data does NOT exist.')
            }

        # ── POST Request ─────────────────────────────────────
        if method == 'POST':
            raw_body = event.get('body') or '{}'
            body = json.loads(raw_body)
            incoming_data = body.get('data', '')

            if not incoming_data:
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps('⚠️ No data provided!')
                }

            data_hash = hashlib.sha256(incoming_data.encode()).hexdigest()
            response = table.get_item(Key={'data_hash': data_hash})

            if 'Item' in response:
                return {
                    'statusCode': 409,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps('❌ Duplicate data detected! Not stored.')
                }

            table.put_item(Item={
                'data_hash': data_hash,
                'original_data': incoming_data
            })
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps('✅ Unique data stored successfully!')
            }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(f'Server Error: {str(e)}')
        }
