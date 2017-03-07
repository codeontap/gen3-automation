#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Check for repo provided deployment unit list
# slice(s).ref and slices.json are legacy - always use deployment_units.json
if [[ -z "${DEPLOYMENT_UNIT_LIST}" ]]; then
    for DU_FILE in deployment_units.json slices.json slices.ref slice.ref; do
        if [[ -f ${DU_FILE} ]]; then
            case ${DU_FILE##*.} in
                json)
                    for ATTRIBUTE in units slices format; do 
                        ATTRIBUTE_VALUE=$(jq -r ".${ATTRIBUTE} | select(.!=null)" < ${DU_FILE})
                        declare "${ATTRIBUTE^^}"="${ATTRIBUTE_VALUE}"
                    done
                    export DEPLOYMENT_UNIT_LIST="${UNITS:-${SLICES}}"
                    break
                    ;;
    
                ref)
                    export DEPLOYMENT_UNIT_LIST=$(cat ${DU_FILE})
                    break
                    ;;
            esac
        fi
    done

    echo "DEPLOYMENT_UNIT_LIST=${DEPLOYMENT_UNIT_LIST}" >> ${AUTOMATION_DATA_DIR}/context.properties
fi

# Already set image format overrides that in the repo
IMAGE_FORMAT="${IMAGE_FORMAT:-${FORMAT:-docker}}"
export IMAGE_FORMAT_LIST="${IMAGE_FORMAT}"
echo "IMAGE_FORMAT_LIST=${IMAGE_FORMAT_LIST}" >> ${AUTOMATION_DATA_DIR}/context.properties

DEPLOYMENT_UNIT_ARRAY=(${DEPLOYMENT_UNIT_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})

# Record key parameters for downstream jobs
echo "DEPLOYMENT_UNITS=${DEPLOYMENT_UNIT_LIST}" >> $AUTOMATION_DATA_DIR/chain.properties
echo "GIT_COMMIT=${CODE_COMMIT_ARRAY[0]}" >> $AUTOMATION_DATA_DIR/chain.properties
echo "IMAGE_FORMAT=${IMAGE_FORMAT}" >> $AUTOMATION_DATA_DIR/chain.properties

# Include the build information in the detail message
${AUTOMATION_DIR}/manageBuildReferences.sh -l
RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then exit; fi

case ${IMAGE_FORMAT} in
    docker)
        # Perform checks for Docker packaging
        if [[ -f Dockerfile ]]; then
            ${AUTOMATION_DIR}/manageDocker.sh -v -s "${DEPLOYMENT_UNIT_ARRAY[0]}" -g "${CODE_COMMIT_ARRAY[0]}"
            RESULT=$?
            if [[ "${RESULT}" -eq 0 ]]; then
                RESULT=1
                exit
            fi
        else
            echo -e "\nDockerfile missing" >&2
            exit
        fi
        ;;

    # TODO: Perform checks for AWS Lambda packaging - not sure yet what to check for as a marker
    *)
        echo -e "\nUnsupported image format \"${IMAGE_FORMAT}\"" >&2
        exit
        ;;
esac

# All good
RESULT=0