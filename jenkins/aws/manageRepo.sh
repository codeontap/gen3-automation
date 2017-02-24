#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

REPO_OPERATION_CLONE="clone"
REPO_OPERATION_INIT="init"
REPO_OPERATION_PUSH="push"

# Defaults
REPO_OPERATION_DEFAULT="${REPO_OPERATION_PUSH}"
REPO_REMOTE_DEFAULT="origin"
REPO_BRANCH_DEFAULT="master"

function usage() {
    cat <<EOF

Manage git repos

Usage: $(basename $0) -l REPO_LOG_NAME -m REPO_MESSAGE -d REPO_DIR
        -u REPO_URL -n REPO_NAME -v REPO_PROVIDER
        -t REPO_TAG -r REPO_REMOTE -b REPO_BRANCH
        -s GIT_USER -e GIT_EMAIL -i -c -p

where

(o) -c (REPO_OPERATION=${REPO_OPERATION_CLONE}) clone repo
(m) -d REPO_DIR         is the directory containing the repo
(o) -e GIT_EMAIL        is the repo user email
    -h                  shows this text
(o) -i (REPO_OPERATION=${REPO_OPERATION_INIT}) initialise repo
(o) -l REPO_NAME        is the repo name for the git provider
(o) -m REPO_MESSAGE     is used as the commit/tag message
(m) -n REPO_LOG_NAME    to use in log messages
(o) -p (REPO_OPERATION=${REPO_OPERATION_PUSH}) commit local repo and push to origin
(o) -r REPO_REMOTE      is the remote name for pushing
(o) -s GIT_USER         is the repo user
(o) -t REPO_TAG         is the tag to add after any commit
(o) -u REPO_URL         is the repo URL
(o) -v REPO_PROVIDER    is the repo git provider

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

REPO_OPERATION=${REPO_OPERATION_DEFAULT}
REPO_REMOTE=${REPO_REMOTE_DEFAULT}
REPO_BRANCH=${REPO_BRANCH_DEFAULT}

NOTES:

1. Initialise requires REPO_LOG_NAME and REPO_URL
2. Initialise does nothing if existing repo detected
3. Current branch is assumed when pushing
4. REPO_NAME and REPO_PROVIDER can be supplied as
   an alternative to REPO_URL

EOF
    exit
}

function init() {
    echo -e "Initialising the ${REPO_LOG_NAME} repo..."
    git status >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        # Convert directory into a repo
        git init .
    fi

    if [[ (-z "${REPO_REMOTE}") ]]; then
        echo -e "\nInsufficient arguments" >&2
        exit
    fi
    git remote show "${REPO_REMOTE}" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        if [[ (-z "${REPO_URL}") ]]; then
            echo -e "\nInsufficient arguments" >&2
            exit
        fi
        git remote add "${REPO_REMOTE}" "${REPO_URL}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo -e "\nCan't add remote ${REPO_REMOTE} to ${REPO_LOG_NAME} repo" >&2
            exit
        fi
    fi
    
    git log -n 1 >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        # Create basic files
        echo -e "# ${REPO_LOG_NAME}" > README.md
        touch .gitignore LICENSE.md

        # Commit to repo in preparation for first push
        REPO_MESSAGE="${REPO_MESSAGE:-Initial commit}"
        push
    fi
}

function clone() {
    echo -e "Cloning the ${REPO_LOG_NAME} repo and checking out the ${REPO_BRANCH} branch ..."
    if [[ (-z "${REPO_URL}") ||
            (-z "${REPO_BRANCH}") ]]; then
        echo -e "\nInsufficient arguments" >&2
        exit
    fi

    git clone -b "${REPO_BRANCH}" "${REPO_URL}" .
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo -e "\nCan't clone ${REPO_LOG_NAME} repo" >&2
        exit
    fi
}

