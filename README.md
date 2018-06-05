## Requirements

* AWS CLI already configured with at least PowerUser permission
* [Python 3 installed](https://www.python.org/downloads/)

## Setup process

### Installing dependencies

```bash
pip install -r requirements.txt
```

## Packaging and deployment

```bash
aws s3 mb s3://aws-tag-verifier
```

The following command to package Lambda function to S3:

```bash
cd src && zip aws-tag-verifier.zip  * && aws s3 cp aws-tag-verifier.zip s3://aws-tag-verifier/src/tagreporter.zip
```

The following command will create a Cloudformation Stack and deploy your SAM resources.

```bash
sam deploy --template-file template.yaml --stack-name aws-tag-verifier
```

> **See [Serverless Application Model (SAM) HOWTO Guide](https://github.com/awslabs/serverless-application-model/blob/master/HOWTO.md) for more details in how to get started.**
