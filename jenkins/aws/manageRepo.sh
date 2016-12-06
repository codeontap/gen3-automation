#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

REPO_OPERATION_DEFAULT="push"
REPO_REMOTE_DEFAULT="origin"
REPO_BRANCH_DEFAULT="master"
function usage() {
    echo -e "\nManage git repos"
    echo -e "\nUsage: $(basename $0) -n REPO_NAME -m REPO_MESSAGE -d REPO_DIR"
    echo -e "\t\t -u REPO_URL -t REPO_TAG -r REPO_REMOTE -b REPO_BRANCH"
    echo -e "\t\t -s GIT_USER -e GIT_EMAIL -i -c -p"
    echo -e "\nwhere\n"
    echo -e "(o) -c clone repo"
    echo -e "(m) -d REPO_DIR is the directory containing the repo"
    echo -e "(o) -e GIT_EMAIL is the repo user email"
    echo -e "    -h shows this text"
    echo -e "(o) -i initialise repo"
    echo -e "(o) -m REPO_MESSAGE is used as the commit/tag message"
    echo -e "(m) -n REPO_NAME to use in log messages"
    echo -e "(o) -p commit local repo and push to origin"
    echo -e "(o) -r REPO_REMOTE is the remote name for pushing"
    echo -e "(o) -s GIT_USER is the repo user"
    echo -e "(o) -t REPO_TAG is the tag to add after any commit"
    echo -e "(o) -u REPO_URL is the repo URL"
    echo -e "\nDEFAULTS:\n"
    echo -e "REPO_OPERATION=${REPO_OPERATION_DEFAULT}"
    echo -e "REPO_REMOTE=${REPO_REMOTE_DEFAULT}"
    echo -e "REPO_BRANCH=${REPO_BRANCH_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e "1. Initialise requires REPO_NAME and REPO_URL"
    echo -e "2. Initialise does nothing if existing repo detected"
    echo -e "3. Current branch is assumed when pushing"
    echo -e ""
    exit
}


function init() {
    echo -e "Initialising the ${REPO_NAME} repo..."
    git status >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        # Convert directory into a repo
        git init .
    fi

    if [[ (-z "${REPO_REMOTE}") ]]; then
        echo -e "\nInsufficient arguments"
        usage
    fi
    git remote show "${REPO_REMOTE}" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        if [[ (-z "${REPO_URL}") ]]; then
            echo -e "\nInsufficient arguments"
            usage
        fi
        git remote add "${REPO_REMOTE}" "${REPO_URL}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo -e "\nCan't add remote ${REPO_REMOTE} to ${REPO_NAME} repo"
            exit
        fi
    fi
    
    git log -n 1 >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        # Create basic files
        echo -e "# ${REPO_NAME}" > README.md
        touch .gitignore LICENSE.md

        # Commit to repo in preparation for first push
        REPO_MESSAGE="${REPO_MESSAGE:-Initial commit}"
        push
    fi
}

function clone() {
    echo -e "Cloning the ${REPO_NAME} repo and checking out the ${REPO_BRANCH} branch ..."
    if [[ (-z "${REPO_URL}") ||
            (-z "${REPO_BRANCH}") ]]; then
        echo -e "\nInsufficient arguments"
        usage
    fi

    git clone -b "${REPO_BRANCH}" "${REPO_URL}" .
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo -e "\nCan't clone ${REPO_NAME} repo"
        exit
    fi
}

function push() {
    if [[ (-z "${GIT_USER}") ||
            (-z "${GIT_EMAIL}") ||
            (-z "${REPO_MESSAGE}") ||
            (-z "${REPO_REMOTE}") ]]; then
        echo -e "\nInsufficient arguments"
        usage
    fi

    git remote show "${REPO_REMOTE}" >/dev/null 2>&1
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo -e "\nRemote ${REPO_REMOTE} is not initialised"
        exit
    fi

    # Ensure git knows who we are
    git config user.name  "${GIT_USER}"
    git config user.email "${GIT_EMAIL}"

    # Add anything that has been added/modified/deleted
    git add -A

    if [[ -n "$(git status --porcelain)" ]]; then
        # Commit changes
        echo -e "Committing to the ${REPO_NAME} repo..."
        git commit -m "${REPO_MESSAGE}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo -e "\nCan't commit to the ${REPO_NAME} repo"
            exit
        fi
        REPO_PUSH_REQUIRED="true"
    fi

    # Tag the commit if required
    if [[ -n "${REPO_TAG}" ]]; then
        echo -e "Adding tag \"${REPO_TAG}\" to the ${REPO_NAME} repo..."
        git tag -a "${REPO_TAG}" -m "${REPO_MESSAGE}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo -e "\nCan't tag the ${REPO_NAME} repo"
            exit
        fi
        REPO_PUSH_REQUIRED="true"
    fi

    # Update upstream repo
    if [[ "${REPO_PUSH_REQUIRED}" == "true" ]]; then
        echo -e "Pushing the ${REPO_NAME} repo upstream..."
        git push --tags ${REPO_REMOTE} ${REPO_BRANCH}
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo -e "\nCan't push the ${REPO_NAME} repo changes to upstream repo ${REPO_REMOTE}"
            exit
        fi
    fi
}

# Parse options
while getopts ":b:cd:e:him:n:pr:s:t:u:" opt; do
    case $opt in
        b)
            REPO_BRANCH="${OPTARG}"
            ;;
        c)
            REPO_OPERATION="clone"
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
            REPO_OPERATION="init"
            ;;
        m)
            REPO_MESSAGE="${OPTARG}"
            ;;
        n)
            REPO_NAME="${OPTARG}"
            ;;
        p)
            REPO_OPERATION="push"
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
REPO_OPERATION="${REPO_OPERATION:-$REPO_OPERATION_DEFAULT}"
REPO_REMOTE="${REPO_REMOTE:-$REPO_REMOTE_DEFAULT}"
REPO_BRANCH="${REPO_BRANCH:-$REPO_BRANCH_DEFAULT}"

# Ensure mandatory arguments have been provided
if [[ (-z "${REPO_DIR}") ||
        (-z "${REPO_NAME}") ]]; then
    echo -e "\nInsufficient arguments"
    usage
fi

# Ensure we are inside the repo directory
if [[ ! -d "${REPO_DIR}" ]]; then
    mkdir -p "${REPO_DIR}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo -e "\nCan't create repo directory ${REPO_DIR}"
        exit
    fi
fi
cd "${REPO_DIR}"

# Perform the required action
case ${REPO_OPERATION} in
    init)
        init
        ;;

    clone)
        clone
        ;;
        
    push)
        push
        ;;
esac

# All good
RESULT=0
