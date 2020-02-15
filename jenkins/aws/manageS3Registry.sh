#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ -z ${AUTOMATION_DEBUG} ]] && rm -rf ./temp_*; exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Defaults
REGISTRY_TAG_DEFAULT="latest"
REGISTRY_TYPE_DEFAULT="lambda"
REGISTRY_FILENAME_DEFAULT="lambda.zip"
REGISTRY_OPERATION_SAVE="save"
REGISTRY_OPERATION_VERIFY="verify"
REGISTRY_OPERATION_TAG="tag"
REGISTRY_OPERATION_PULL="pull"
REGISTRY_OPERATION_DEFAULT="${REGISTRY_OPERATION_VERIFY}"
REGISTRY_EXPAND_DEFAULT="false"
REGISTRY_REMOVE_SOURCE_DEFAULT="false"

function usage() {
    cat <<EOF

Manage images in an S3 backed registry

Usage: $(basename $0) -s -v -p -k -x
                        -y REGISTRY_TYPE
                        -c REGISTRY_SCOPE
                        -a REGISTRY_PROVIDER
                        -l REGISTRY_REPO
                        -t REGISTRY_TAG
                        -f REGISTRY_FILENAME
                        -z REMOTE_REGISTRY_PROVIDER
                        -i REMOTE_REGISTRY_REPO
                        -r REMOTE_REGISTRY_TAG
                        -d REGISTRY_PRODUCT
                        -u REGISTRY_DEPLOYMENT_UNIT
                        -g REGISTRY_CODE_COMMIT
                        -b REGISTRY_ADDITIONAL_DIRECTORY
                        -e REGISTRY_REMOVE_SOURCE

where

(o) -a REGISTRY_PROVIDER                is the local registry provider
(o) -b REGISTRY_ADDITIONAL_DIRECTORY    is an additonal directory that is stored with the image
(o) -c REGISTRY_SCOPE                   is the scope of the registry
(o) -d REGISTRY_PRODUCT                 is the product to use when defaulting REGISTRY_REPO
(o) -e REGISTRY_REMOVE_SOURCE           remove the source data once the image is in the registry
(o) -f REGISTRY_FILENAME                is the filename used when storing images
(o) -g REGISTRY_CODE_COMMIT             to use when defaulting REGISTRY_REPO
    -h                                  shows this text
(o) -i REMOTE_REGISTRY_REPO             is the repository to pull
(o) -k                                  tag an image in the local registry with the remote details
                                        (REGISTRY_OPERATION=${REGISTRY_OPERATION_TAG})
(o) -l REGISTRY_REPO                    is the local repository
(o) -p                                  pull image from a remote to a local registry
                                        (REGISTRY_OPERATION=${REGISTRY_OPERATION_PULL})
(o) -r REMOTE_REGISTRY_TAG              is the tag to pull
(o) -s                                  save in local registry
                                        (REGISTRY_OPERATION=${REGISTRY_OPERATION_SAVE})
(o) -t REGISTRY_TAG                     is the local tag
(o) -u REGISTRY_DEPLOYMENT_UNIT         is the deployment unit to use when defaulting REGISTRY_REPO
(o) -v                                  verify image is present in local registry
                                        (REGISTRY_OPERATION=${REGISTRY_OPERATION_VERIFY})
(o) -x                                  expand on save if REGISTRY_FILENAME is a zip file
                                        (REGISTRY_EXPAND=true)
(m) -y REGISTRY_TYPE                    is the registry image type
(o) -z REMOTE_REGISTRY_PROVIDER         is the registry provider to pull from

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

REGISTRY_PROVIDER=${PRODUCT_${REGISTRY_TYPE}_PROVIDER}
REGISTRY_TYPE=${REGISTRY_TYPE_DEFAULT}
REGISTRY_FILENAME=${REGISTRY_FILENAME_DEFAULT}
REGISTRY_REPO="REGISTRY_PRODUCT/REGISTRY_DEPLOYMENT_UNIT/REGISTRY_CODE_COMMIT" or
            "REGISTRY_PRODUCT/REGISTRY_CODE_COMMIT" if no REGISTRY_DEPLOYMENT_UNIT defined
REGISTRY_TAG=${REGISTRY_TAG_DEFAULT}
REMOTE_REGISTRY_PROVIDER=${PRODUCT_REMOTE_${REGISTRY_TYPE}_PROVIDER}
REMOTE_REGISTRY_REPO=REGISTRY_REPO
REMOTE_REGISTRY_TAG=REGISTRY_TAG
REGISTRY_OPERATION=${REGISTRY_OPERATION_DEFAULT}
REGISTRY_PRODUCT=${PRODUCT}
REGISTRY_EXPAND=${REGISTRY_EXPAND_DEFAULT}
REGISTRY_REMOVE_SOURCE=${REGISTRY_REMOVE_SOURCE_DEFAULT}

NOTES:

1. Currently "segment" is the only accepted value for registry scope. If not
   provided, the account level registry is used by default.

EOF
    exit
}

