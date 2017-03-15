#!/bin/bash

# Create images corresponding to the current build
#
# This script is designed to be sourced into framework specific build scripts
 
if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi

DEPLOYMENT_UNIT_ARRAY=(${DEPLOYMENT_UNIT_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})
IMAGE_FORMATS_ARRAY=(${IMAGE_FORMATS_LIST})

IFS="," read -ra FORMATS <<< "${IMAGE_FORMATS_ARRAY[0]}"

for FORMAT in "${FORMATS[@]}"; do
    case ${FORMAT,,} in
        docker)
            # Package for docker
            if [[ -f Dockerfile ]]; then
                ${AUTOMATION_DIR}/manageDocker.sh -b -s "${DEPLOYMENT_UNIT_ARRAY[0]}" -g "${CODE_COMMIT_ARRAY[0]}"
                RESULT=$?
                if [[ "${RESULT}" -ne 0 ]]; then
                    exit
                fi
            else
                echo -e "\nDockerfile missing" >&2
                exit
            fi
            ;;

        lambda)
            IMAGE_FILE="./dist/lambda.zip"

            # TODO remove once we've sorted out generating lambda builds in JS
            if [[ ! -f "${IMAGE_FILE}" ]]; then
                mkdir dist
                touch "${IMAGE_FILE}"
            fi

            if [[ -f "${IMAGE_FILE}" ]]; then
                ${AUTOMATION_DIR}/manageLambda.sh -s \
                        -u "${DEPLOYMENT_UNIT_ARRAY[0]}" \
                        -g "${CODE_COMMIT_ARRAY[0]}" \
                        -f "${IMAGE_FILE}"
                RESULT=$?
                if [[ "${RESULT}" -ne 0 ]]; then
                    exit
                fi
            else
                echo -e "\n${IMAGE_FILE} missing" >&2
                exit
            fi
            ;;

        *)
            echo -e "\nUnsupported image format \"${FORMAT}\"" >&2
            exit
            ;;
    esac
done