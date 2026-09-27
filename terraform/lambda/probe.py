import time
import urllib.request
import os
import boto3
from decimal import Decimal
# Hedef adres ve merkezi DynamoDB bölgesi
TARGET_URL = "https://www.google.com"
DYNAMODB_REGION = "eu-north-1"  # Tabloyu Stockholm'de açtığımız için
TABLE_NAME = "InternetLatencyMetrics"
# Farklı bir bölgeden çalışsa bile merkezi Stockholm tablosuna yazacak client
dynamodb = boto3.resource('dynamodb', region_name=DYNAMODB_REGION)
table = dynamodb.Table(TABLE_NAME)
def lambda_handler(event, context):
    current_region = os.environ.get('AWS_REGION', 'unknown-region')
    start_time = time.time()
    status_code = 0


    try:
        req = urllib.request.Request(
            TARGET_URL, 
            headers={'User-Agent': 'AWS-Latency-Probe'}
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            status_code = response.getcode()
            latency_ms = (time.time() - start_time) * 1000
    except Exception as e:
        latency_ms = (time.time() - start_time) * 1000
        print(f"Hata oluştu: {str(e)}")
        status_code = 500
    timestamp = int(time.time() * 1000)
    # DynamoDB'ye kaydet
    item = {
        'Region': current_region,
        'Timestamp': timestamp,
        'LatencyMs': Decimal(str(round(latency_ms, 2))),
        'StatusCode': status_code,
        'TargetUrl': TARGET_URL
    }


    table.put_item(Item=item)


    return {
        'statusCode': 200,
        'body': f"Kaydedildi -> Bölge: {current_region}, Gecikme: {latency_ms:.2f} ms, Durum: {status_code}"
    }