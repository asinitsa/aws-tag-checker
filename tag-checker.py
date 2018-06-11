import os
import boto3
import json
import botocore


def tag_collector_lambda():
    func_tags = [{'ExtractedARN': 'arn:blah-blah', 'Key1': 'Value1', 'Key2': 'Value2'}]

    client = boto3.client('lambda')
    paginator = client.get_paginator('list_functions')
    response_iterator = paginator.paginate(
        PaginationConfig={
            'MaxItems': 10000,
            'PageSize': 50
        })

    for response in response_iterator:
        functions = response['Functions']
        for f in functions:
            f_arn = str(f['FunctionArn'])
            tags_response = client.list_tags(Resource=f_arn)
            f_tags = tags_response['Tags']
            f_tags['ExtractedARN'] = f_arn
            func_tags.append(f_tags)

    return func_tags


def tag_collector_resourcegroupstaggingapi():
    res_tags = [{'ExtractedARN': 'fake:arn:blah-blah', 'Key1': 'Value1', 'Key2': 'Value2'}]

    client = boto3.client('resourcegroupstaggingapi')
    paginator = client.get_paginator('get_resources')
    response_iterator = paginator.paginate(
        PaginationConfig={
            'MaxItems': 10000,
            'PageSize': 50
        })

    # print(json.dumps(resource, indent=4, sort_keys=True))
    for response in response_iterator:
        resources = response['ResourceTagMappingList']
        for resource in resources:
            tags = resource['Tags']

            r_tags = {'ExtractedARN': resource['ResourceARN']}

            for tag in tags:
                key = tag['Key']
                r_tags[key] = tag['Value']

            res_tags.append(r_tags)

    return res_tags


def tag_setter_resourcegroupstaggingapi(required_tags, csv_width):
    s3 = boto3.resource('s3')
    client = boto3.client('resourcegroupstaggingapi')

    report_bucket_name = 'tagreporterbucket'
    csv_file_key_in = 'in/tag-report.csv'
    csv_file_key_out = 'out/tag-report.csv'
    csv_str_in = ''
    csv_str_out = ''
    counters = {'arn': 0, 'tag': 0}

    try:
        csv_str_in = s3.Object(report_bucket_name, csv_file_key_in).get()['Body'].read().decode('utf-8')
    except botocore.exceptions.ClientError as e:
        if e.response['Error']['Code'] == "404":
            print("The " + csv_file_key_in + " does not exist.")
        else:
            raise

    try:
        csv_str_out = s3.Object(report_bucket_name, csv_file_key_out).get()['Body'].read().decode('utf-8')
    except botocore.exceptions.ClientError as e:
        if e.response['Error']['Code'] == "404":
            print("The " + csv_file_key_out + " does not exist.")
        else:
            raise

    csv_list_in = csv_str_in.splitlines()
    csv_list_out = csv_str_out.splitlines()

    #  iterate over both csv
    for row_in in csv_list_in:
        for row_out in csv_list_out:
            row_fields_in = row_in.split(',')
            row_fields_out = row_out.split(',')
            arn_in = row_fields_in[0]
            arn_out = row_fields_out[0]
            if (arn_in == arn_out) and arn_in.startswith('arn:aws:') and arn_out.startswith('arn:aws:'):
                counters['arn'] += 1
                for row_position in range(1, csv_width):
                    row_position_str = str(row_position)
                    if row_fields_in[row_position] != 'EMPTY_TAG_VALUE' and row_fields_in[row_position] != \
                            row_fields_out[row_position]:
                        response = client.tag_resources(
                            ResourceARNList=[arn_in],
                            Tags={
                                required_tags[row_position_str]: row_fields_in[row_position]
                            }
                        )
                        counters['tag'] += 1
                        print(response)

    return counters


