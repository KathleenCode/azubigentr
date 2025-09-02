This documentation covers infrastructure setup, IAM roles, script usage, and troubleshooting.

---

# AWS Translation Project Documentation

## Overview
This project implements a real-time document translation system using AWS services, including Amazon S3, AWS Lambda, and Amazon Translate. The solution allows users to upload JSON files containing text to translate, processes them asynchronously via Lambda, and stores the translated output in an S3 bucket. The frontend, hosted locally, polls for results. The infrastructure is managed with Terraform, deployed in the `eu-north-1` region, and recently enhanced with a VPC for security.

## Infrastructure Setup

### Architecture
- **Components**:
  - **Frontend**: Local web app (`http://localhost:8080`) with HTML, CSS, and JavaScript (AWS SDK).
  - **AWS VPC**: `10.0.0.0/16` with subnets in `eu-north-1a` (10.0.1.0/24) and `eu-north-1b` (10.0.2.0/24), Internet Gateway, and Route Table.
  - **AWS S3**:
    - Input Bucket: `request-bucket-7qkitsou` (stores uploaded JSON).
    - Output Bucket: `response-bucket-<suffix>` (stores translated JSON).
  - **AWS Lambda**: `translation-function` (Python 3.12) processes translations.
  - **Amazon Translate**: Performs real-time text translation.
  - **IAM Role**: `translation-role` for Lambda permissions.
  - **CloudWatch Logs**: Logs Lambda execution.
- **Flow**: User uploads JSON → S3 triggers Lambda → Lambda calls Translate → Output to S3 → Frontend polls result.
- **Region**: `eu-north-1`.

### Terraform Configuration
- **File**: `main.tf`
- **Setup Steps**:
  1. Install Terraform on Windows (download from terraform.io, add to PATH).
  2. Initialize project:
     ```
     cd C:\Projects\apppp
     terraform init
     ```
  3. Apply configuration:
     ```
     terraform apply
     ```
     - Confirms bucket creation, Lambda deployment, and VPC setup.
  4. Verify output:
     ```
     terraform output
     ```
     - Provides bucket names (e.g., `response_bucket_name`).
- **Key Resources**:
  - S3 Buckets with CORS (`allowed_origins = ["http://localhost:8080"]`).
  - Lambda with VPC config (subnets and security group).
  - IAM role with S3 and Translate permissions.

### VPC Integration
- **Purpose**: Isolates resources, enhances security.
- **Configuration**: VPC with two subnets across `eu-north-1a` and `eu-north-1b`, Internet Gateway for external access, and S3 VPC endpoint for private connectivity.
- **Update**: Add VPC resources to `main.tf` and re-apply.

## IAM Roles

### Role: `translation-role`
- **Purpose**: Grants Lambda permissions to interact with S3 and Translate.
- **Policy**:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      { "Effect": "Allow", "Action": ["s3:GetObject"], "Resource": "arn:aws:s3:::request-bucket-7qkitsou/*" },
      { "Effect": "Allow", "Action": ["s3:PutObject"], "Resource": "arn:aws:s3:::response-bucket-<suffix>/*" },
      { "Effect": "Allow", "Action": "translate:TranslateText", "Resource": "*" },
      { "Effect": "Allow", "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], "Resource": "arn:aws:logs:*:*:*" }
    ]
  }
  ```
- **Setup**: Defined in `main.tf`, attached via `aws_iam_role_policy_attachment`.
- **User**: IAM user (`translation-frontend-user`) with similar S3 permissions for frontend SDK.

### Security Considerations
- Block Public Access enabled on S3 buckets.
- VPC restricts access; adjust security groups as needed.

## Script Usage

### Frontend Scripts
- **File**: `frontend/index.html`
  - **Usage**: Open in browser after running `npx http-server -p 8080` in `frontend` directory.
  - **Function**: Displays upload form and result div.
- **File**: `frontend/script.js`
  - **Usage**: Configures AWS SDK, handles upload to `request-bucket-7qkitsou`, and polls `response-bucket-<suffix>`.
  - **Key Function**: `pollForResult(inputKey)` (polls every 5 seconds).
  - **Setup**: Requires `config.js` with credentials.
- **File**: `frontend/config.js`
  - **Usage**: Defines `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `REQUEST_BUCKET`, `RESPONSE_BUCKET`.
  - **Setup**: Generate from `.env` using `generate_config.py`.
