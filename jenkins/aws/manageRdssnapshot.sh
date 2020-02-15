#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ -z ${AUTOMATION_DEBUG} ]] && rm -rf ./temp_*; exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Defaults
SNAPSHOT_TAG_DEFAULT="latest"
SNAPSHOT_TYPE_DEFAULT="rdssnapshot"
SNAPSHOT_OPERATION_SAVE="save"
SNAPSHOT_OPERATION_VERIFY="verify"
SNAPSHOT_OPERATION_TAG="tag"
SNAPSHOT_OPERATION_PULL="pull"
SNAPSHOT_OPERATION_DEFAULT="${SNAPSHOT_OPERATION_VERIFY}"
SNAPSHOT_EXPAND_DEFAULT="false"
SNAPSHOT_REMOVE_SOURCE_DEFAULT="false"

function usage() {
    cat <<EOF

Manage images in an S3 backed registry

Usage: $(basename $0) -s -v -p -k -x
                        -y SNAPSHOT_TYPE
                        -q SNAPSHOT_SOURCE
                        -a SNAPSHOT_PROVIDER
                        -c REGISTRY_SCOPE
                        -l SNAPSHOT_REPO
                        -t SNAPSHOT_TAG
                        -z REMOTE_SNAPSHOT_PROVIDER
                        -i REMOTE_SNAPSHOT_REPO
                        -r REMOTE_SNAPSHOT_TAG
                        -d SNAPSHOT_PRODUCT
                        -u SNAPSHOT_DEPLOYMENT_UNIT
                        -g SNAPSHOT_CODE_COMMIT

where

(o) -a SNAPSHOT_PROVIDER                is the local registry provider
(o) -c REGISTRY_SCOPE                   is the registry scope
(o) -d SNAPSHOT_PRODUCT                 is the product to use when defaulting SNAPSHOT_REPO
(o) -g SNAPSHOT_CODE_COMMIT             to use when defaulting SNAPSHOT_REPO
    -h                                  shows this text
(o) -i REMOTE_SNAPSHOT_REPO             is the repository to pull
(o) -k                                  tag an image in the local registry with the remote details
                                        (SNAPSHOT_OPERATION=${SNAPSHOT_OPERATION_TAG})
(o) -l SNAPSHOT_REPO                    is the local repository
(o) -p                                  pull image from a remote to a local registry
                                        (SNAPSHOT_OPERATION=${SNAPSHOT_OPERATION_PULL})
(o) -q SNAPSHOT_SOURCE_SNAPHOST         is the source RDS snapshot for ${SNAPSHOT_OPERATION_BUILD} operations
(o) -r REMOTE_SNAPSHOT_TAG              is the tag to pull
(o) -s                                  save an image to the local registry
                                        (SNAPSHOT_OPERATION=${REGISRTY_OPERATION_SAVE})
(o) -t SNAPSHOT_TAG                     is the local tag
(o) -u SNAPSHOT_DEPLOYMENT_UNIT         is the deployment unit to use when defaulting SNAPSHOT_REPO
(o) -v                                  verify image is present in local registry
                                        (SNAPSHOT_OPERATION=${SNAPSHOT_OPERATION_VERIFY})
(m) -y SNAPSHOT_TYPE                    is the registry image type
(o) -z REMOTE_SNAPSHOT_PROVIDER         is the registry provider to pull from

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

SNAPSHOT_PROVIDER=${PRODUCT_${SNAPSHOT_TYPE}_PROVIDER}
SNAPSHOT_TYPE=${SNAPSHOT_TYPE_DEFAULT}
SNAPSHOT_REPO="SNAPSHOT_PRODUCT/SNAPSHOT_DEPLOYMENT_UNIT/SNAPSHOT_CODE_COMMIT" or
            "SNAPSHOT_PRODUCT/SNAPSHOT_CODE_COMMIT" if no SNAPSHOT_DEPLOYMENT_UNIT defined
SNAPSHOT_TAG=${SNAPSHOT_TAG_DEFAULT}
REMOTE_SNAPSHOT_PROVIDER=${PRODUCT_REMOTE_${SNAPSHOT_TYPE}_PROVIDER}
REMOTE_SNAPSHOT_REPO=SNAPSHOT_REPO
REMOTE_SNAPSHOT_TAG=SNAPSHOT_TAG
SNAPSHOT_OPERATION=${SNAPSHOT_OPERATION_DEFAULT}
SNAPSHOT_PRODUCT=${PRODUCT}

NOTES:

EOF
    exit
}

