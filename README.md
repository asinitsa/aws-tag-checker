## Requirements

* AWS CLI already configured with at least PowerUser permission
* [Python 3 installed](https://www.python.org/downloads/)
* [Docker installed](https://www.docker.com/community-edition)
* [Python Virtual Environment](http://docs.python-guide.org/en/latest/dev/virtualenvs/)

## Setup process

### Installing dependencies

```bash
pip install -r requirements.txt
```

## Packaging and deployment

Firstly, we need a `S3 bucket` where we can upload our Lambda functions packaged as ZIP before we deploy anything - If you don't have a S3 bucket to store code artifacts then this is a good time to create one:

```bash
aws s3 mb s3://aws-tag-verifier
```

Next, run the following command to package our Lambda function to S3:

```bash
cd src && zip aws-tag-verifier.zip  * && aws s3 cp aws-tag-verifier.zip s3://aws-tag-verifier/src/tagreporter.zip
```

Next, the following command will create a Cloudformation Stack and deploy your SAM resources.

```bash
sam deploy --template-file template.yaml --stack-name aws-tag-verifier
```

> **See [Serverless Application Model (SAM) HOWTO Guide](https://github.com/awslabs/serverless-application-model/blob/master/HOWTO.md) for more details in how to get started.**
