#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Ensure we are in the directory where the repo was checked out
cd ${AUTOMATION_BUILD_DIR}

# Check for a build qualifier
BUILD_TASK_QUALIFIER=
if [[ -n "${BUILD_TASKS}" ]]; then
    REQUIRED_TASKS=( ${BUILD_TASKS} )
    for REQUIRED_TASK in "${REQUIRED_TASKS[@]}"; do
        REQUIRED_TASK_BASE="${REQUIRED_TASK%%:*}"
        REQUIRED_TASK_QUALIFIER="${REQUIRED_TASK##*:}"
        if [[ ("${REQUIRED_TASK_BASE}" == "build") &&
            ("${REQUIRED_TASK}" != "${REQUIRED_TASK_BASE}") ]]; then
            BUILD_TASK_QUALIFIER="${REQUIRED_TASK_QUALIFIER,,}_"
        fi
    done
fi

DU_FILES=(
    "${AUTOMATION_BUILD_DEVOPS_DIR}/${BUILD_TASK_QUALIFIER}deployment_units.json" \
    "${AUTOMATION_BUILD_DEVOPS_DIR}/codeontap/${BUILD_TASK_QUALIFIER}deployment_units.json" \
    "${BUILD_TASK_QUALIFIER}deployment_units.json" \
    slices.json slices.ref slice.ref \
)
# Check for repo provided deployment unit list
# slice(s).ref and slices.json are legacy - always use deployment_units.json
if [[ -z "${DEPLOYMENT_UNIT_LIST}" ]]; then
    for DU_FILE in "${DU_FILES[@]}"; do
        if [[ -f "${DU_FILE}" ]]; then
            case "${DU_FILE##*.}" in
                json)
                    for ATTRIBUTE in units slices formats; do
                        ATTRIBUTE_VALUE=$(jq -r ".${ATTRIBUTE} | select(.!=null) | .[]" < "${DU_FILE}" | tr -s "\r\n" " ")
                        if [[ -z "${ATTRIBUTE_VALUE}" ]]; then
                            ATTRIBUTE_VALUE=$(jq -r ".${ATTRIBUTE^} | select(.!=null) | .[]" < "${DU_FILE}" | tr -s "\r\n" " ")
                        fi
                        declare "${ATTRIBUTE^^}"="${ATTRIBUTE_VALUE}"
                    done
                    for ATTRIBUTE in scope; do
                        ATTRIBUTE_VALUE=$(jq -r ".${ATTRIBUTE} | select(.!=null)" < "${DU_FILE}" | tr -d "\r\n")
                        if [[ -z "${ATTRIBUTE_VALUE}" ]]; then
                            ATTRIBUTE_VALUE=$(jq -r ".${ATTRIBUTE^} | select(.!=null)" < "${DU_FILE}" | tr -d "\r\n")
                        fi
                        declare "${ATTRIBUTE^^}"="${ATTRIBUTE_VALUE}"
                    done
                    export DEPLOYMENT_UNIT_LIST="${UNITS:-${SLICES}}"
                    export REGISTRY_SCOPE="${SCOPE,,}"
                    break
                    ;;

                ref)
                    export DEPLOYMENT_UNIT_LIST=$(cat "${DU_FILE}")
                    export REGISTRY_SCOPE=""
                    break
                    ;;
            esac
        fi
    done

    save_context_property DEPLOYMENT_UNIT_LIST
    save_context_property REGISTRY_SCOPE
fi

# Already set image format overrides that in the repo
IMAGE_FORMATS="${IMAGE_FORMATS:-${IMAGE_FORMAT}}"
IMAGE_FORMATS="${IMAGE_FORMATS:-${FORMATS:-docker}}"
IFS="${IMAGE_FORMAT_SEPARATORS}, " read -ra IMAGE_FORMATS_ARRAY <<< "${IMAGE_FORMATS}"
export IMAGE_FORMATS_LIST=$(IFS="${IMAGE_FORMAT_SEPARATORS}"; echo "${IMAGE_FORMATS_ARRAY[*]}")
save_context_property IMAGE_FORMATS_LIST

DEPLOYMENT_UNIT_ARRAY=(${DEPLOYMENT_UNIT_LIST})
DEPLOYMENT_UNIT="${DEPLOYMENT_UNIT_ARRAY[0]}"
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})
CODE_COMMIT="${CODE_COMMIT_ARRAY[0]}"

# Record key parameters for downstream jobs
save_chain_property DEPLOYMENT_UNITS "${DEPLOYMENT_UNIT_LIST}"
save_chain_property GIT_COMMIT "${CODE_COMMIT}"
save_chain_property IMAGE_FORMATS
save_chain_property REGISTRY_SCOPE

# Include the build information in the detail message
${AUTOMATION_DIR}/manageBuildReferences.sh -l
RESULT=$?
[[ "${RESULT}" -ne 0 ]] && exit

