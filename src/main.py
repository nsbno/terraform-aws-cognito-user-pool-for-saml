import json
import boto3


def lambda_handler(event, context):
    print(f'incoming event: {json.dumps(event)}')

    if (event['triggerSource'] != "TokenGeneration_HostedAuth") and (event['triggerSource'] != "TokenGeneration_RefreshTokens"):
        print('Not an access token')
        return event

    if 'custom:groups' not in event['request']['userAttributes']:
        print('custom:groups')
        return event

    group = []
    group = event['request']['userAttributes']['custom:groups']
    group=group.replace(" ", "")
    group=group[1:]
    group=group[:-1]
    group = group.split(",")

    event["response"]["claimsOverrideDetails"] = {
        "groupOverrideDetails": {"groupsToOverride": group}
    }

    print(f'outgoing event: {json.dumps(event)}')

    return event
