#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap '[[ -z ${AUTOMATION_DEBUG} ]] && rm -rf ./temp_*; exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

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

function usage() {
    cat <<EOF

Manage images in an S3 backed registry

Usage: $(basename $0) -s -v -p -k -x
                        -y REGISTRY_TYPE
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

where

(o) -a REGISTRY_PROVIDER        is the local registry provider
(o) -d REGISTRY_PRODUCT         is the product to use when defaulting REGISTRY_REPO
(o) -f REGISTRY_FILENAME        is the filename used when storing images
(o) -g REGISTRY_CODE_COMMIT     to use when defaulting REGISTRY_REPO
    -h                          shows this text
(o) -i REMOTE_REGISTRY_REPO     is the repository to pull
(o) -k                          tag an image in the local registry with the remote details
                                (REGISTRY_OPERATION=${REGISTRY_OPERATION_TAG})
(o) -l REGISTRY_REPO            is the local repository
(o) -p                          pull image from a remote to a local registry
                                (REGISTRY_OPERATION=${REGISTRY_OPERATION_PULL})
(o) -r REMOTE_REGISTRY_TAG      is the tag to pull
(o) -s                          save in local registry
                                (REGISTRY_OPERATION=${REGISTRY_OPERATION_SAVE})
(o) -t REGISTRY_TAG             is the local tag
(o) -u REGISTRY_DEPLOYMENT_UNIT is the deployment unit to use when defaulting REGISTRY_REPO
(o) -v                          verify image is present in local registry
                                (REGISTRY_OPERATION=${REGISTRY_OPERATION_VERIFY})
(o) -x                          expand on save if REGISTRY_FILENAME is a zip file
                                (REGISTRY_EXPAND=true)
(m) -y REGISTRY_TYPE            is the registry image type
(o) -z REMOTE_REGISTRY_PROVIDER is the registry provider to pull from

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

NOTES:

EOF
    exit
}

# Parse options
while getopts ":a:d:f:g:hki:l:pr:st:u:vxy:z:" opt; do
    case $opt in
        a)
            REGISTRY_PROVIDER="${OPTARG}"
            ;;
        d)
            REGISTRY_PRODUCT="${OPTARG}"
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
            echo -e "\nInvalid option: -${OPTARG}" >&2
            exit
            ;;
        :)
            echo -e "\nOption -${OPTARG} requires an argument" >&2
            exit
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
            if [[ -z "${AWS_SESSION_TOKEN}" ]]; then
                unset AWS_SESSION_TOKEN
            fi
            return 0
        fi
    done

    # New registry - set up the AWS credentials
    . ${AUTOMATION_DIR}/setCredentials.sh "${SC_PROVIDER}"

    # Define the credentials
    export AWS_ACCESS_KEY_ID="${AWS_CRED_TEMP_AWS_ACCESS_KEY_ID:-${!AWS_CRED_AWS_ACCESS_KEY_ID_VAR}}"
    export AWS_SECRET_ACCESS_KEY="${AWS_CRED_TEMP_AWS_SECRET_ACCESS_KEY:-${!AWS_CRED_AWS_SECRET_ACCESS_KEY_VAR}}"
    export AWS_SESSION_TOKEN="${AWS_CRED_TEMP_AWS_SESSION_TOKEN}"
    if [[ -z "${AWS_SESSION_TOKEN}" ]]; then
        unset AWS_SESSION_TOKEN
    fi

    # Cache the redentials
    PROVIDER_IDS+=("${SC_PROVIDER}")
    PROVIDER_AWS_ACCESS_KEY_IDS+=("${AWS_ACCESS_KEY_ID}")
    PROVIDER_AWS_SECRET_ACCESS_KEYS+=("${AWS_SECRET_ACCESS_KEY}")
    PROVIDER_AWS_SESSION_TOKENS+=("${AWS_SESSION_TOKEN}")
    return 0

}

