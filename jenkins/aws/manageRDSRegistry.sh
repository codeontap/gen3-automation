#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ -z ${AUTOMATION_DEBUG} ]] && rm -rf ./temp_*; exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Defaults
REGISTRY_TAG_DEFAULT="latest"
REGISTRY_TYPE_DEFAULT="rdssnapshot"
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
                        -q REGISTRY_SOURCE_SNAPSHOT
                        -a REGISTRY_PROVIDER
                        -l REGISTRY_REPO
                        -t REGISTRY_TAG
                        -f REGISTRY_PREFIX
                        -z REMOTE_REGISTRY_PROVIDER
                        -i REMOTE_REGISTRY_REPO
                        -r REMOTE_REGISTRY_TAG
                        -d REGISTRY_PRODUCT
                        -u REGISTRY_DEPLOYMENT_UNIT
                        -g REGISTRY_CODE_COMMIT

where

(o) -a REGISTRY_PROVIDER                is the local registry provider
(o) -d REGISTRY_PRODUCT                 is the product to use when defaulting REGISTRY_REPO
(o) -g REGISTRY_CODE_COMMIT             to use when defaulting REGISTRY_REPO
    -h                                  shows this text
(o) -i REMOTE_REGISTRY_REPO             is the repository to pull
(o) -k                                  tag an image in the local registry with the remote details
                                        (REGISTRY_OPERATION=${REGISTRY_OPERATION_TAG})
(o) -l REGISTRY_REPO                    is the local repository
(o) -p                                  pull image from a remote to a local registry
                                        (REGISTRY_OPERATION=${REGISTRY_OPERATION_PULL})
(o) -q REGISTRY_SOURCE_SNAPHOST         is the source RDS snapshot for ${REGISTRY_OPERATION_BUILD} operations         
(o) -r REMOTE_REGISTRY_TAG              is the tag to pull
(o) -s                                  save an image to the local registry
                                        (REGISTRY_OPERATION=${REGISRTY_OPERATION_SAVE})
(o) -t REGISTRY_TAG                     is the local tag
(o) -u REGISTRY_DEPLOYMENT_UNIT         is the deployment unit to use when defaulting REGISTRY_REPO
(o) -v                                  verify image is present in local registry
                                        (REGISTRY_OPERATION=${REGISTRY_OPERATION_VERIFY})
(m) -y REGISTRY_TYPE                    is the registry image type
(o) -z REMOTE_REGISTRY_PROVIDER         is the registry provider to pull from

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

REGISTRY_PROVIDER=${PRODUCT_${REGISTRY_TYPE}_PROVIDER}
REGISTRY_TYPE=${REGISTRY_TYPE_DEFAULT}
REGISTRY_REPO="REGISTRY_PRODUCT/REGISTRY_DEPLOYMENT_UNIT/REGISTRY_CODE_COMMIT" or 
            "REGISTRY_PRODUCT/REGISTRY_CODE_COMMIT" if no REGISTRY_DEPLOYMENT_UNIT defined
REGISTRY_TAG=${REGISTRY_TAG_DEFAULT}
REMOTE_REGISTRY_PROVIDER=${PRODUCT_REMOTE_${REGISTRY_TYPE}_PROVIDER}
REMOTE_REGISTRY_REPO=REGISTRY_REPO
REMOTE_REGISTRY_TAG=REGISTRY_TAG
REGISTRY_OPERATION=${REGISTRY_OPERATION_DEFAULT}
REGISTRY_PRODUCT=${PRODUCT}

NOTES:

EOF
    exit
}

# Parse options
while getopts ":a:b:d:e:f:g:hki:l:p:qr:st:u:vxy:z:" opt; do
    case $opt in
        a)
            REGISTRY_PROVIDER="${OPTARG}"
            ;;
        b)
            REGISTRY_OPERATION="${REGISTRY_OPERATION_BUILD}"
            ;;
        d)
            REGISTRY_PRODUCT="${OPTARG}"
            ;;
        f)
            REGISTRY_PREFIX="${OPTARG}"
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
        q)
            REGISTRY_SOURCE_SNAPSHOT="${OPTARG}"
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
    for DRPA_ATTRIBUTE in "PREFIX" "REGION"; do
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

