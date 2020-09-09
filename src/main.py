import json
import boto3
import os

def lambda_handler(event, context):
    print(f'incoming event: {json.dumps(event)}')
    grouprole='arn:aws:iam::231176028624:role/SAML-ReadOnlyRole'
    rolegroup = []
    adroles=''

    if (event['triggerSource'] != "TokenGeneration_HostedAuth"):
        return event

    if 'custom:groups' not in event['request']['userAttributes']:
        adgroups = ''
    else:
        adgroups = event['request']['userAttributes']['custom:groups']

    if 'custom:roles' not in event['request']['userAttributes']:
        adroles =''
    else:
        rolegroup = event['request']['userAttributes']['custom:roles']
        client = boto3.client('cognito-idp')
        groupinfo = client.get_group(
            UserPoolId=event['userPoolId'],
            GroupName=rolegroup
        )
        groupinfo = groupinfo.get("Group")
        grouprole = groupinfo.get("RoleArn")
        
    if (adgroups == adroles == ''):
        return event
        
    adgroupsmapping = json.loads(os.environ["ADGROUPS"])
    
    for adgroup in adgroupsmapping:
        adgroupid = adgroup.split(":")
        if (adgroupid[0] in adgroups):
            rolegroup.append(adgroupid[1])

    event["response"]["claimsOverrideDetails"] = {
        "claimsToAddOrOverride": {"scope" : "adgroups"},
        "groupOverrideDetails": {"groupsToOverride": rolegroup, "iamRolesToOverride": [grouprole],
                                 "preferredRole": grouprole}
    }

    print(f'outgoing event: {json.dumps(event)}')

    return event