# Parse options
while getopts ":a:b:c:d:e:f:g:hki:l:pr:st:u:vxy:z:" opt; do
    case $opt in
        a)
            REGISTRY_PROVIDER="${OPTARG}"
            ;;
        b)
            REGISTRY_ADDITIONAL_DIRECTORY="${OPTARG}"
            ;;
        c)
            REGISTRY_SCOPE="${OPTARG}"
            ;;
        d)
            REGISTRY_PRODUCT="${OPTARG}"
            ;;
        e)
            REGISTRY_REMOVE_SOURCE="true"
            ;;
        f)
            REGISTRY_FILENAME="${OPTARG}"
            ;;
        g)
            REGISTRY_CODE_COMMIT="${OPTARG}"
            ;;
        h)
            usage
            ;;
        i)
            REMOTE_REGISTRY_REPO="${OPTARG}"
            ;;
        k)
            REGISTRY_OPERATION="${REGISTRY_OPERATION_TAG}"
            ;;
        l)
            REGISTRY_REPO="${OPTARG}"
            ;;
        p)
            REGISTRY_OPERATION="${REGISTRY_OPERATION_PULL}"
            ;;
        r)
            REMOTE_REGISTRY_TAG="${OPTARG}"
            ;;
        s)
            REGISTRY_OPERATION="${REGISTRY_OPERATION_SAVE}"
            ;;
        t)
            REGISTRY_TAG="${OPTARG}"
            ;;
        u)
            REGISTRY_DEPLOYMENT_UNIT="${OPTARG}"
            ;;
        v)
            REGISTRY_OPERATION="${REGISTRY_OPERATION_VERIFY}"
            ;;
        x)
            REGISTRY_EXPAND="true"
            ;;
        y)
            REGISTRY_TYPE="${OPTARG}"
            ;;
        z)
            REMOTE_REGISTRY_PROVIDER="${OPTARG}"
            ;;
        \?)
            fatalOption
            ;;
        :)
            fatalOptionArgument
            ;;
     esac
done

# Define registry provider attributes
# $1 = provider
# $2 = provider type
# $3 = variable prefix
function defineRegistryProviderAttributes() {
    local DRPA_PROVIDER="${1^^}"
    local DRPA_TYPE="${2^^}"
    local DRPA_PREFIX="${3^^}"

    # Attribute variable names
    for DRPA_ATTRIBUTE in "DNS" "REGION"; do
        DRPA_PROVIDER_VAR="${DRPA_PROVIDER}_${DRPA_TYPE}_${DRPA_ATTRIBUTE}"
        declare -g ${DRPA_PREFIX}_${DRPA_ATTRIBUTE}="${!DRPA_PROVIDER_VAR}"
    done
}

PROVIDER_IDS=()
PROVIDER_AWS_ACCESS_KEY_IDS=()
PROVIDER_AWS_SECRET_ACCESS_KEYS=()
PROVIDER_AWS_SESSION_TOKENS=()

