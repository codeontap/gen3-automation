#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Defaults
DOCKER_TAG_DEFAULT="latest"
DOCKER_IMAGE_SOURCE_REMOTE="remote"
DOCKER_IMAGE_SOURCE_DEFAULT="${DOCKER_IMAGE_SOURCE_REMOTE}"
DOCKER_OPERATION_BUILD="build"
DOCKER_OPERATION_VERIFY="verify"
DOCKER_OPERATION_TAG="tag"
DOCKER_OPERATION_PULL="pull"
DOCKER_OPERATION_DEFAULT="${DOCKER_OPERATION_VERIFY}"

function usage() {
    cat <<EOF

Manage docker images

Usage: $(basename $0) -b -v -p -k -a DOCKER_PROVIDER -l DOCKER_REPO -t DOCKER_TAG -z REMOTE_DOCKER_PROVIDER -i REMOTE_DOCKER_REPO -r REMOTE_DOCKER_TAG -u DOCKER_IMAGE_SOURCE  -d DOCKER_PRODUCT -s DOCKER_DEPLOYMENT_UNIT -g DOCKER_CODE_COMMIT

where

(o) -a DOCKER_PROVIDER          is the local docker provider
(o) -b                          perform docker build and save in local registry
(o) -d DOCKER_PRODUCT           is the product to use when defaulting DOCKER_REPO
(o) -g DOCKER_CODE_COMMIT       to use when defaulting DOCKER_REPO
    -h                          shows this text
(o) -i REMOTE_DOCKER_REPO       is the repository to pull
(o) -k                          tag an image in the local registry with the remote details
(o) -l DOCKER_REPO              is the local repository
(o) -p                          pull image from a remote to a local registry
(o) -r REMOTE_DOCKER_TAG        is the tag to pull
(o) -s DOCKER_DEPLOYMENT_UNIT   is the deployment unit to use when defaulting DOCKER_REPO
(o) -t DOCKER_TAG               is the local tag
(o) -u DOCKER_IMAGE_SOURCE      is the registry to pull from
(o) -v                          verify image is present in local registry
(o) -z REMOTE_DOCKER_PROVIDER   is the docker provider to pull from

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

DOCKER_PROVIDER=${PRODUCT_DOCKER_PROVIDER}
DOCKER_REPO="DOCKER_PRODUCT/DOCKER_DEPLOYMENT_UNIT-DOCKER_CODE_COMMIT" or 
            "DOCKER_PRODUCT/DOCKER_CODE_COMMIT" if no DOCKER_DEPLOYMENT_UNIT defined
DOCKER_TAG=${DOCKER_TAG_DEFAULT}
REMOTE_DOCKER_PROVIDER=${PRODUCT_REMOTE_DOCKER_PROVIDER}
REMOTE_DOCKER_REPO=DOCKER_REPO
REMOTE_DOCKER_TAG=DOCKER_TAG
DOCKER_IMAGE_SOURCE=${DOCKER_IMAGE_SOURCE_DEFAULT}
DOCKER_OPERATION=${DOCKER_OPERATION_DEFAULT}
DOCKER_PRODUCT=${PRODUCT}

NOTES:

1. DOCKER_IMAGE_SOURCE can be "remote" or "dockerhub"

EOF
    exit
}

