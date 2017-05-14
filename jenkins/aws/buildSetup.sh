#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Ensure we are in the directory where the repo was checked out
cd ${AUTOMATION_BUILD_DIR}

# Check for repo provided deployment unit list
# slice(s).ref and slices.json are legacy - always use deployment_units.json
if [[ -z "${DEPLOYMENT_UNIT_LIST}" ]]; then
    for DU_FILE in "codeontap/deployment_units.json" deployment_units.json slices.json slices.ref slice.ref; do
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
                    export DEPLOYMENT_UNIT_LIST="${UNITS:-${SLICES}}"
                    break
                    ;;
    
                ref)
                    export DEPLOYMENT_UNIT_LIST=$(cat "${DU_FILE}")
                    break
                    ;;
            esac
        fi
    done

    echo "DEPLOYMENT_UNIT_LIST=${DEPLOYMENT_UNIT_LIST}" >> ${AUTOMATION_DATA_DIR}/context.properties
fi

# Already set image format overrides that in the repo
IMAGE_FORMATS="${IMAGE_FORMATS:-${IMAGE_FORMAT}}"
IMAGE_FORMATS="${IMAGE_FORMATS:-${FORMATS:-docker}}"
IMAGE_FORMATS_ARRAY=(${IMAGE_FORMATS})
export IMAGE_FORMATS_LIST=$(IFS=','; echo "${IMAGE_FORMATS_ARRAY[*]}")
echo "IMAGE_FORMATS_LIST=${IMAGE_FORMATS_LIST}" >> ${AUTOMATION_DATA_DIR}/context.properties

DEPLOYMENT_UNIT_ARRAY=(${DEPLOYMENT_UNIT_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})

# Record key parameters for downstream jobs
echo "DEPLOYMENT_UNITS=${DEPLOYMENT_UNIT_LIST}" >> $AUTOMATION_DATA_DIR/chain.properties
echo "GIT_COMMIT=${CODE_COMMIT_ARRAY[0]}" >> $AUTOMATION_DATA_DIR/chain.properties
echo "IMAGE_FORMATS=${IMAGE_FORMATS_LIST}" >> $AUTOMATION_DATA_DIR/chain.properties

# Include the build information in the detail message
${AUTOMATION_DIR}/manageBuildReferences.sh -l
RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then exit; fi

# Ensure no builds exist regardless of format
PRESENT=0
for IMAGE_FORMAT in "${IMAGE_FORMATS_ARRAY[@]}"; do
    case ${IMAGE_FORMAT,,} in
        docker)
            ${AUTOMATION_DIR}/manageDocker.sh -v -s "${DEPLOYMENT_UNIT_ARRAY[0]}" -g "${CODE_COMMIT_ARRAY[0]}"
            RESULT=$?
            if [[ "${RESULT}" -eq 0 ]]; then
                PRESENT=1
            fi
            ;;

        lambda)
            ${AUTOMATION_DIR}/manageLambda.sh -v -u "${DEPLOYMENT_UNIT_ARRAY[0]}" -g "${CODE_COMMIT_ARRAY[0]}"
            RESULT=$?
            if [[ "${RESULT}" -eq 0 ]]; then
                PRESENT=1
            fi
            ;;

        swagger)
            ${AUTOMATION_DIR}/manageSwagger.sh -v -u "${DEPLOYMENT_UNIT_ARRAY[0]}" -g "${CODE_COMMIT_ARRAY[0]}"
            RESULT=$?
            if [[ "${RESULT}" -eq 0 ]]; then
                PRESENT=1
            fi
            ;;

        cloudfront)
            ${AUTOMATION_DIR}/manageCloudFront.sh -v -u "${DEPLOYMENT_UNIT_ARRAY[0]}" -g "${CODE_COMMIT_ARRAY[0]}"
            RESULT=$?
            if [[ "${RESULT}" -eq 0 ]]; then
                PRESENT=1
            fi
            ;;

        *)
            echo -e "\nUnsupported image format \"${IMAGE_FORMAT}\"" >&2
            exit
            ;;
    esac
done

RESULT=${PRESENT}
if [[ "${RESULT}" -ne 0 ]]; then exit; fi

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
                    if [[ ${RESULT} -ne 0 ]]; then
                        exit
                    fi
                else
                    echo -e "\nWARNING: \"${REPO_NAME} repo already exists - using existing local rather than fetching again" >&2
                fi
            else
                echo -e "\nWARNING: Incorrectly formatted include repo information: ${ENTRY}" >&2
            fi
        else
            # No more entries to process
            break
        fi
    done
fi

# All good
RESULT=0