# Set credentials for S3 access
# $1 = provider
function setCredentials() {

    # Key variables
    local SC_PROVIDER="${1^^}"

    # Check if credentials already obtained
    for INDEX in $(seq 0 $((${#PROVIDER_IDS[@]}-1 )) ); do
        if [[ "${PROVIDER_IDS[$INDEX]}" == "${SC_PROVIDER}" ]]; then
            # Use cached credentials
            export AWS_ACCESS_KEY_ID="${PROVIDER_AWS_ACCESS_KEY_IDS[$INDEX]}"
            export AWS_SECRET_ACCESS_KEY="${PROVIDER_AWS_SECRET_ACCESS_KEYS[$INDEX]}"
            export AWS_SESSION_TOKEN="${PROVIDER_AWS_SESSION_TOKENS[$INDEX]}"
            [[ -z "${AWS_SESSION_TOKEN}" ]] && unset AWS_SESSION_TOKEN
            return 0
        fi
    done

    # New registry - set up the AWS credentials
    . ${AUTOMATION_DIR}/setCredentials.sh "${SC_PROVIDER}"

    # Define the credentials
    export AWS_ACCESS_KEY_ID="${AWS_CRED_TEMP_AWS_ACCESS_KEY_ID:-${!AWS_CRED_AWS_ACCESS_KEY_ID_VAR}}"
    export AWS_SECRET_ACCESS_KEY="${AWS_CRED_TEMP_AWS_SECRET_ACCESS_KEY:-${!AWS_CRED_AWS_SECRET_ACCESS_KEY_VAR}}"
    export AWS_SESSION_TOKEN="${AWS_CRED_TEMP_AWS_SESSION_TOKEN}"
    [[ -z "${AWS_SESSION_TOKEN}" ]] && unset AWS_SESSION_TOKEN

    # Cache the redentials
    PROVIDER_IDS+=("${SC_PROVIDER}")
    PROVIDER_AWS_ACCESS_KEY_IDS+=("${AWS_ACCESS_KEY_ID}")
    PROVIDER_AWS_SECRET_ACCESS_KEYS+=("${AWS_SECRET_ACCESS_KEY}")
    PROVIDER_AWS_SESSION_TOKENS+=("${AWS_SESSION_TOKEN}")
    return 0

}

# Copy files to the registry
# $1 = file to copy
# $2 = name to save it as
function copyToRegistry() {

    # Key variables
    local FILE_TO_COPY="${1}"
    local SAVE_AS="${2}"
    local FILES_TEMP_DIR="temp_files_dir"

    if [[ "${FILE_TO_COPY}" =~ ^s3:// ]]; then

        aws --region "${REGISTRY_PROVIDER_REGION}" s3 ls "${FILE_TO_COPY}"  >/dev/null 2>&1
        RESULT=$?
        [[ "$RESULT" -ne 0 ]] &&
            fatal "Can't access ${FILE_TO_COPY}" && exit

        aws --region "${REGISTRY_PROVIDER_REGION}" s3 cp --recursive "${FILE_TO_COPY}" "${FULL_REGISTRY_IMAGE_PATH}/"

    else

        rm -rf "${FILES_TEMP_DIR}"
        mkdir -p "${FILES_TEMP_DIR}"
        cp "${FILE_TO_COPY}" "${FILES_TEMP_DIR}/${SAVE_AS}"
        RESULT=$?
        [[ $RESULT -ne 0 ]] && fatal "Unable to copy ${FILE_TO_COPY}" && exit

        if [[ ("${REGISTRY_EXPAND}" == "true") &&
            ("${FILE_TO_COPY##*.}" == "zip") ]]; then
                unzip "${FILE_TO_COPY}" -d "${FILES_TEMP_DIR}"
                RESULT=$?
                [[ $RESULT -ne 0 ]] &&
                    fatal "Unable to unzip ${FILE_TO_COPY}" && exit
        fi

        aws --region "${REGISTRY_PROVIDER_REGION}" s3 cp --recursive "${FILES_TEMP_DIR}/" "${FULL_REGISTRY_IMAGE_PATH}/"
        RESULT=$?
        [[ $RESULT -ne 0 ]] &&
            fatal "Unable to save ${BASE_REGISTRY_FILENAME} in the local registry" && exit

    fi

    aws --region "${REGISTRY_PROVIDER_REGION}" s3 cp "${TAG_FILE}" "${FULL_TAGGED_REGISTRY_IMAGE}"
    RESULT=$?
    [[ $RESULT -ne 0 ]] &&
        fatal "Unable to tag ${BASE_REGISTRY_FILENAME} as latest" && exit
}

# Remove the source S3 content. This is used to keep the S3 Stage clean for new uploads
function removeSource() {
    local FILE_TO_REMOVE="${1}"

    info "removing ${FILE_TO_REMOVE}"

    if [[ "${FILE_TO_REMOVE}" =~ ^s3:// ]]; then

        aws --region "${REGISTRY_PROVIDER_REGION}" s3 ls "${FILE_TO_REMOVE}"  >/dev/null 2>&1
        RESULT=$?
        [[ "$RESULT" -ne 0 ]] &&
            fatal "Can't access ${FILE_TO_REMOVE}" && return 128

        aws --region "${REGISTRY_PROVIDER_REGION}" s3 rm --recursive "${FILE_TO_REMOVE}"

    else
        info "Local data not removed as it is temporary anyway"
    fi
}

# Apply local registry defaults
REGISTRY_TYPE="${REGISTRY_TYPE,,:-${REGISTRY_TYPE_DEFAULT}}"
REGISTRY_PROVIDER_VAR="PRODUCT_${REGISTRY_TYPE^^}_PROVIDER"
REGISTRY_PROVIDER="${REGISTRY_PROVIDER:-${!REGISTRY_PROVIDER_VAR}}"
REGISTRY_FILENAME="${REGISTRY_FILENAME:-${REGISTRY_FILENAME_DEFAULT}}"
BASE_REGISTRY_FILENAME="${REGISTRY_FILENAME##*/}"
REGISTRY_TAG="${REGISTRY_TAG:-${REGISTRY_TAG_DEFAULT}}"
REGISTRY_OPERATION="${REGISTRY_OPERATION:-${REGISTRY_OPERATION_DEFAULT}}"
REGISTRY_PRODUCT="${REGISTRY_PRODUCT:-${PRODUCT}}"
REGISTRY_REMOVE_SOURCE="${REGISTRY_REMOVE_SOURCE:-${REGISTRY_REMOVE_SOURCE_DEFAULT}}"

# Handle registry scope values
case "${REGISTRY_SCOPE}" in
    segment)
        if [[ -n "${SEGMENT}" ]]; then
            REGISTRY_SUBTYPE="/${SEGMENT}"
        else
          fatal "Segment scoped registry required but SEGMENT not defined" && exit
        fi
        ;;
    *)
        REGISTRY_SUBTYPE=""
        ;;
esac

# Default local repository is based on standard image naming conventions
if [[ (-n "${REGISTRY_PRODUCT}") &&
        (-n "${REGISTRY_CODE_COMMIT}") ]]; then
    if [[ (-n "${REGISTRY_DEPLOYMENT_UNIT}" ) ]]; then
        REGISTRY_REPO="${REGISTRY_REPO:-${REGISTRY_PRODUCT}${REGISTRY_SUBTYPE}/${REGISTRY_DEPLOYMENT_UNIT}/${REGISTRY_CODE_COMMIT}}"
    else
        REGISTRY_REPO="${REGISTRY_REPO:-${REGISTRY_PRODUCT}${REGISTRY_SUBTYPE}/${REGISTRY_CODE_COMMIT}}"
    fi
fi

# Empty file for tagging operations
TAG_FILE="./temp_${REGISTRY_TAG}"
touch "${TAG_FILE}"


# Determine registry provider details
defineRegistryProviderAttributes "${REGISTRY_PROVIDER}" "${REGISTRY_TYPE}" "REGISTRY_PROVIDER"

# Ensure the local repository has been determined
[[ -z "${REGISTRY_REPO}" ]] &&
    fatal "Job requires the local repository name, or the product/deployment unit/commit" && exit

# Apply remote registry defaults
REMOTE_REGISTRY_PROVIDER_VAR="PRODUCT_REMOTE_${REGISTRY_TYPE^^}_PROVIDER"
REMOTE_REGISTRY_PROVIDER="${REMOTE_REGISTRY_PROVIDER:-${!REMOTE_REGISTRY_PROVIDER_VAR}}"
REMOTE_REGISTRY_REPO="${REMOTE_REGISTRY_REPO:-$REGISTRY_REPO}"
REMOTE_REGISTRY_TAG="${REMOTE_REGISTRY_TAG:-$REGISTRY_TAG}"

# Determine remote registry provider details
defineRegistryProviderAttributes "${REMOTE_REGISTRY_PROVIDER}" "${REGISTRY_TYPE}" "REMOTE_REGISTRY_PROVIDER"

# pull = tag if local provider = remote provider
if [[ ("${REGISTRY_PROVIDER}" == "${REMOTE_REGISTRY_PROVIDER}") &&
        ("${REGISTRY_OPERATION}" == "${REGISTRY_OPERATION_PULL}") ]]; then
    REGISTRY_OPERATION="${REGISTRY_OPERATION_TAG}"
fi

# Formulate the local registry details
REGISTRY_IMAGE="${REGISTRY_TYPE}/${REGISTRY_REPO}/${BASE_REGISTRY_FILENAME}"
TAGGED_REGISTRY_IMAGE="${REGISTRY_TYPE}/${REGISTRY_REPO}/tags/${REGISTRY_TAG}"
FULL_REGISTRY_IMAGE="s3://${REGISTRY_PROVIDER_DNS}/${REGISTRY_IMAGE}"
FULL_REGISTRY_IMAGE_PATH="s3://${REGISTRY_PROVIDER_DNS}/${REGISTRY_TYPE}/${REGISTRY_REPO}"
FULL_TAGGED_REGISTRY_IMAGE="s3://${REGISTRY_PROVIDER_DNS}/${TAGGED_REGISTRY_IMAGE}"

# Set up credentials for registry access
setCredentials "${REGISTRY_PROVIDER}"

# Confirm access to the local registry
aws --region "${REGISTRY_PROVIDER_REGION}" s3 ls "s3://${REGISTRY_PROVIDER_DNS}/${REGISTRY_TYPE}" >/dev/null 2>&1
RESULT=$?
[[ "$RESULT" -ne 0 ]] &&
    fatal "Can't access ${REGISTRY_TYPE} registry at ${REGISTRY_PROVIDER_DNS}" && exit

# Perform the required action
case ${REGISTRY_OPERATION} in
    ${REGISTRY_OPERATION_SAVE})
        copyToRegistry "${REGISTRY_FILENAME}" "${BASE_REGISTRY_FILENAME}"
        if [[ -n "${REGISTRY_ADDITIONAL_DIRECTORY}" ]]; then
            copyToRegistry "${REGISTRY_ADDITIONAL_DIRECTORY}"
        fi

        # Clean out the source staging directory
        if [[ "${REGISTRY_REMOVE_SOURCE}" == "true" ]]; then
            removeSource "${REGISTRY_FILENAME}"
            if [[ -n "${REGISTRY_ADDITIONAL_DIRECTORY}" ]]; then
                removeSource "${REGISTRY_ADDITIONAL_DIRECTORY}"
            fi
        fi
        ;;

    ${REGISTRY_OPERATION_VERIFY})
        # Check whether the image is already in the local registry
        aws --region "${REGISTRY_PROVIDER_REGION}" s3 ls "${FULL_TAGGED_REGISTRY_IMAGE}" >/dev/null 2>&1
        RESULT=$?
        if [[ "${RESULT}" -eq 0 ]]; then
            info "${REGISTRY_TYPE^} image ${REGISTRY_IMAGE} present in the local registry"
            exit
        else
            info "${REGISTRY_TYPE^} image ${REGISTRY_IMAGE} with tag ${REGISTRY_TAG} not present in the local registry"
            exit
        fi
        ;;

    ${REGISTRY_OPERATION_TAG})
        # Formulate the remote registry details
        REMOTE_TAGGED_REGISTRY_IMAGE="${REGISTRY_TYPE}/${REMOTE_REGISTRY_REPO}/tags/${REMOTE_REGISTRY_TAG}"
        FULL_REMOTE_TAGGED_REGISTRY_IMAGE="s3://${REGISTRY_PROVIDER_DNS}/${REMOTE_TAGGED_REGISTRY_IMAGE}"

        # Check for the local image
        aws --region "${REGISTRY_PROVIDER_REGION}" s3 ls "${FULL_REGISTRY_IMAGE}" >/dev/null 2>&1
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            fatal "Can't find ${REGISTRY_IMAGE} in ${REGISTRY_PROVIDER_DNS}" && exit
        else
            # Copy to S3
            aws --region "${REGISTRY_PROVIDER_REGION}" s3 cp "${TAG_FILE}" "${FULL_REMOTE_TAGGED_REGISTRY_IMAGE}"
            RESULT=$?
            [[ "${RESULT}" -ne 0 ]] &&
                fatal "Couldn't tag image ${FULL_REGISTRY_IMAGE} with tag ${REMOTE_REGISTRY_TAG}" && exit
        fi
        ;;

    ${REGISTRY_OPERATION_PULL})
        # Formulate the remote registry details
        REMOTE_REGISTRY_IMAGE="${REGISTRY_TYPE}/${REMOTE_REGISTRY_REPO}/${BASE_REGISTRY_FILENAME}"
        REMOTE_REGISTRY_PATH="${REGISTRY_TYPE}/${REMOTE_REGISTRY_REPO}"
        REMOTE_TAGGED_REGISTRY_IMAGE="${REGISTRY_TYPE}/${REMOTE_REGISTRY_REPO}/tags/${REMOTE_REGISTRY_TAG}"
        FULL_REMOTE_REGISTRY_IMAGE="s3://${REMOTE_REGISTRY_PROVIDER_DNS}/${REMOTE_REGISTRY_IMAGE}"
        FULL_REMOTE_TAGGED_REGISTRY_IMAGE="s3://${REMOTE_REGISTRY_PROVIDER_DNS}/${REMOTE_TAGGED_REGISTRY_IMAGE}"
        FULL_REMOTE_REGISTRY_PATH="s3://${REMOTE_REGISTRY_PROVIDER_DNS}/${REMOTE_REGISTRY_PATH}"
        IMAGE_FILE="./temp_${BASE_REGISTRY_FILENAME}"

        # Get access to the remote registry
        setCredentials "${REMOTE_REGISTRY_PROVIDER}"

        # Confirm image is present
        aws --region "${REMOTE_REGISTRY_PROVIDER_REGION}" s3 ls "${FULL_REMOTE_TAGGED_REGISTRY_IMAGE}" >/dev/null 2>&1
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            fatal "Can't find ${REMOTE_REGISTRY_IMAGE} in ${REMOTE_REGISTRY_PROVIDER_DNS}" && exit
        else
            # Copy image
            aws --region "${REGISTRY_PROVIDER_REGION}" s3 cp "${FULL_REMOTE_REGISTRY_IMAGE}" "${IMAGE_FILE}"
            RESULT=$?
            [[ "$RESULT" -ne 0 ]] &&
                fatal "Can't copy remote image ${FULL_REMOTE_REGISTRY_IMAGE}" && exit
        fi

        # Now copy to local rgistry
        setCredentials "${REGISTRY_PROVIDER}"

        copyToRegistry "${IMAGE_FILE}" "${BASE_REGISTRY_FILENAME}"
        if [[ -n "${REGISTRY_ADDITIONAL_DIRECTORY}" ]]; then
            if [[ "${REGISTRY_ADDITIONAL_DIRECTORY}" == "REGISTRY_CONTENT" ]]; then
                copyToRegistry "${FULL_REMOTE_REGISTRY_PATH}"
            else
                copyToRegistry "${REGISTRY_ADDITIONAL_DIRECTORY}"
            fi
        fi
        ;;

    *)
        fatal "Unknown operation \"${REGISTRY_OPERATION}\"" && exit
        ;;
esac

# All good
RESULT=0