# Parse options
while getopts ":a:bd:g:hki:l:pr:s:t:u:vz:" opt; do
    case $opt in
        a)
            DOCKER_PROVIDER="${OPTARG}"
            ;;
        b)
            DOCKER_OPERATION="${DOCKER_OPERATION_BUILD}"
            ;;
        d)
            DOCKER_PRODUCT="${OPTARG}"
            ;;
        g)
            DOCKER_CODE_COMMIT="${OPTARG}"
            ;;
        h)
            usage
            ;;
        i)
            REMOTE_DOCKER_REPO="${OPTARG}"
            ;;
        k)
            DOCKER_OPERATION="${DOCKER_OPERATION_TAG}"
            ;;
        l)
            DOCKER_REPO="${OPTARG}"
            ;;
        p)
            DOCKER_OPERATION="${DOCKER_OPERATION_PULL}"
            ;;
        r)
            REMOTE_DOCKER_TAG="${OPTARG}"
            ;;
        s)
            DOCKER_DEPLOYMENT_UNIT="${OPTARG}"
            ;;
        t)
            DOCKER_TAG="${OPTARG}"
            ;;
        u)
            DOCKER_IMAGE_SOURCE="${OPTARG}"
            ;;
        v)
            DOCKER_OPERATION="${DOCKER_OPERATION_VERIFY}"
            ;;
        z)
            REMOTE_DOCKER_PROVIDER="${OPTARG}"
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

# Determine if a docker registry is hosted by AWS
# $1 = registry
# $2 = provider
PROVIDER_REGISTRY_IDS=()
PROVIDER_AWS_ACCESS_KEY_IDS=()
PROVIDER_AWS_SECRET_ACCESS_KEYS=()
PROVIDER_AWS_SESSION_TOKENS=()