# Ensure no builds exist regardless of format
PRESENT=0

for IMAGE_FORMAT in "${IMAGE_FORMATS_ARRAY[@]}"; do
    case ${IMAGE_FORMAT,,} in
        dataset)
            ${AUTOMATION_DIR}/manageDataSetS3.sh -v -u "${DEPLOYMENT_UNIT}" -g "undefined" -c "${REGISTRY_SCOPE}"
            RESULT=$?
            [[ "${RESULT}" -eq 0 ]] && PRESENT=1
            ;;

        rdssnapshot)
            ${AUTOMATION_DIR}/manageDataSetRDSSnapshot.sh -v -u "${DEPLOYMENT_UNIT}" -g "undefined" -c "${REGISTRY_SCOPE}"
            RESULT=$?
            [[ "${RESULT}" -eq 0 ]] && PRESENT=1
            ;;

        docker)
            ${AUTOMATION_DIR}/manageDocker.sh -v -s "${DEPLOYMENT_UNIT}" -g "${CODE_COMMIT}" -c "${REGISTRY_SCOPE}"
            RESULT=$?
            [[ "${RESULT}" -eq 0 ]] && PRESENT=1
            ;;

        lambda)
            ${AUTOMATION_DIR}/manageLambda.sh -v -u "${DEPLOYMENT_UNIT}" -g "${CODE_COMMIT}" -c "${REGISTRY_SCOPE}"
            RESULT=$?
            [[ "${RESULT}" -eq 0 ]] && PRESENT=1
            ;;

        pipeline)
            ${AUTOMATION_DIR}/managePipeline.sh -v -u "${DEPLOYMENT_UNIT}" -g "${CODE_COMMIT}" -c "${REGISTRY_SCOPE}"
            RESULT=$?
            [[ "${RESULT}" -eq 0 ]] && PRESENT=1
            ;;

        scripts)
            ${AUTOMATION_DIR}/manageScripts.sh -v -u "${DEPLOYMENT_UNIT}" -g "${CODE_COMMIT}" -c "${REGISTRY_SCOPE}"
            RESULT=$?
            [[ "${RESULT}" -eq 0 ]] && PRESENT=1
            ;;

        openapi|swagger)
            ${AUTOMATION_DIR}/manageOpenapi.sh -v \
                -y "${IMAGE_FORMAT,,}"  -c "${REGISTRY_SCOPE}" -f "${IMAGE_FORMAT,,}.zip" \
                -u "${DEPLOYMENT_UNIT}" -g "${CODE_COMMIT}"
            RESULT=$?
            [[ "${RESULT}" -eq 0 ]] && PRESENT=1
            ;;

        spa)
            ${AUTOMATION_DIR}/manageSpa.sh -v -u "${DEPLOYMENT_UNIT}" -g "${CODE_COMMIT}" -c "${REGISTRY_SCOPE}"
            RESULT=$?
            [[ "${RESULT}" -eq 0 ]] && PRESENT=1
            ;;

        contentnode)
            ${AUTOMATION_DIR}/manageContentNode.sh -v -u "${DEPLOYMENT_UNIT}" -g "${CODE_COMMIT}" -c "${REGISTRY_SCOPE}"
            RESULT=$?
            [[ "${RESULT}" -eq 0 ]] && PRESENT=1
            ;;

        *)
            fatal "Unsupported image format \"${IMAGE_FORMAT}\""
            ;;
    esac
done

RESULT=${PRESENT}
[[ "${RESULT}" -ne 0 ]] && exit

# Perform prebuild actions
if [[ -f prebuild.json ]]; then
    # Include repos
    for ((INDEX=0; ; INDEX++)); do
        ENTRY=$(jq -c ".IncludeRepos[${INDEX}] | select(.!=null)" < prebuild.json)
        if [[ -n "${ENTRY}" ]]; then
            # Extract key attributes
            REPO_PROVIDER=$(jq -r '.provider' <<< $ENTRY)
            REPO_NAME=$(jq -r '.name' <<< $ENTRY)

            if [[ (-n "${REPO_PROVIDER}") && (-n "${REPO_NAME}") ]]; then
                if [[ ! -e "./${REPO_NAME}" ]]; then
                    ${AUTOMATION_DIR}/manageRepo.sh -c -l "${REPO_NAME}" \
                        -n "${REPO_NAME}" -v "${REPO_PROVIDER^^}" \
                        -d "./${REPO_NAME}"
                    RESULT=$?
                    [[ ${RESULT} -ne 0 ]] && exit
                else
                    warning "\"${REPO_NAME}\" repo already exists - using existing local rather than fetching again"
                fi
            else
                warning "Incorrectly formatted include repo information: ${ENTRY}"
            fi
        else
            # No more entries to process
            break
        fi
    done
fi

# All good
RESULT=0