# Parse options
while getopts ":a:c:d:g:hki:l:pqr:st:u:vxy:z:" opt; do
    case $opt in
        a)
            SNAPSHOT_PROVIDER="${OPTARG}"
            ;;
        c)
            REGISTRY_SCOPE="${OPTARG}"
            ;;
        d)
            SNAPSHOT_PRODUCT="${OPTARG}"
            ;;
        g)
            SNAPSHOT_CODE_COMMIT="${OPTARG}"
            ;;
        h)
            usage
            ;;
        i)
            REMOTE_SNAPSHOT_REPO="${OPTARG}"
            ;;
        k)
            SNAPSHOT_OPERATION="${SNAPSHOT_OPERATION_TAG}"
            ;;
        l)
            SNAPSHOT_REPO="${OPTARG}"
            ;;
        p)
            SNAPSHOT_OPERATION="${SNAPSHOT_OPERATION_PULL}"
            ;;
        q)
            SNAPSHOT_SOURCE="${OPTARG}"
            ;;
        r)
            REMOTE_SNAPSHOT_TAG="${OPTARG}"
            ;;
        s)
            SNAPSHOT_OPERATION="${SNAPSHOT_OPERATION_SAVE}"
            ;;
        t)
            SNAPSHOT_TAG="${OPTARG}"
            ;;
        u)
            SNAPSHOT_DEPLOYMENT_UNIT="${OPTARG}"
            ;;
        v)
            SNAPSHOT_OPERATION="${SNAPSHOT_OPERATION_VERIFY}"
            ;;
        y)
            SNAPSHOT_TYPE="${OPTARG,,}"
            ;;
        z)
            REMOTE_SNAPSHOT_PROVIDER="${OPTARG}"
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
SNAPSHOT_TYPE="${SNAPSHOT_TYPE:-${SNAPSHOT_TYPE_DEFAULT}}"
SNAPSHOT_PROVIDER_VAR="PRODUCT_${SNAPSHOT_TYPE^^}_PROVIDER"
SNAPSHOT_PROVIDER="${SNAPSHOT_PROVIDER:-${!SNAPSHOT_PROVIDER_VAR}}"
SNAPSHOT_TAG="${SNAPSHOT_TAG:-${SNAPSHOT_TAG_DEFAULT}}"
SNAPSHOT_OPERATION="${SNAPSHOT_OPERATION:-${SNAPSHOT_OPERATION_DEFAULT}}"
SNAPSHOT_PRODUCT="${SNAPSHOT_PRODUCT:-${PRODUCT}}"

# Handle registry scope values
case "${REGISTRY_SCOPE}" in
    segment)
        if [[ -n "${SEGMENT}" ]]; then
            REGISTRY_SUBTYPE="-${SEGMENT}"
        else
          fatal "Segment scoped registry required but SEGMENT not defined" && exit
        fi
        ;;
    *)
        REGISTRY_SUBTYPE=""
        ;;
esac


# Default local repository is based on standard image naming conventions
if [[ (-n "${SNAPSHOT_PRODUCT}") &&
        (-n "${SNAPSHOT_CODE_COMMIT}") ]]; then
    if [[ (-n "${SNAPSHOT_DEPLOYMENT_UNIT}" ) ]]; then
        SNAPSHOT_REPO="${SNAPSHOT_REPO:-${SNAPSHOT_PRODUCT}${REGISTRY_SCOPE}-${SNAPSHOT_DEPLOYMENT_UNIT}-${SNAPSHOT_CODE_COMMIT}}"
    else
        SNAPSHOT_REPO="${SNAPSHOT_REPO:-${SNAPSHOT_PRODUCT}${REGISTRY_SCOPE}-${SNAPSHOT_CODE_COMMIT}}"
    fi
fi

# Make sure we have a source instance
if [[ "${SNAPSHOT_OPERATION}" == "${SNAPSHOT_OPERATION_SAVE}" && -z "${SNAPSHOT_SOURCE}" ]]; then
    fatal "Registry source RDS instance was not defined for ${SNAPSHOT_OPERATION_BUILD} operation"
    exit 255
fi

# Determine registry provider details
defineRegistryProviderAttributes "${SNAPSHOT_PROVIDER}" "${SNAPSHOT_TYPE}" "SNAPSHOT_PROVIDER"

# Formulate the local registry details
SNAPSHOT_IMAGE="${SNAPSHOT_PROVIDER_PREFIX}-${SNAPSHOT_TYPE}-${SNAPSHOT_REPO}"

# Ensure the local repository has been determined
if [[ -z "${SNAPSHOT_REPO}" ]]; then
    fatal "Job requires the local repository name, or the product/deployment unit/commit"
    exit 255
fi