function isAWSRegistry() {
    if [[ "${1}" =~ ".amazonaws.com" ]]; then

        # Determine the registry account id and region
        AWS_REGISTRY_ID=$(cut -d '.' -f 1 <<< "${1}")
        AWS_REGISTRY_REGION=$(cut -d '.' -f 4 <<< "${1}")
        
        for INDEX in $(seq 0 $((${#PROVIDER_REGISTRY_IDS[@]}-1 )) ); do
            if [[ "${PROVIDER_REGISTRY_IDS[$INDEX]}" == "${AWS_REGISTRY_ID}" ]]; then
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

        if [[ -z "$2" ]]; then
            return 0
        fi

        # New registry - set up the AWS credentials
        . ${AUTOMATION_DIR}/setCredentials.sh ${2^^}

        # Define the credentials
        export AWS_ACCESS_KEY_ID="${AWS_CRED_TEMP_AWS_ACCESS_KEY_ID:-${!AWS_CRED_AWS_ACCESS_KEY_ID_VAR}}"
        export AWS_SECRET_ACCESS_KEY="${AWS_CRED_TEMP_AWS_SECRET_ACCESS_KEY:-${!AWS_CRED_AWS_SECRET_ACCESS_KEY_VAR}}"
        export AWS_SESSION_TOKEN="${AWS_CRED_TEMP_AWS_SESSION_TOKEN}"
        if [[ -z "${AWS_SESSION_TOKEN}" ]]; then
            unset AWS_SESSION_TOKEN
        fi

        # Cache the redentials
        PROVIDER_REGISTRY_IDS+=("${AWS_REGISTRY_ID}")
        PROVIDER_AWS_ACCESS_KEY_IDS+=("${AWS_ACCESS_KEY_ID}")
        PROVIDER_AWS_SECRET_ACCESS_KEYS+=("${AWS_SECRET_ACCESS_KEY}")
        PROVIDER_AWS_SESSION_TOKENS+=("${AWS_SESSION_TOKEN}")
        return 0
    else
        return 1
    fi
}

# Perform login logic required depending on the registry implementation
# $1 = registry
# $2 = provider
# $3 = user
# $4 = password
function dockerLogin() {
    isAWSRegistry $1 $2
    if [[ $? -eq 0 ]]; then
        $(aws --region ${AWS_REGISTRY_REGION} ecr get-login --registry-ids ${AWS_REGISTRY_ID})
    else
        docker login -u ${3} -p ${4} ${1}
    fi
    return $?
}

# Perform logic required to create a repository depending on the registry implementation
# $1 = registry
# $2 = repository
function createRepository() {
    isAWSRegistry $1
    if [[ $? -eq 0 ]]; then
        aws --region ${AWS_REGISTRY_REGION} ecr describe-repositories --registry-id ${AWS_REGISTRY_ID} --repository-names "${2}" > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            # Not there yet so create it
            aws --region ${AWS_REGISTRY_REGION} ecr create-repository --repository-name "${2}"
            return $?
        fi
    fi
    return 0
}

# Define docker provider attributes
# $1 = provider
# $2 = variable prefix
function defineDockerProviderAttributes() {
    DDPA_PROVIDER="${1^^}"
    DDPA_PREFIX="${2^^}"

    # Attribute variable names
    for DDPA_ATTRIBUTE in "DNS" "API_DNS" "USER_VAR" "PASSWORD_VAR"; do
        DDPA_PROVIDER_VAR="${DDPA_PROVIDER}_DOCKER_${DDPA_ATTRIBUTE}"
        declare -g ${DDPA_PREFIX}_${DDPA_ATTRIBUTE}="${!DDPA_PROVIDER_VAR}"
    done
}

# Apply local registry defaults
DOCKER_PROVIDER="${DOCKER_PROVIDER:-${PRODUCT_DOCKER_PROVIDER}}"
DOCKER_TAG="${DOCKER_TAG:-${DOCKER_TAG_DEFAULT}}"
DOCKER_IMAGE_SOURCE="${DOCKER_IMAGE_SOURCE:-${DOCKER_IMAGE_SOURCE_DEFAULT}}"
DOCKER_OPERATION="${DOCKER_OPERATION:-${DOCKER_OPERATION_DEFAULT}}"
DOCKER_PRODUCT="${DOCKER_PRODUCT:-${PRODUCT}}"

# Default local repository is based on standard image naming conventions
if [[ (-n "${DOCKER_PRODUCT}") && 
        (-n "${DOCKER_CODE_COMMIT}") ]]; then
    if [[ (-n "${DOCKER_DEPLOYMENT_UNIT}" ) ]]; then
        DOCKER_REPO="${DOCKER_REPO:-${DOCKER_PRODUCT}/${DOCKER_DEPLOYMENT_UNIT}-${DOCKER_CODE_COMMIT}}"
    else
        DOCKER_REPO="${DOCKER_REPO:-${DOCKER_PRODUCT}/${DOCKER_CODE_COMMIT}}"
    fi
fi

# Determine docker provider details
defineDockerProviderAttributes "${DOCKER_PROVIDER}" "DOCKER_PROVIDER"

# Ensure the local repository has been determined
if [[ -z "${DOCKER_REPO}" ]]; then
    echo -e "\nJob requires the local repository name, or the product/deployment unit/commit" >&2
    exit
fi

# Apply remote registry defaults
REMOTE_DOCKER_PROVIDER="${REMOTE_DOCKER_PROVIDER:-${PRODUCT_REMOTE_DOCKER_PROVIDER}}"
REMOTE_DOCKER_REPO="${REMOTE_DOCKER_REPO:-$DOCKER_REPO}"
REMOTE_DOCKER_TAG="${REMOTE_DOCKER_TAG:-$DOCKER_TAG}"

# Determine remote docker provider details
defineDockerProviderAttributes "${REMOTE_DOCKER_PROVIDER}" "REMOTE_DOCKER_PROVIDER"

# pull = tag if local provider = remote provider
if [[ ("${DOCKER_PROVIDER}" == "${REMOTE_DOCKER_PROVIDER}") &&
        ("${DOCKER_OPERATION}" == "${${DOCKER_OPERATION_PULL}}") ]]; then
    DOCKER_OPERATION="${DOCKER_OPERATION_TAG}"
fi


# Formulate the local registry details
DOCKER_IMAGE="${DOCKER_REPO}:${DOCKER_TAG}"
FULL_DOCKER_IMAGE="${DOCKER_PROVIDER_DNS}/${DOCKER_IMAGE}"

# Confirm access to the local registry
dockerLogin ${DOCKER_PROVIDER_DNS} ${DOCKER_PROVIDER} ${!DOCKER_PROVIDER_USER_VAR} ${!DOCKER_PROVIDER_PASSWORD_VAR}
RESULT=$?
if [[ "$RESULT" -ne 0 ]]; then
    echo -e "\nCan't log in to ${DOCKER_PROVIDER_DNS}" >&2
    exit
fi

# Perform the required action
case ${DOCKER_OPERATION} in
    ${DOCKER_OPERATION_BUILD})
        # Locate the Dockerfile
        DOCKERFILE="./Dockerfile"
        if [[ -f "${AUTOMATION_BUILD_DEVOPS_DIR}/docker/Dockerfile" ]]; then
            DOCKERFILE="${AUTOMATION_BUILD_DEVOPS_DIR}/docker/Dockerfile"
        fi
        docker build \
            -t "${FULL_DOCKER_IMAGE}" \
            -f "${DOCKERFILE}" \
            "${AUTOMATION_BUILD_DIR}"
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
            echo -e "\nCannot build image ${DOCKER_IMAGE}" >&2
            exit
        fi
        createRepository ${DOCKER_PROVIDER_DNS} ${DOCKER_REPO}
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
            echo -e "\nUnable to create repository ${DOCKER_REPO} in the local registry" >&2
        fi
        docker push ${FULL_DOCKER_IMAGE}
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
            echo -e "\nUnable to push ${DOCKER_IMAGE} to the local registry" >&2
        fi
        ;;

    ${DOCKER_OPERATION_VERIFY})
        # Check whether the image is already in the local registry
        # Use the docker API to avoid having to download the image to verify its existence
        isAWSRegistry ${DOCKER_PROVIDER_DNS}
        if [[ $? -eq 0 ]]; then
            DOCKER_IMAGE_PRESENT=$(aws --region ${AWS_REGISTRY_REGION} ecr list-images --registry-id ${AWS_REGISTRY_ID} --repository-name "${DOCKER_REPO}" | jq ".imageIds[] | select(.imageTag==\"${DOCKER_TAG}\") | select(.!=null)")
        else
            # Be careful of @ characters in the username or password
            DOCKER_USER=$(sed "s/@/%40/g" <<< "${!DOCKER_PROVIDER_USER_VAR}")
            DOCKER_PASSWORD=$(sed "s/@/%40/g" <<< "${!DOCKER_PROVIDER_PASSWORD_VAR}")
            DOCKER_IMAGE_PRESENT=$(curl -s https://${DOCKER_USER}:${DOCKER_PASSWORD}@${DOCKER_PROVIDER_API_DNS}/v1/repositories/${DOCKER_REPO}/tags | jq ".[\"${DOCKER_TAG}\"] | select(.!=null)")
        fi

        if [[ -n "${DOCKER_IMAGE_PRESENT}" ]]; then
            echo -e "\nDocker image ${DOCKER_IMAGE} present in the local registry"
            RESULT=0
        else
            echo -e "\nDocker image ${DOCKER_IMAGE} not present in the local registry" >&2
            RESULT=1
        fi
        ;;

    ${DOCKER_OPERATION_TAG})
        # Formulate the tag details
        REMOTE_DOCKER_IMAGE="${REMOTE_DOCKER_REPO}:${REMOTE_DOCKER_TAG}"
        FULL_REMOTE_DOCKER_IMAGE="${DOCKER_PROVIDER_DNS}/${REMOTE_DOCKER_IMAGE}"

        # Pull in the local image
        docker pull ${FULL_DOCKER_IMAGE}
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo -e "\nCan't pull ${DOCKER_IMAGE} from ${DOCKER_PROVIDER_DNS}" >&2
        else
            # Tag the image ready to push to the registry
            docker tag ${FULL_DOCKER_IMAGE} ${FULL_REMOTE_DOCKER_IMAGE}
            RESULT=$?
            if [[ "$?" -ne 0 ]]; then
                echo -e "\nCouldn't tag image ${FULL_DOCKER_IMAGE} with ${FULL_REMOTE_DOCKER_IMAGE}" >&2
            else
                # Push to registry
                createRepository ${DOCKER_PROVIDER_DNS} ${REMOTE_DOCKER_REPO}
                RESULT=$?
                if [ $RESULT -ne 0 ]; then
                    echo -e "\nUnable to create repository ${REMOTE_DOCKER_REPO} in the local registry" >&2
                fi

                docker push ${FULL_REMOTE_DOCKER_IMAGE}
                RESULT=$?
                if [[ "$?" -ne 0 ]]; then
                    echo -e "\nUnable to push ${REMOTE_DOCKER_IMAGE} to the local registry" >&2
                fi
            fi
        fi
        ;;        

    ${DOCKER_OPERATION_PULL})
        # Formulate the remote registry details
        REMOTE_DOCKER_IMAGE="${REMOTE_DOCKER_REPO}:${REMOTE_DOCKER_TAG}"

        case ${DOCKER_IMAGE_SOURCE} in
            ${DOCKER_IMAGE_SOURCE_REMOTE})
                FULL_REMOTE_DOCKER_IMAGE="${REMOTE_DOCKER_PROVIDER_DNS}/${REMOTE_DOCKER_IMAGE}"

                # Confirm access to the remote registry
                dockerLogin ${REMOTE_DOCKER_PROVIDER_DNS} ${REMOTE_DOCKER_PROVIDER} ${!REMOTE_DOCKER_PROVIDER_USER_VAR} ${!REMOTE_DOCKER_PROVIDER_PASSWORD_VAR}
                RESULT=$?
                if [[ "$RESULT" -ne 0 ]]; then
                    echo -e "\nCan't log in to ${REMOTE_DOCKER_PROVIDER_DNS}" >&2
                    exit
                fi
                ;;
                
            *)
                # Docker utility defaults to dockerhub if no registry provided to a pull command
                FULL_REMOTE_DOCKER_IMAGE="${REMOTE_DOCKER_IMAGE}"
                ;;
        esac
    
        # Pull in the remote image
        docker pull ${FULL_REMOTE_DOCKER_IMAGE}
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo -e "\nCan't pull ${REMOTE_DOCKER_IMAGE} from ${DOCKER_IMAGE_SOURCE}" >&2
        else
            # Tag the image ready to push to the registry
            docker tag ${FULL_REMOTE_DOCKER_IMAGE} ${FULL_DOCKER_IMAGE}
            RESULT=$?
            if [[ "$RESULT" -ne 0 ]]; then
                echo -e "\nCouldn't tag image ${FULL_REMOTE_DOCKER_IMAGE} with ${FULL_DOCKER_IMAGE}" >&2
            else
                # Push to registry
                createRepository ${DOCKER_PROVIDER_DNS} ${DOCKER_REPO}
                RESULT=$?
                if [ $RESULT -ne 0 ]; then
                    echo -e "\nUnable to create repository ${DOCKER_REPO} in the local registry" >&2
                else
                    docker push ${FULL_DOCKER_IMAGE}
                    RESULT=$?
                    if [[ "$RESULT" -ne 0 ]]; then
                        echo -e "\nUnable to push ${DOCKER_IMAGE} to the local registry" >&2
                    fi
                fi
            fi
        fi
        ;;        
        
    *)
        echo -e "\n Unknown operation \"${DOCKER_OPERATION}\"" >&2
        exit
        ;;
esac

IMAGEID=$(docker images | grep "${REMOTE_DOCKER_REPO}" | grep "${REMOTE_DOCKER_TAG}" | head -1 |awk '{print($3)}')
if [[ "${IMAGEID}" != "" ]]; then
    docker rmi -f ${IMAGEID}
fi

IMAGEID=$(docker images | grep "${DOCKER_REPO}" | grep "${DOCKER_TAG}" | head -1 |awk '{print($3)}')
if [[ "${IMAGEID}" != "" ]]; then
    docker rmi -f ${IMAGEID}
fi

# The RESULT variable is not explicitly set here so result of operation
# can be returned after image cleanup.
