AWS.config.update({
    accessKeyId: config.AWS_ACCESS_KEY_ID,
    secretAccessKey: config.AWS_SECRET_ACCESS_KEY,
    region: config.AWS_REGION
});

const s3 = new AWS.S3();
const requestBucket = 'request-bucket-7qkitsou';  // From Terraform output
const responseBucket = 'response-bucket-7qkitsou';  // From Terraform output

function uploadFile() {
    const fileInput = document.getElementById('fileInput');
    const file = fileInput.files[0];
    if (!file) return alert('Select a JSON file');

    const key = file.name;
    s3.upload({
        Bucket: requestBucket,
        Key: key,
        Body: file,
        ContentType: 'application/json'
    }, (err, data) => {
        if (err) return alert('Upload error: ' + err.message);
        alert('File uploaded. Processing...');
        pollForResult(key);
    });
}

function pollForResult(inputKey) {
    const outputKey = `translated_${inputKey}`;
    const resultDiv = document.getElementById('result');
    resultDiv.innerHTML = 'Waiting for translation...';

    const interval = setInterval(() => {
        s3.getObject({
            Bucket: responseBucket,
            Key: outputKey
        }, (err, data) => {
            if (err) {
                if (err.code === 'NoSuchKey') return;  // Still processing
                clearInterval(interval);
                return resultDiv.innerHTML = 'Error: ' + err.message;
            }
            clearInterval(interval);
            const translated = JSON.parse(data.Body.toString('utf-8'));
            resultDiv.innerHTML = `<strong>Original:</strong> ${translated.original_text}<br>
                                   <strong>Translated:</strong> ${translated.translated_text}`;
        });
    }, 5000);  // Poll every 2 seconds
}