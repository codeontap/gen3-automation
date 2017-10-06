#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${GENERATION_DIR}/common.sh"

findGen3Dirs "${AUTOMATION_DATA_DIR}/${ACCOUNT}"

# Create the account level buckets if required
if [[ "${CREATE_ACCOUNT_BUCKETS}" == "true" ]]; then
    cd ${ACCOUNT_DIR}
    ${GENERATION_DIR}/createAccountTemplate.sh -a ${ACCOUNT}
    RESULT=$?
    [[ "${RESULT}" -ne 0 ]] &&
        fatal "Generation of the account level template for the ${ACCOUNT} account failed"

    # Create the stack
    ${GENERATION_DIR}/createStack.sh -t account
	RESULT=$?
    [[ "${RESULT}" -ne 0 ]] &&
        fatal "Creation of the account level stack for the ${ACCOUNT} account failed"
        
    # Update the infrastructure repo to capture any stack changes
    cd ${ACCOUNT_INFRASTRUCTURE_DIR}

    # Ensure git knows who we are
    git config user.name  "${BUILD_USER}"
    git config user.email "${BUILD_USER_EMAIL}"

    # Record changes
    git add *
    git commit -m "Stack changes as a result of creating the ${ACCOUNT} account stack"
    git push origin master
	RESULT=$?
    [[ "${RESULT}" -ne 0 ]] &&
        fatal "Unable to save the changes resulting from creating the ${ACCOUNT} account stack"
fi

# Update the code and credentials buckets if required
if [[ "${SYNC_ACCOUNT_BUCKETS}" == "true" ]]; then
    cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}
    ${GENERATION_DIR}/syncAccountBuckets.sh -a ${ACCOUNT}
fi

# All good
RESULT=0