def tag_validator(required_tags, csv_width, valid_values):
    s3 = boto3.resource('s3')
    sns = boto3.client('sns')

    report_bucket_name = os.environ['S3_BUCKET']
    csv_file_key_out = 'out/tag-report.csv'
    txt_file_key_out = 'out/wrong-tags.txt'
    txt_str_out = ''
    csv_str_out = ''
    txt_newline = "\r\n"
    sns_arn = os.environ['SNS_ARN']

    counters = {'arn': 0, 'tag': 0}

    try:
        csv_str_out = s3.Object(report_bucket_name, csv_file_key_out).get()['Body'].read().decode('utf-8')
    except botocore.exceptions.ClientError as e:
        if e.response['Error']['Code'] == "404":
            print("The " + csv_file_key_out + " does not exist.")
        else:
            raise

    csv_list_out = csv_str_out.splitlines()

    #  iterate over csv
    for row_out in csv_list_out:
        row_fields_out = row_out.split(',')
        arn_out = row_fields_out[0]
        if arn_out.startswith('arn:aws:'):
            counters['arn'] += 1
            for row_position in range(1, csv_width):
                c_name = required_tags[str(row_position)]
                c_value = row_fields_out[row_position]
                if c_value not in valid_values[c_name]:
                    txt_str_out = txt_str_out + 'Wrong tag: ' + c_name + ':' + c_value + ' in ' + arn_out + txt_newline
                    counters['tag'] += 1

    bucket = s3.Bucket(report_bucket_name)
    s3_resp = bucket.put_object(
        ACL='private',
        ContentType='text/plain',
        Key=txt_file_key_out,
        Body=txt_str_out
    )
    print('*** S3 response: ' + str(s3_resp))

    if len(txt_str_out) > 0:
        sns_resp = sns.publish(
            TargetArn=sns_arn,
            Message=json.dumps({'default': 'Tags are not set properly'}),
            MessageStructure='json'
        )
        print('*** SNS response: ' + str(sns_resp))

    return counters


def tag_report_generator(tags_list, required_tags, csv_width):

    print('*** Generating tag report...')

    report_bucket_name = os.environ['S3_BUCKET']
    csv_delimiter = ','
    csv_newline = "\r\n"

    csv_header_elements = ''
    for key in range(1, csv_width):
        position = str(key)
        csv_header_elements = csv_header_elements + required_tags[position] + csv_delimiter

    csv_header = 'ResourceARN' + csv_delimiter + csv_header_elements
    csv_rows = []

    # [{'ExtractedARN': 'arn:blah-blah', 'Key1': 'Value1', 'Key2': 'Value2' }]
    for resource_tag in tags_list:

        csv_row = [str(resource_tag['ExtractedARN'])]

        # fill in all cells in the row with default value 'EMPTY_TAG_VALUE', guessing, that tags are not set
        for key in range(1, csv_width):
            csv_row.append('EMPTY_TAG_VALUE')

        for row_position in range(1, csv_width):
            position = str(row_position)
            req_tag_key = required_tags[position]
            if req_tag_key in resource_tag:
                csv_row[row_position] = resource_tag[req_tag_key]

        csv_rows.append(csv_row)

    s3 = boto3.resource('s3')
    bucket = s3.Bucket(report_bucket_name)
    path = 'out/tag-report.csv'
    data = csv_header[:-1] + csv_newline

    # generating of rows
    for c_r in csv_rows:
        r = ''
        for field in c_r:
            r = r + field + csv_delimiter

        data = data + r[:-1] + csv_newline

    resp = bucket.put_object(
        ACL='private',
        ContentType='application/vnd.ms-excel',
        Key=path,
        Body=data
    )

    return resp


def lambda_handler(event, context):

    required_tags = os.environ['REQUIRED_TAGS']
    valid_values = os.environ['VALID_VALUES']
    #required_tags = {'1': 'Environment', '2': 'Application', '3': 'Product'}
    #valid_values = {'Environment': ['Production', 'Staging'], 'Application': ['Api', 'Api2'], 'Product': ['Neo']}

    csv_width = len(required_tags) + 1  # One extra field for ARN column

    try:
        print('*** Starting resource collection ...')
        tags_l = tag_collector_resourcegroupstaggingapi()
        print('*** Completed resource collection. Found: ' + str(len(tags_l) - 1))  # minus one placeholder
        # tags_l structure is:
        # [{'ExtractedARN': 'fake-arn:blah-blah', 'Key1': 'Value1', 'Key2': 'Value2' }]

        print('*** Starting report generation ...')
        r = tag_report_generator(tags_l, required_tags, csv_width)
        print('*** Completed report generation: ' + str(r))

        print('*** Starting tag assignment...')
        c = tag_setter_resourcegroupstaggingapi(required_tags, csv_width)
        print('*** Completed tag assignment: Resources checked: ' + str(c['arn']) + ' tags updated: ' + str(c['tag']))

        print('*** Starting tag validation...')
        c = tag_validator(required_tags, csv_width, valid_values)
        print('*** Completed tag validation: Resources with wrong tags: ' + str(c['tag']))
    except:
        print('*** ERROR Something went wrong!')
        raise
    else:
        print('*** Work completed!')
        return str(c)
    finally:
        print('*** Work completed!')
