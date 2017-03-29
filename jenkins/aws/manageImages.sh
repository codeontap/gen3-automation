#!/bin/bash

# Create/manage images corresponding to the current build
 
if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

function usage() {
    cat <<EOF

Manage images corresponding to the current build

Usage: $(basename $0) -g CODE_COMMIT -u DEPLOYMENT_UNIT -f IMAGE_FORMATS

where

(m) -f IMAGE_FORMATS   is the comma separated list of image formats to manage
(m) -g CODE_COMMIT     to use when defaulting REGISTRY_REPO
(m) -u DEPLOYMENT_UNIT is the deployment unit associated with the imges

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

DEPLOYMENT_UNIT=First entry in DEPLOYMENT_UNIT_LIST
CODE_COMMIT=First entry in CODE_COMMIT_LIST
IMAGE_FORMATS=First entry in IMAGE_FORMAT_LIST

NOTES:

EOF
    exit
}

# Parse options
while getopts ":f:g:hu:" opt; do
    case $opt in
        f)
            IMAGE_FORMATS="${OPTARG}"
            ;;
        g)
            CODE_COMMIT="${OPTARG}"
            ;;
        h)
            usage
            ;;
        u)
            DEPLOYMENT_UNIT="${OPTARG}"
            ;;
        \?)
            echo -e "\nInvalid option: -${OPTARG}" >&2
            exit
            ;;
        :)
            echo -e "\nOption -${OPTARG} requires an argument" >&2
            exit
            ;;
     esac
done

# Apply defaults
DEPLOYMENT_UNIT_ARRAY=(${DEPLOYMENT_UNIT_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})
IMAGE_FORMATS_ARRAY=(${IMAGE_FORMATS_LIST})
DEPLOYMENT_UNIT="${DEPLOYMENT_UNIT:-${DEPLOYMENT_UNIT_ARRAY[0]}}"
CODE_COMMIT="${CODE_COMMIT:-${CODE_COMMIT_ARRAY[0]}}"
IMAGE_FORMATS="${IMAGE_FORMATS:-${IMAGE_FORMATS_ARRAY[0]}}"

# Ensure mandatory arguments have been provided
if [[ (-z "${DEPLOYMENT_UNIT}") ||
        (-z "${CODE_COMMIT}") ||
        (-z "${IMAGE_FORMATS}") ]]; then
    echo -e "\nInsufficient arguments" >&2
    exit
fi

IFS="," read -ra FORMATS <<< "${IMAGE_FORMATS}"

for FORMAT in "${FORMATS[@]}"; do
    case ${FORMAT,,} in
        docker)
            # Package for docker
            if [[ -f Dockerfile ]]; then
                ${AUTOMATION_DIR}/manageDocker.sh -b -s "${DEPLOYMENT_UNIT}" -g "${CODE_COMMIT}"
                RESULT=$?
                if [[ "${RESULT}" -ne 0 ]]; then
                    exit
                fi
            else
                echo -e "\nDockerfile missing" >&2
                RESULT=1
                exit
            fi
            ;;

        lambda)
            IMAGE_FILE="./dist/lambda.zip"

            if [[ -f "${IMAGE_FILE}" ]]; then
                ${AUTOMATION_DIR}/manageLambda.sh -s \
                        -u "${DEPLOYMENT_UNIT}" \
                        -g "${CODE_COMMIT}" \
                        -f "${IMAGE_FILE}"
                RESULT=$?
                if [[ "${RESULT}" -ne 0 ]]; then
                    exit
                fi
            else
                echo -e "\n${IMAGE_FILE} missing" >&2
                RESULT=1
                exit
            fi
            ;;

        swagger)
            IMAGE_FILE="./dist/swagger.json"

            if [[ -f "${IMAGE_FILE}" ]]; then
                ${AUTOMATION_DIR}/manageSwagger.sh -s \
                        -u "${DEPLOYMENT_UNIT}" \
                        -g "${CODE_COMMIT}" \
                        -f "${IMAGE_FILE}"
                RESULT=$?
                if [[ "${RESULT}" -ne 0 ]]; then
                    exit
                fi
            else
                echo -e "\n${IMAGE_FILE} missing" >&2
                RESULT=1
                exit
            fi
            ;;

        *)
            echo -e "\nUnsupported image format \"${FORMAT}\"" >&2
            RESULT=1
            exit
            ;;
    esac
done

# All good
RESULT=0
