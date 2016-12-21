#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Check for repo provided slice list
# slice(s).ref are legacy - always use slices.json
if [[ -z "${SLICE_LIST}" ]]; then
    if [[ -f slices.json ]]; then
        for ATTRIBUTE in slices format; do 
            ATTRIBUTE_VALUE=$(echo "slices.json" | jq -r ".${ATTRIBUTE} | select(.!=null)")
            declare "${ATTRIBUTE^^}"="${ATTRIBUTE_VALUE}"
        done
        export SLICE_LIST="${SLICES}"
    else
        if [[ -f slices.ref ]]; then
            export SLICE_LIST=`cat slices.ref`
        else
            if [[ -f slice.ref ]]; then
                export SLICE_LIST=`cat slice.ref`
            fi
        fi
    fi

    echo "SLICE_LIST=${SLICE_LIST}" >> ${AUTOMATION_DATA_DIR}/context.properties
fi

# Already set image format overrides that in the repo
export IMAGE_FORMAT="${IMAGE_FORMAT:-${FORMAT:-docker}}}"
echo "IMAGE_FORMAT_LIST=${IMAGE_FORMAT}" >> ${AUTOMATION_DATA_DIR}/context.properties

SLICE_ARRAY=(${SLICE_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})

# Record key parameters for downstream jobs
echo "SLICES=${SLICE_LIST}" >> $AUTOMATION_DATA_DIR/chain.properties
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
            ${AUTOMATION_DIR}/manageDocker.sh -v -s "${SLICE_ARRAY[0]}" -g "${CODE_COMMIT_ARRAY[0]}"
            RESULT=$?
            if [[ "${RESULT}" -eq 0 ]]; then
                RESULT=1
                exit
            fi
        else
            echo -e "\nDockerfile missing"
            exit
        fi
        ;;

    # TODO: Perform checks for AWS Lambda packaging - not sure yet what to check for as a marker
    *)
        echo -e "\nUnsupported image format \"${IMAGE_FORMAT}\""
        exit
        ;;
esac

# All good
RESULT=0