# Apply remote registry defaults
REMOTE_SNAPSHOT_PROVIDER_VAR="PRODUCT_REMOTE_${SNAPSHOT_TYPE^^}_PROVIDER"
REMOTE_SNAPSHOT_PROVIDER="${REMOTE_SNAPSHOT_PROVIDER:-${!REMOTE_SNAPSHOT_PROVIDER_VAR}}"
REMOTE_SNAPSHOT_REPO="${REMOTE_SNAPSHOT_REPO:-$SNAPSHOT_REPO}"
REMOTE_SNAPSHOT_TAG="${REMOTE_SNAPSHOT_TAG:-$SNAPSHOT_TAG}"

# Determine remote registry provider details
defineRegistryProviderAttributes "${REMOTE_SNAPSHOT_PROVIDER}" "${SNAPSHOT_TYPE}" "REMOTE_SNAPSHOT_PROVIDER"

# pull = tag if local provider = remote provider
if [[ ("${SNAPSHOT_PROVIDER}" == "${REMOTE_SNAPSHOT_PROVIDER}") &&
        ("${SNAPSHOT_OPERATION}" == "${SNAPSHOT_OPERATION_PULL}") ]]; then
    SNAPSHOT_OPERATION="${SNAPSHOT_OPERATION_TAG}"
fi

# Formulate the local registry details
REMOTE_SNAPSHOT_IMAGE="${REMOTE_SNAPSHOT_PROVIDER_PREFIX}-${SNAPSHOT_TYPE}-${SNAPSHOT_REPO}"

# Set up credentials for registry access
setCredentials "${SNAPSHOT_PROVIDER}"
SNAPSHOT_PROVIDER_AWS_ACCOUNT_ID_VAR="${SNAPSHOT_PROVIDER^^}_AWS_ACCOUNT_ID"

# Confirm access to the local registry
aws --region "${SNAPSHOT_PROVIDER_REGION}" rds describe-db-snapshots >/dev/null 2>&1
RESULT=$?
[[ "$RESULT" -ne 0 ]] &&
    fatal "Can't access ${SNAPSHOT_TYPE} registry at ${SNAPSHOT_PROVIDER}" && exit

