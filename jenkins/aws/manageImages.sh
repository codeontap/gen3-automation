#!/bin/bash

# Create images corresponding to the current build
#
# This script is designed to be sourced into framework specific build scripts
 
if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi

SLICE_ARRAY=(${SLICE_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})
IMAGE_FORMAT_ARRAY=(${IMAGE_FORMAT_LIST})

case ${IMAGE_FORMAT_ARRAY[0]} in
    docker)
        # Package for docker
        if [[ -f Dockerfile ]]; then
            ${AUTOMATION_DIR}/manageDocker.sh -b -s "${SLICE_ARRAY[0]}" -g "${CODE_COMMIT_ARRAY[0]}"
            RESULT=$?
            if [[ "${RESULT}" -ne 0 ]]; then
                exit
            fi
        else
            echo -e "\nDockerfile missing"
            exit
        fi
        ;;

    # TODO: Perform checks for AWS Lambda packaging - not sure yet what to check for as a marker
    *)
        echo -e "\nUnsupported image format \"${IMAGE_FORMAT}\""
        exit
        ;;
esac