function push() {
    if [[ (-z "${GIT_USER}") ||
            (-z "${GIT_EMAIL}") ||
            (-z "${REPO_MESSAGE}") ||
            (-z "${REPO_REMOTE}") ]]; then
        echo -e "\nInsufficient arguments" >&2
        exit
    fi

    git remote show "${REPO_REMOTE}" >/dev/null 2>&1
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo -e "\nRemote ${REPO_REMOTE} is not initialised" >&2
        exit
    fi

    # Ensure git knows who we are
    git config user.name  "${GIT_USER}"
    git config user.email "${GIT_EMAIL}"

    # Add anything that has been added/modified/deleted
    git add -A

    if [[ -n "$(git status --porcelain)" ]]; then
        # Commit changes
        echo -e "Committing to the ${REPO_LOG_NAME} repo..."
        git commit -m "${REPO_MESSAGE}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo -e "\nCan't commit to the ${REPO_LOG_NAME} repo" >&2
            exit
        fi
        REPO_PUSH_REQUIRED="true"
    fi

    # Tag the commit if required
    if [[ -n "${REPO_TAG}" ]]; then
        echo -e "Adding tag \"${REPO_TAG}\" to the ${REPO_LOG_NAME} repo..."
        git tag -a "${REPO_TAG}" -m "${REPO_MESSAGE}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo -e "\nCan't tag the ${REPO_LOG_NAME} repo" >&2
            exit
        fi
        REPO_PUSH_REQUIRED="true"
    fi

    # Update upstream repo
    if [[ "${REPO_PUSH_REQUIRED}" == "true" ]]; then
        echo -e "Pushing the ${REPO_LOG_NAME} repo upstream..."
        git push --tags ${REPO_REMOTE} ${REPO_BRANCH}
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo -e "\nCan't push the ${REPO_LOG_NAME} repo changes to upstream repo ${REPO_REMOTE}" >&2
            exit
        fi
    fi
}

# Define git provider attributes
# $1 = provider
# $2 = variable prefix
function defineGitProviderAttributes() {
    DGPA_PROVIDER="${1^^}"
    DGPA_PREFIX="${2^^}"

    # Attribute variable names
    for DGPA_ATTRIBUTE in "DNS" "API_DNS" "ORG" "CREDENTIALS_VAR"; do
        DGPA_PROVIDER_VAR="${DGPA_PROVIDER}_GIT_${DGPA_ATTRIBUTE}"
        declare -g ${DGPA_PREFIX}_${DGPA_ATTRIBUTE}="${!DGPA_PROVIDER_VAR}"
    done
}

# Parse options
while getopts ":b:cd:e:hil:m:n:pr:s:t:u:v:" opt; do
    case $opt in
        b)
            REPO_BRANCH="${OPTARG}"
            ;;
        c)
            REPO_OPERATION="${REPO_OPERATION_CLONE}"
            ;;
        d)
            REPO_DIR="${OPTARG}"
            ;;
        e)
            GIT_EMAIL="${OPTARG}"
            ;;
        h)
            usage
            ;;
        i)
            REPO_OPERATION="${REPO_OPERATION_INIT}"
            ;;
        l)
            REPO_LOG_NAME="${OPTARG}"
            ;;
        m)
            REPO_MESSAGE="${OPTARG}"
            ;;
        n)
            REPO_NAME="${OPTARG}"
            ;;
        p)
            REPO_OPERATION="${REPO_OPERATION_PUSH}"
            ;;
        r)
            REPO_REMOTE="${OPTARG}"
            ;;
        s)
            GIT_USER="${OPTARG}"
            ;;
        t)
            REPO_TAG="${OPTARG}"
            ;;
        u)
            REPO_URL="${OPTARG}"
            ;;
        v)
            REPO_PROVIDER="${OPTARG}"
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
REPO_OPERATION="${REPO_OPERATION:-$REPO_OPERATION_DEFAULT}"
REPO_REMOTE="${REPO_REMOTE:-$REPO_REMOTE_DEFAULT}"
REPO_BRANCH="${REPO_BRANCH:-$REPO_BRANCH_DEFAULT}"
if [[ -z "${REPO_URL}" ]]; then
    if [[ (-n "${REPO_PROVIDER}") &&
            (-n "${REPO_NAME}") ]]; then
        defineGitProviderAttributes "${REPO_PROVIDER}" "REPO_PROVIDER"
        if [[ -n "${!REPO_PROVIDER_CREDENTIALS_VAR}" ]]; then
            REPO_URL="https://${!REPO_PROVIDER_CREDENTIALS_VAR}@${REPO_PROVIDER_DNS}/${REPO_PROVIDER_ORG}/${REPO_NAME}"
        else
            REPO_URL="https://${REPO_PROVIDER_DNS}/${REPO_PROVIDER_ORG}/${REPO_NAME}"
        fi
    fi
fi

# Ensure mandatory arguments have been provided
if [[ (-z "${REPO_DIR}") ||
        (-z "${REPO_LOG_NAME}") ]]; then
    echo -e "\nInsufficient arguments" >&2
    exit
fi

# Ensure we are inside the repo directory
if [[ ! -d "${REPO_DIR}" ]]; then
    mkdir -p "${REPO_DIR}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo -e "\nCan't create repo directory ${REPO_DIR}" >&2
        exit
    fi
fi
cd "${REPO_DIR}"

# Perform the required action
case ${REPO_OPERATION} in
    ${REPO_OPERATION_INIT})
        init
        ;;

    ${REPO_OPERATION_CLONE})
        clone
        ;;
        
    ${REPO_OPERATION_PUSH})
        push
        ;;
esac

# All good
RESULT=0
