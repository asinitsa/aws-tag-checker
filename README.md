## Requirements

* AWS CLI already configured with at least PowerUser permission
* [Python 3 installed](https://www.python.org/downloads/)

## Setup for local development

### Installing dependencies

```bash
pip install -r requirements.txt
```

## Packaging and deployment into AWS Lambda

```bash
aws s3 mb s3://tag-checker
```

The following command to package Lambda function to S3:

```bash
cd src && zip tag-checker.zip  * && aws s3 cp tag-checker.zip s3://tag-checker/src/tag-checker.zip
```

The following command will create a Cloudformation Stack and deploy your SAM resources.

```bash
sam deploy --template-file tag-checker.yaml --stack-name tag-checker
```

> **See [Serverless Application Model (SAM) HOWTO Guide](https://github.com/awslabs/serverless-application-model/blob/master/HOWTO.md) for more details in how to get started.**
