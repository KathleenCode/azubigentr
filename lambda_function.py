import json
import boto3
import os

s3 = boto3.client('s3')
translate = boto3.client('translate')

def lambda_handler(event, context):
    try:
        input_bucket = event['Records'][0]['s3']['bucket']['name']
        input_key = event['Records'][0]['s3']['object']['key']
        response = s3.get_object(Bucket=input_bucket, Key=input_key)
        content = response['Body'].read().decode('utf-8')
        data = json.loads(content)
        
        text = data.get('text')
        source_lang = data.get('source_language', 'auto')
        target_lang = data.get('target_language')
        
        if not text or not target_lang:
            raise ValueError("Missing 'text' or 'target_language'")
        
        translation = translate.translate_text(
            Text=text,
            SourceLanguageCode=source_lang,
            TargetLanguageCode=target_lang
        )
        
        output_data = {
            'original_text': text,
            'translated_text': translation['TranslatedText'],
            'source_language': translation['SourceLanguageCode'],
            'target_language': target_lang
        }
        
        output_bucket = os.environ['OUTPUT_BUCKET']
        output_key = f"translated_{input_key}"
        s3.put_object(
            Bucket=output_bucket,
            Key=output_key,
            Body=json.dumps(output_data, ensure_ascii=False).encode('utf-8'),
            ContentType='application/json'
        )
        
        return {'statusCode': 200, 'body': json.dumps({'output_key': output_key})}
    except Exception as e:
        print(f"Error: {str(e)}")
        return {'statusCode': 500, 'body': str(e)}