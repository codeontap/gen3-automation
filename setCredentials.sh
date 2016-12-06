#!/bin/bash

# Set up the access 
#
# This script is designed to be sourced into other scripts
#
# $1 = account to be accessed

AWS_CRED_ACCOUNT="${1^^}"

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi

# Clear any previous results
unset AWS_CRED_AWS_ACCESS_KEY_ID_VAR
unset AWS_CRED_AWS_SECRET_ACCESS_KEY_VAR
unset AWS_CRED_TEMP_AWS_ACCESS_KEY_ID
unset AWS_CRED_TEMP_AWS_SECRET_ACCESS_KEY
unset AWS_CRED_TEMP_AWS_SESSION_TOKEN

# First check for account specific credentials
AWS_CRED_OVERRIDE_AWS_ACCESS_KEY_ID_VAR="${AWS_CRED_ACCOUNT}_AWS_ACCESS_KEY_ID"
AWS_CRED_OVERRIDE_AWS_SECRET_ACCESS_KEY_VAR="${AWS_CRED_ACCOUNT}_AWS_SECRET_ACCESS_KEY"
if [[ (-n "${!AWS_CRED_OVERRIDE_AWS_ACCESS_KEY_ID_VAR}") && (-n "${!AWS_CRED_OVERRIDE_AWS_SECRET_ACCESS_KEY_VAR}") ]]; then
    AWS_CRED_AWS_ACCESS_KEY_ID_VAR="${AWS_CRED_OVERRIDE_AWS_ACCESS_KEY_ID_VAR}"
    AWS_CRED_AWS_SECRET_ACCESS_KEY_VAR="${AWS_CRED_OVERRIDE_AWS_SECRET_ACCESS_KEY_VAR})"
else
    # Check for a global automation user/role
    AWS_CRED_AWS_ACCOUNT_ID_VAR="${AWS_CRED_ACCOUNT}_AWS_ACCOUNT_ID"
    AWS_CRED_AUTOMATION_USER_VAR="${AWS_CRED_ACCOUNT}_AUTOMATION_USER"
    if [[ -z "${!AWS_CRED_AUTOMATION_USER_VAR}" ]]; then AWS_CRED_AUTOMATION_USER_VAR="AWS_AUTOMATION_USER"; fi
    AWS_CRED_AUTOMATION_ROLE_VAR="${AWS_CRED_ACCOUNT}_AUTOMATION_ROLE"
    if [[ -z "${!AWS_CRED_AUTOMATION_ROLE_VAR}" ]]; then AWS_CRED_AUTOMATION_ROLE_VAR="AWS_AUTOMATION_ROLE"; fi
    
    if [[ (-n ${!AWS_CRED_AWS_ACCOUNT_ID_VAR}) && (-n ${!AWS_CRED_AUTOMATION_USER_VAR}) ]]; then
        # Assume automation role using automation user access credentials
        # Note that the value for the user is just a way to obtain the access credentials
        # and doesn't have to be the same as the IAM user associated with the credentials
        AWS_CRED_AWS_ACCESS_KEY_ID_VAR="${!AWS_CRED_AUTOMATION_USER_VAR^^}_AWS_ACCESS_KEY_ID"
        AWS_CRED_AWS_SECRET_ACCESS_KEY_VAR="${!AWS_CRED_AUTOMATION_USER_VAR^^}_AWS_SECRET_ACCESS_KEY"
        AWS_CRED_AUTOMATION_ROLE="${!AWS_CRED_AUTOMATION_ROLE_VAR:-codeontap-automation}"
        AWS_CRED_AWS_ACCESS_KEY_ID="${!AWS_CRED_AWS_ACCESS_KEY_ID_VAR}"
        AWS_CRED_AWS_SECRET_ACCESS_KEY="${!AWS_CRED_AWS_SECRET_ACCESS_KEY_VAR}"
        if [[ (-n ${AWS_CRED_AWS_ACCESS_KEY_ID}) && (-n ${AWS_CRED_AWS_SECRET_ACCESS_KEY}) ]]; then
            TEMP_CREDENTIAL_FILE="${AUTOMATION_DATA_DIR}/temp_aws_credentials.json"
            export AWS_ACCESS_KEY_ID="${AWS_CRED_AWS_ACCESS_KEY_ID}"
            export AWS_SECRET_ACCESS_KEY="${AWS_CRED_AWS_SECRET_ACCESS_KEY}"
            unset AWS_SESSION_TOKEN
            aws sts assume-role \
                --role-arn arn:aws:iam::${!AWS_CRED_AWS_ACCOUNT_ID_VAR}:role/${AWS_CRED_AUTOMATION_ROLE} \
                --role-session-name "$(echo $GIT_USER | tr -d ' ' )" \
                --output json > $TEMP_CREDENTIAL_FILE
            AWS_CRED_TEMP_AWS_ACCESS_KEY_ID=$(cat $TEMP_CREDENTIAL_FILE | jq -r '.Credentials.AccessKeyId')
            AWS_CRED_TEMP_AWS_SECRET_ACCESS_KEY=$(cat $TEMP_CREDENTIAL_FILE | jq -r '.Credentials.SecretAccessKey')
            AWS_CRED_TEMP_AWS_SESSION_TOKEN=$(cat $TEMP_CREDENTIAL_FILE | jq -r '.Credentials.SessionToken')
            rm $TEMP_CREDENTIAL_FILE
        fi
    fi
fi
