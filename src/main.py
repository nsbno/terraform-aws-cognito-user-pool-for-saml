import json
import boto3


def lambda_handler(event, context):
    print(f'incoming event: {json.dumps(event)}')

    if (event['triggerSource'] != "TokenGeneration_HostedAuth"):
        return event

    if 'custom:groups' not in event['request']['userAttributes']:
        return event

    group = event['request']['userAttributes']['custom:groups']
    client = boto3.client('cognito-idp')
    groupinfo = client.get_group(
        UserPoolId=event['userPoolId'],
        GroupName=group
    )
    groupinfo = groupinfo.get("Group")
    grouprole = groupinfo.get("RoleArn")

    event["response"]["claimsOverrideDetails"] = {
        "groupOverrideDetails": {"groupsToOverride": [group], "iamRolesToOverride": [grouprole],
                                 "preferredRole": grouprole}
    }

    print(f'outgoing event: {json.dumps(event)}')

    return event