# Apply local registry defaults
REGISTRY_TYPE="${REGISTRY_TYPE,,:-${REGISTRY_TYPE_DEFAULT}}"
REGISTRY_PROVIDER_VAR="PRODUCT_${REGISTRY_TYPE^^}_PROVIDER"
REGISTRY_PROVIDER="${REGISTRY_PROVIDER:-${!REGISTRY_PROVIDER_VAR}}"
REGISTRY_TAG="${REGISTRY_TAG:-${REGISTRY_TAG_DEFAULT}}"
REGISTRY_OPERATION="${REGISTRY_OPERATION:-${REGISTRY_OPERATION_DEFAULT}}"
REGISTRY_PRODUCT="${REGISTRY_PRODUCT:-${PRODUCT}}"

# Default local repository is based on standard image naming conventions
if [[ (-n "${REGISTRY_PRODUCT}") && 
        (-n "${REGISTRY_CODE_COMMIT}") ]]; then
    if [[ (-n "${REGISTRY_DEPLOYMENT_UNIT}" ) ]]; then
        REGISTRY_REPO="${REGISTRY_REPO:-${REGISTRY_PRODUCT}-${REGISTRY_DEPLOYMENT_UNIT}-${REGISTRY_CODE_COMMIT}}"
    else
        REGISTRY_REPO="${REGISTRY_REPO:-${REGISTRY_PRODUCT}-${REGISTRY_CODE_COMMIT}}"
    fi
fi

REGISTRY_DEPLOYMENT_UNIT_PREFIX="${REGISTRY_REPO%$REGISTRY_CODE_COMMIT}"

# Formulate the local registry details
REGISTRY_IMAGE="${REGISTRY_PROVIDER_PREFIX}-${REGISTRY_TYPE}-${REGISTRY_REPO}"

# Make sure we have a source instance
if [[ "${REGISTRY_OPERATION}" == "${REGISTRY_OPERATION_BUILD}" && -z "${REGISTRY_SOURCE_SNAPSHOT}" ]]; then 
    fatal "Registry source RDS instance was not defined for ${REGISTRY_OPERATION_BUILD} operation" && exit 255
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
REMOTE_REGISTRY_IMAGE="${REMOTE_REGISTRY_PROVIDER_PREFIX}-${REGISTRY_TYPE}-${REGISTRY_REPO}"

# Set up credentials for registry access
setCredentials "${REGISTRY_PROVIDER}"

# Confirm access to the local registry
aws --region "${REGISTRY_PROVIDER_REGION}" rds describe-db-snapshots >/dev/null 2>&1
RESULT=$?
[[ "$RESULT" -ne 0 ]] &&
    fatal "Can't access ${REGISTRY_TYPE} registry at ${REGISTRY_PROVIDER}" && exit