- **File**: `frontend/style.css`
  - **Usage**: Styles UI with violet gradient background, dashed border, smaller button, and colored file input.
  - **Setup**: Linked in `index.html`.

### Backend Script
- **File**: `lambda_function.py`
  - **Usage**: Processes S3 event, extracts JSON, translates via Amazon Translate, and saves output.
  - **Key Function**: `lambda_handler(event, context)`.
  - **Setup**: Zip into `lambda_function.zip` and deploy via Terraform.
- **File**: `test_s3.py`
  - **Usage**: Tests Boto3 S3 access locally with `.env` credentials.
  - **Run**: `python test_s3.py`.
- **File**: `generate_config.py`
  - **Usage**: Generates `config.js` from `.env`.
  - **Run**: `python generate_config.py`.

### Sample JSON Files
- **File**: `test.json`
  - **Content**:
    ```json
    {
      "text": "Hello, world!",
      "source_language": "en",
      "target_language": "fr"
    }
    ```
  - **Usage**: Upload via frontend or CLI (`aws s3 cp test.json s3://request-bucket-7qkitsou/`).

## Troubleshooting

### Common Issues
- **"Upload error: Network Failure"**
  - **Cause**: Incorrect credentials, region mismatch, or CORS issue.
  - **Fix**: Verify `config.js` matches `.env` and `main.tf` (all `eu-north-1`). Ensure `allowed_origins = ["http://localhost:8080"]` in `main.tf`, re-apply Terraform.
- **"Waiting to translate" (No Output)**
  - **Cause**: Lambda failure (e.g., `Runtime.ImportModuleError`).
  - **Fix**: Recreate `lambda_function.zip` with `lambda_function.py` at root, re-run `terraform apply`. Check CloudWatch Logs.
- **Lambda Import Error**
  - **Cause**: Incorrect ZIP structure.
  - **Fix**: Extract ZIP, ensure only `lambda_function.py` is present, re-zip, and deploy.
- **Access Denied**
  - **Cause**: Missing IAM permissions.
  - **Fix**: Update `translation-role` policy or IAM user policy with required S3 and Translate actions.

### Debugging Steps
1. **Check Browser Console**:
   - Open F12 > Console, look for `AccessDenied`, `NoSuchKey`, or CORS errors.
2. **Review CloudWatch Logs**:
   - AWS Console > Lambda > `translation-function` > Monitor > View logs.
   - Filter by timestamp (e.g., upload time).
3. **Test Manually**:
   - Upload via CLI: `aws s3 cp test.json s3://request-bucket-name/`.
   - Check output: `aws s3 ls s3://response-bucket-<suffix>/`.
4. **Validate JSON**:
   - Ensure `test.json` has valid `text`, `source_language`, and `target_language` fields.

## Activities and Deliverables

### Phase 5: Testing, Debugging & Documentation
- **Activities**:
  - Tested upload and polling with `testfiles`.
  - Debugged `Runtime.ImportModuleError`, fixed via ZIP structure.
  - Documented setup, roles, usage, and troubleshooting.


### Deployment Instructions
1. Clone repo: `git clone https://github.com/KathleenCode/azubigentr`.
2. Install dependencies: `npm install` in `frontend`, `pip install python-dotenv` in root.
3. Configure `.env` with AWS credentials.
4. Run `terraform apply` in root directory.
5. Start frontend: `npx http-server -p 8080` in `frontend`.

### Testing
- Upload `test.json`, verify translated output in `response-bucket-<suffix>`.
- Check CloudWatch Logs for success.

---

### Notes
- **Security**: Use AWS Cognito for production credentials instead of `.env`.
- **Scaling**: Adjust Lambda memory or timeout if processing large files.
- **Updates**: Reflect changes (e.g., VPC) in `main.tf` and re-apply.


This documentation provides a complete guide for your project.