# Copy files to the registry
# $1 = file to copy
function copyToRegistry() {

    # Key variables
    local FILE_TO_COPY="${1}"
    local FILES_TEMP_DIR="temp_files_dir"

    rm -rf "${FILES_TEMP_DIR}"
    mkdir -p "${FILES_TEMP_DIR}"
    cp "${FILE_TO_COPY}" "${FILES_TEMP_DIR}"
    if [[ ("${REGISTRY_EXPAND}" == "true") &&
            ("${FILE_TO_COPY##*.}" == "zip") ]]; then
        unzip "${FILE_TO_COPY}" -d "${FILES_TEMP_DIR}"
    fi

    aws --region "${REGISTRY_PROVIDER_REGION}" s3 cp --recursive "${FILES_TEMP_DIR}/" "${FULL_REGISTRY_IMAGE_PATH}/"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "\nUnable to save ${BASE_REGISTRY_FILENAME} in the local registry" >&2
        exit
    fi
    aws --region "${REGISTRY_PROVIDER_REGION}" s3 cp "${TAG_FILE}" "${FULL_TAGGED_REGISTRY_IMAGE}"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "\nUnable to tag ${BASE_REGISTRY_FILENAME} as latest" >&2
        exit
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

# Default local repository is based on standard image naming conventions
if [[ (-n "${REGISTRY_PRODUCT}") && 
        (-n "${REGISTRY_CODE_COMMIT}") ]]; then
    if [[ (-n "${REGISTRY_DEPLOYMENT_UNIT}" ) ]]; then
        REGISTRY_REPO="${REGISTRY_REPO:-${REGISTRY_PRODUCT}/${REGISTRY_DEPLOYMENT_UNIT}/${REGISTRY_CODE_COMMIT}}"
    else
        REGISTRY_REPO="${REGISTRY_REPO:-${REGISTRY_PRODUCT}/${REGISTRY_CODE_COMMIT}}"
    fi
fi

# Empty file for tagging operations
TAG_FILE="./temp_${REGISTRY_TAG}"
touch "${TAG_FILE}"


# Determine registry provider details
defineRegistryProviderAttributes "${REGISTRY_PROVIDER}" "${REGISTRY_TYPE}" "REGISTRY_PROVIDER"

# Ensure the local repository has been determined
if [[ -z "${REGISTRY_REPO}" ]]; then
    echo -e "\nJob requires the local repository name, or the product/deployment unit/commit" >&2
    exit
fi

# Apply remote registry defaults
REMOTE_REGISTRY_PROVIDER_VAR="PRODUCT_REMOTE_${REGISTRY_TYPE^^}_PROVIDER"
REMOTE_REGISTRY_PROVIDER="${REMOTE_REGISTRY_PROVIDER:-${!REMOTE_REGISTRY_PROVIDER_VAR}}"
REMOTE_REGISTRY_REPO="${REMOTE_REGISTRY_REPO:-$REGISTRY_REPO}"
REMOTE_REGISTRY_TAG="${REMOTE_REGISTRY_TAG:-$REGISTRY_TAG}"

# Determine remote registry provider details
defineRegistryProviderAttributes "${REMOTE_REGISTRY_PROVIDER}" "${REGISTRY_TYPE}" "REMOTE_REGISTRY_PROVIDER"

# pull = tag if local provider = remote provider
if [[ ("${REGISTRY_PROVIDER}" == "${REMOTE_REGISTRY_PROVIDER}") &&
        ("${REGISTRY_OPERATION}" == "${${REGISTRY_OPERATION_PULL}}") ]]; then
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
if [[ "$RESULT" -ne 0 ]]; then
    echo -e "\nCan't access ${REGISTRY_TYPE} registry at ${REGISTRY_PROVIDER_DNS}" >&2
    exit
fi

# Perform the required action
case ${REGISTRY_OPERATION} in
    ${REGISTRY_OPERATION_SAVE})
        copyToRegistry "${REGISTRY_FILENAME}"
        ;;

    ${REGISTRY_OPERATION_VERIFY})
        # Check whether the image is already in the local registry
        aws --region "${REGISTRY_PROVIDER_REGION}" s3 ls "${FULL_TAGGED_REGISTRY_IMAGE}" >/dev/null 2>&1
        RESULT=$?
        if [[ "${RESULT}" -eq 0 ]]; then
            echo -e "\n${REGISTRY_TYPE^} image ${REGISTRY_IMAGE} present in the local registry" 
            exit
        else
            echo -e "\n${REGISTRY_TYPE^} image ${REGISTRY_IMAGE} with tag ${REGISTRY_TAG} not present in the local registry" >&2
            exit
        fi
        ;;

    ${REGISTRY_OPERATION_TAG})
        
        # Check for the local image
        aws --region "${REGISTRY_PROVIDER_REGION}" s3 ls "${FULL_REGISTRY_IMAGE}" >/dev/null 2>&1
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo -e "\nCan't find ${REGISTRY_IMAGE} in ${REGISTRY_PROVIDER_DNS}" >&2
            exit
        else
            # Copy to S3
            aws --region "${REGISTRY_PROVIDER_REGION}" s3 cp "${TAG_FILE}" "${FULL_TAGGED_REGISTRY_IMAGE}" >/dev/null
            RESULT=$?
            if [[ "$?" -ne 0 ]]; then
                echo -e "\nCouldn't tag image ${FULL_REGISTRY_IMAGE} with tag ${REGISTRY_TSAG}" >&2
                exit
            fi
        fi
        ;;        

    ${REGISTRY_OPERATION_PULL})
        # Formulate the remote registry details
        REMOTE_REGISTRY_IMAGE="${REGISTRY_TYPE}/${REMOTE_REGISTRY_REPO}/${BASE_REGISTRY_FILENAME}"
        REMOTE_TAGGED_REGISTRY_IMAGE="${REGISTRY_TYPE}/${REMOTE_REGISTRY_REPO}/tags/${REMOTE_REGISTRY_TAG}"
        FULL_REMOTE_REGISTRY_IMAGE="s3://${REMOTE_REGISTRY_PROVIDER_DNS}/${REMOTE_REGISTRY_IMAGE}"
        FULL_REMOTE_TAGGED_REGISTRY_IMAGE="s3://${REMOTE_REGISTRY_PROVIDER_DNS}/${REMOTE_TAGGED_REGISTRY_IMAGE}"
        IMAGE_FILE="./temp_${REGISTRY_FILENAME}"

        # Get access to the remote registry
        setCredentials "${REMOTE_REGISTRY_PROVIDER}"

        # Confirm image is present
        aws --region "${REMOTE_REGISTRY_PROVIDER_REGION}" s3 ls "${FULL_REMOTE_TAGGED_REGISTRY_IMAGE}" >/dev/null 2>&1
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo -e "\nCan't find ${REMOTE_REGISTRY_IMAGE} in ${REMOTE_REGISTRY_PROVIDER_DNS}" >&2
            exit
        else
            # Copy image
            aws --region "${REGISTRY_PROVIDER_REGION}" s3 cp "${FULL_REMOTE_REGISTRY_IMAGE}" "${IMAGE_FILE}" >/dev/null
            RESULT=$?
            if [[ "$RESULT" -ne 0 ]]; then
                echo -e "\nCan't copy remote image ${FULL_REMOTE_REGISTRY_IMAGE}" >&2
                exit
            fi
        fi

        # Now copy to local rgistry
        setCredentials "${REGISTRY_PROVIDER}"

        copyToRegistry "${IMAGE_FILE}"
        ;;        
        
    *)
        echo -e "\n Unknown operation \"${REGISTRY_OPERATION}\"" >&2
        exit
        ;;
esac

# All good
RESULT=0
