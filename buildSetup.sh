#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Check for repo provided slice list
# slice.ref is legacy - always use slices.ref even if one slice
if [[ -z "${SLICE_LIST}" ]]; then
    if [ -e slices.ref ]; then
        export SLICE_LIST=`cat slices.ref`
    else
        if [ -e slice.ref ]; then
            export SLICE_LIST=`cat slice.ref`
        fi
    fi
    echo "SLICE_LIST=${SLICE_LIST}" >> ${AUTOMATION_DATA_DIR}/context.properties
fi

SLICE_ARRAY=(${SLICE_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})

# Record key parameters for downstream jobs
echo "GIT_COMMIT=${CODE_COMMIT_ARRAY[0]}" >> $AUTOMATION_DATA_DIR/chain.properties
echo "SLICES=${SLICE_LIST}" >> $AUTOMATION_DATA_DIR/chain.properties

# Include the build information in the detail message
${AUTOMATION_DIR}/manageBuildReferences.sh -l
RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then exit; fi

# Perform checks for Docker packaging
if [[ -f Dockerfile ]]; then
    ${AUTOMATION_DIR}/manageDocker.sh -v -s "${SLICE_ARRAY[0]}" -g "${CODE_COMMIT_ARRAY[0]}"
    RESULT=$?
    if [[ "${RESULT}" -eq 0 ]]; then
        RESULT=1
        exit
    fi
fi

# TODO: Perform checks for AWS Lambda packaging - not sure yet what to check for as a marker

# All good
RESULT=0