# Perform the required action
case ${SNAPSHOT_OPERATION} in
    ${SNAPSHOT_OPERATION_SAVE})

        info "Copying Snapshot from: ${SNAPSHOT_SOURCE} to: ${SNAPSHOT_IMAGE}"

        # A build will create a new snapshot we just need to bring it into the registry
        aws --region "${SNAPSHOT_PROVIDER_REGION}" rds copy-db-snapshot --source-db-snapshot-identifier "${SNAPSHOT_SOURCE}" --target-db-snapshot-identifier "${SNAPSHOT_IMAGE}" --no-copy-tags --tags Key=RegistrySnapshot,Value="true" || exit $?

        info "Waiting for snapshot to become available..."
        sleep 2
        aws --region "${SNAPSHOT_PROVIDER_REGION}" rds wait db-snapshot-completed --db-snapshot-identifier "${SNAPSHOT_IMAGE}"

        # remove the source snapshot once we have it in the registry - This makes sure a new build will be ok
        info "Deleting Snapshot ${SNAPSHOT_SOURCE}"
        aws --region "${SNAPSHOT_PROVIDER_REGION}" rds delete-db-snapshot --db-snapshot-identifier "${SNAPSHOT_SOURCE}" ||  exit $?
        info "Waiting for snapshot to delete"
        sleep 2
        aws --region "${SNAPSHOT_PROVIDER_REGION}" rds wait db-snapshot-deleted --db-snapshot-identifier "${SNAPSHOT_SOURCE}"

        ;;

    ${SNAPSHOT_OPERATION_VERIFY})
        # Check whether the image is already in the local registry
        SNAPSHOT_ARN="$(aws --region "${SNAPSHOT_PROVIDER_REGION}" rds describe-db-snapshots --db-snapshot-identifier "${SNAPSHOT_IMAGE}" --query "DBSnapshots[0].DBSnapshotArn" --output text)"
        if [[ -n "${SNAPSHOT_ARN}" ]]; then
            SNAPSHOT_TAG="$(aws --region "${SNAPSHOT_PROVIDER_REGION}" rds list-tags-for-resource --resource-name "${SNAPSHOT_ARN}" --query "TagList[?Key==\`RegistryTag\`].Value|[0]" --output text)"
            if [[ "${SNAPSHOT_TAG}" == "${SNAPSHOT_TAG}" ]]; then
                info "${SNAPSHOT_TYPE^} image ${SNAPSHOT} present in the local registry"
                RESULT=0
                exit
            fi
        fi

        info "${SNAPSHOT_TYPE^} image ${SNAPSHOT_IMAGE} with tag ${SNAPSHOT_TAG} not present in the local registry"
        RESULT=1
        exit
        ;;

    ${SNAPSHOT_OPERATION_TAG})
        # Check for the local image
        SNAPSHOT_ARN="$(aws --region "${SNAPSHOT_PROVIDER_REGION}" rds describe-db-snapshots --db-snapshot-identifier "${SNAPSHOT_IMAGE}" --query "DBSnapshots[0].DBSnapshotArn" --output text)"
        if [[ -z "${SNAPSHOT_ARN}" || "${SNAPSHOT_ARN}" == 'null' ]]; then
            fatal "Can't find ${SNAPSHOT_IMAGE} in ${SNAPSHOT_PROVIDER}"
            exit
        else
            aws --region "${SNAPSHOT_PROVIDER_REGION}" rds add-tags-to-resource --resource-name "${SNAPSHOT_ARN}" --tags Key=RegistryTag,Value="${REMOTE_SNAPSHOT_TAG}"
            RESULT=$?
            if [[ "${RESULT}" -ne 0 ]]; then
             fatal "Couldn't tag image ${SNAPSHOT_IMAGE} with tag ${REMOTE_SNAPSHOT_TAG}"
             exit $RESULT
            fi
        fi
        ;;

    ${SNAPSHOT_OPERATION_PULL})
        # Get access to the remote registry
        setCredentials "${REMOTE_SNAPSHOT_PROVIDER}"

        # Confirm image is present
        SNAPSHOT_SNAPSHOT_ARN="$(aws --region "${SNAPSHOT_PROVIDER_REGION}" rds describe-db-snapshots --db-snapshot-identifier "${SNAPSHOT_IMAGE}" --query "DBSnapshots[0].DBSnapshotArn" --output text )"
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            fatal "Can't find ${SNAPSHOT_IMAGE} in ${REMOTE_SNAPSHOT_PROVIDER}"
            exit 255
        else

            # Now see if its available in the local registry
            setCredentials "${SNAPSHOT_PROVIDER}"
            aws --region "${SNAPSHOT_PROVIDER_REGION}" rds describe-db-snapshots --db-snapshot-identifier "${SNAPSHOT_IMAGE}" >/dev/null 2>&1
            RESULT=$?
            if [[ "$RESULT" -eq 0 ]]; then
                info "Image ${SNAPSHOT_IMAGE} already available"
                exit 0
            else
                # share the snapshot from the remote registry to the local registry
                setCredentials "${REMOTE_SNAPSHOT_PROVIDER}"
                aws --region "${REMOTE_SNAPSHOT_PROVIDER_REGION}" rds modify-db-snapshot-attribute --db-snapshot-identifier "${REMOTE_SNAPSHOT_IMAGE}" --attribute-name restore --values-to-add "${!SNAPSHOT_PROVIDER_AWS_ACCOUNT_ID_VAR}" >/dev/null 2>&1

                RESULT=$?
                if [[ "${RESULT}" -ne 0 ]]; then
                    fatal "Could not share image ${REMOTE_SNAPSHOT_IMAGE} with account ${AWS_CRED_AWS_ACCOUNT_ID_VAR}"
                    exit $RESULT
                fi

                # now copy the snapshot to the local registry so we have our own copy
                setCredentials "${SNAPSHOT_PROVIDER}"

                # A build will create a new snapshot we just need to bring it into the registry
                LOCAL_SNAPSHOT_IMAGE_ARN="$(aws --region "${SNAPSHOT_PROVIDER_REGION}" rds copy-db-snapshot --source-db-snapshot-identifier "${SNAPSHOT_SNAPSHOT_ARN}" --target-db-snapshot-identifier "${SNAPSHOT_IMAGE}" --query 'DBSnapshot.DBSnapshotArn' --tags Key=RegistrySnapshot,Value="true" --no-copy-tags --output text || exit $?)"

                if [[ -n "${LOCAL_SNAPSHOT_IMAGE_ARN}" ]]; then
                    info "Waiting for snapshot to become available..."
                    sleep 2
                    aws --region "${REMOTE_SNAPSHOT_PROVIDER_REGION}" rds wait db-snapshot-completed --db-snapshot-identifier "${LOCAL_SNAPSHOT_IMAGE_ARN}" || exit $?
                    info "Registry image ${SNAPSHOT_IMAGE} should now be available"
                else
                    fatal "Registry image ${SNAPSHOT_IMAGE} could not be copied"
                    exit 255
                fi
            fi
        fi
        ;;

    *)
        fatal "Unknown operation \"${SNAPSHOT_OPERATION}\"" && exit
        ;;
esac

# All good
RESULT=0
