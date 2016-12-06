#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Create the account level buckets if required
if [[ "${CREATE_ACCOUNT_BUCKETS}" == "true" ]]; then
    cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${ACCOUNT}
    ${GENERATION_DIR}/createAccountTemplate.sh -a ${ACCOUNT}
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Generation of the account level template for the ${ACCOUNT} account failed"
        exit
    fi

    # Create the stack
    ${GENERATION_DIR}/createStack.sh -t account
	RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Creation of the account level stack for the ${ACCOUNT} account failed"
        exit
    fi
        
    # Update the infrastructure repo to capture any stack changes
    cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}/infrastructure/${ACCOUNT}

    # Ensure git knows who we are
    git config user.name  "${BUILD_USER}"
    git config user.email "${BUILD_USER_EMAIL}"

    # Record changes
    git add *
    git commit -m "Stack changes as a result of creating the ${ACCOUNT} account stack"
    git push origin master
	RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Unable to save the changes resulting from creating the ${ACCOUNT} account stack"
        exit
    fi
fi

# Update the code and credentials buckets if required
if [[ "${SYNC_ACCOUNT_BUCKETS}" == "true" ]]; then
    cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}
    ${GENERATION_DIR}/syncAccountBuckets.sh -a ${ACCOUNT}
fi

# All good
RESULT=0




