import os
import sys
import boto3

token = os.environ['TELEGRAM_TOKEN']
ch_id = os.environ['CHAT_ID']

sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), "./vendored"))

import requests


def put_job_success(job):

    code_pipeline = boto3.client('codepipeline')

    print('Putting job success')
    code_pipeline.put_job_success_result(jobId=job)

def lambda_handler(event, context):


    user_parameters = "Test run"
    if 'CodePipeline.job' in event:
        job_id = event['CodePipeline.job']['id']
        job_data = event['CodePipeline.job']['data']
        user_parameters = job_data['actionConfiguration']['configuration']['UserParameters']

    base_url = "https://api.telegram.org/bot{}".format(token)
    url = base_url + "/sendMessage"

    try:
        requests.post(url, data={'text': user_parameters, 'chat_id': ch_id})
    except Exception as e:
        print(e)

    put_job_success(job_id)

    return {"statusCode": 200}
