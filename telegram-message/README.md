## Requirements

* AWS CLI already configured with at least PowerUser permission
* [Python 3 installed](https://www.python.org/downloads/)

## Setup for local development

```bash
pip3 install virtualenv

virtualenv --system-site-packages venv

source venv/bin/activate

 pip install -r requirements.txt -t src/vendored
```

## Packaging and deployment into AWS Lambda

[AWS Serverless Application Model (SAM)](https://github.com/awslabs/serverless-application-model/blob/master/versions/2016-10-31.md)
 
[AWS Serverless Application Model (SAM) HOWTO Guide](https://github.com/awslabs/serverless-application-model/blob/master/HOWTO.md)
 
```bash
aws s3 mb s3://$CODEBUCKET
```
Upload Lambda function code to S3:

```bash
cd src && zip -r telegram-message.zip . && aws s3 cp telegram-message.zip s3://$CODEBUCKET/src/telegram-message.zip
```
Create a Cloudformation Stack and deploy SAM resources.

```bash
aws cloudformation deploy --template-file telegram-message.yaml --stack-name telegram-message --capabilities CAPABILITY_IAM
```