# Perform the required action
case ${REGISTRY_OPERATION} in
    ${REGISTRY_OPERATION_SAVE})

        info "Copying Snapshot from: ${REGISTRY_SOURCE_SNAPSHOT} to: ${REGISTRY_IMAGE}"

        # A build will create a new snapshot we just need to bring it into the registry
        aws --region "${REGISTRY_PROVIDER_REGION}" rds copy-db-snapshot copy-db-snapshot --source-db-snapshot-identifier "${REGISTRY_SOURCE_SNAPSHOT}" --target-db-snapshot-identifier "${REGISTRY_IMAGE}" --no-copy-tags || fatal "image could not be copied for ${REGISTRY_IMAGE}" && exit $?

        info "Waiting for snapshot to become available..."
        sleep 2
        aws --region "${REGISTRY_PROVIDER_REGION}" rds wait db-snapshot-available --db-snapshot-identifier "${REGISTRY_IMAGE}"

        # remove the source snapshot once we have it in the registry - This makes sure a new build will be ok
        aws --region "${REGISTRY_PROVIDER_REGION}" rds delete-db-snapshot --db-snapshot-identifier "${REGISTRY_SOURCE_SNAPSHOT}"  1> /dev/null || return $?
        aws --region "${REGISTRY_PROVIDER_REGION}" rds wait db-snapshot-deleted --db-snapshot-identifier "${REGISTRY_SOURCE_SNAPSHOT}"  || return $?

        ;;

    ${REGISTRY_OPERATION_VERIFY})
        # Check whether the image is already in the local registry
        SNAPSHOT_ARN="$(aws --region "${REGISTRY_PROVIDER_REGION}" rds describe-db-snapshots --query "DBSnapshots[?DBSnapshotIdentifier==\`${REGISTRY_IMAGE}\`].DBSnapshotArn[0]" --output text)"
        info "SNAPSHOT_ARN = ${SNAPSHOT_ARN}"

        if [[ -n "${SNAPSHOT_ARN}" ]]; then
            SNAPSHOT_TAG="$(aws --region "${REGISTRY_PROVIDER_REGION}" rds list-tags-for-resource --resource-name "${SNAPSHOT_ARN}" --query "TagList[?Key==\`RegistryTag\`].Value|[0]" --output text)"  
            if [[ "${SNAPSHOT_TAG}" == "${REGISTRY_TAG}" ]]; then 
                info "${REGISTRY_TYPE^} image ${SNAPSHOT} present in the local registry" 
            fi
        fi

        info "${REGISTRY_TYPE^} image ${REGISTRY_IMAGE} with tag ${REGISTRY_TAG} not present in the local registry"
        ;;

    ${REGISTRY_OPERATION_TAG})
        # Check for the local image
        SNAPSHOT_ARN="$(aws --region "${REGISTRY_PROVIDER_REGION}" rds describe-db-snapshots --query "DBSnapshots[?DBSnapshotIdentifier==\`${REGISTRY_IMAGE}\`].DBSnapshotArn[0]" --output text)"
        if [[ -z "${SNAPSHOT_ARN}" || "${SNAPSHOT_ARN}" == 'null' ]]; then
            fatal "Can't find ${REGISTRY_IMAGE} in ${REGISTRY_PROVIDER}" && exit
        else
            aws --region "${REGISTRY_PROVIDER_REGION}" rds add-tags-to-resource --resource-name "${SNAPSHOT_ARN}" --tags Key=RegistryTag,Value="${REMOTE_REGISTRY_TAG}" \
                || fatal "Couldn't tag image ${REGISTRY_IMAGE} with tag ${REMOTE_REGISTRY_TAG}" && exit
        fi
        ;;        

    ${REGISTRY_OPERATION_PULL})
        # Get access to the remote registry
        setCredentials "${REMOTE_REGISTRY_PROVIDER}"

        # Confirm image is present
        REGISTRY_SNAPSHOT_ARN="$(aws --region "${REGISTRY_PROVIDER_REGION}" rds describe-db-snapshots --db-snapshot-identifier "${REGISTRY_IMAGE}" --query "DBSnapshots[0].DBSnapshotArn" --output text >/dev/null 2>&1)"
        
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            fatal "Can't find ${REGISTRY_IMAGE} in ${REMOTE_REGISTRY_PROVIDER}" && exit
        else
            
            # Now see if its available in the local registry 
            setCredentials "${REGISTRY_PROVIDER}"
            aws --region "${REGISTRY_PROVIDER_REGION}" rds describe-db-snapshots --db-snapshot-identifier "${REGISTRY_IMAGE}" >/dev/null 2>&1
            RESULT=$?
            if [[ "$RESULT" -eq 0 ]]; then
                info "Image ${REGISTRY_IMAGE} already available" 
                exit 
            else
                # share the snapshot from the remote registry to the local registry 
                setCredentials "${REMOTE_REGISTRY_PROVIDER}"

                AWS_ACCOUNT_ID_VAR="${REMOTE_REGISTRY_PROVIDER}_AWS_ACCOUNT_ID"

                aws --region "${REMOTE_REGISTRY_PROVIDER_REGION}" rds modify-db-snapshot-attribute \ 
                    --db-snapshot-identifier "${REMOTE_REGISTRY_IMAGE}"\ 
                    --attribute-name restore \ 
                    --values-to-add "[\"${!AWS_CRED_AWS_ACCOUNT_ID_VAR}\"]" || fatal "Registry image ${REMOTE_REGISTRY_IMAGE} could not be shared with ${AWS_ACCOUNT_ID_VAR}" && exit $?

                # now copy the snapshot to the local registry so we have our own copy 
                setCredentials "${REGISTRY_PROVIDER}"

                # A build will create a new snapshot we just need to bring it into the registry
                LOCAL_REGISTRY_IMAGE_ARN="$(aws --region "${REGISTRY_PROVIDER_REGION}" rds copy-db-snapshot --source-db-snapshot-identifier "${REGISTRY_SNAPSHOT_ARN}" --target-db-snapshot-identifier "${REGISTRY_IMAGE}" --copy-tags || fatal "image could not be copied for ${REGISTRY_SNAPSHOT_ARN}" && exit $?)"
            
                info "Waiting for snapshot to become available..."
                sleep 2
                aws --region "${REMOTE_REGISTRY_PROVIDER_REGION}" rds wait db-snapshot-available --db-snapshot-identifier "${LOCAL_REGISTRY_IMAGE_ARN}"

                info "Registry image ${REGISTRY_IMAGE} should now be available"
            fi
        fi
        ;;        
        
    *)
        fatal "Unknown operation \"${REGISTRY_OPERATION}\"" && exit
        ;;
esac

# All good
RESULT=0
