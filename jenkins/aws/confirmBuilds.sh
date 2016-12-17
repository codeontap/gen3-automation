#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

CONFIRM_BUILD_OPERATION_DEPLOY="promotion"
CONFIRM_BUILD_OPERATION_DEPLOY="hotfix"
CONFIRM_BUILD_OPERATION_DEPLOY="deploy"
CONFIRM_BUILD_OPERATION_DEFAULT="${CONFIRM_BUILD_OPERATION_DEPLOY}"
function usage() {
    echo -e "\nConfirm build references point to valid build images"
    echo -e "\nUsage: $(basename $0) -o OPERATION"
    echo -e "\nwhere\n"
    echo -e "    -h shows this text"
    echo -e "(m) -o OPERATION is the operation being executed"
    echo -e "\nDEFAULTS:\n"
    echo -e "OPERATION = \${CONFIRM_BUILD_OPERATION_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e ""
    exit
}

while getopts ":ho:" opt; do
    case $opt in
        h)
            usage
            ;;
        o)
            OPERATION="${OPTARG}"
            ;;
        \?)
            echo -e "\nInvalid option: -${OPTARG}"
            usage
            ;;
        :)
            echo -e "\nOption -${OPTARG} requires an argument"
            usage
            ;;
     esac
done

# Apply defaults
OPERATION="${OPERATION:-${CONFIRM_BUILD_OPERATION_DEFAULT}}"

# Verify the build information
case "${OPERATION}" in
    ${CONFIRM_BUILD_OPERATION_DEPLOY})
        ${AUTOMATION_DIR}/manageBuildReferences.sh -v ${VERIFICATION_TAG:-latest}
        ;;
esac

RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then exit; fi

# Include the build information in the detail message
${AUTOMATION_DIR}/manageBuildReferences.sh -l
RESULT=$?
