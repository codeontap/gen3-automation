#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

npm install --unsafe-perm
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nnpm install failed" >&2
   exit
fi

# Run bower as part of the build if required
if [[ -f bower.json ]]; then
    bower install --allow-root
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo -e "\nbower install failed" >&2
       exit
    fi
fi

# Determine required tasks
# Build is always first
REQUIRED_TASKS=( "build" )

# Perform format specific tasks if defined
IMAGE_FORMATS_ARRAY=(${IMAGE_FORMATS_LIST})
IFS="," read -ra FORMATS <<< "${IMAGE_FORMATS_ARRAY[0]}"
REQUIRED_TASKS=( "${REQUIRED_TASKS[@]}" "${FORMATS[@]}" )

# The build file existence checks below rely on nullglob
# to return nothing if no match
shopt -s nullglob
BUILD_FILES=( ?runtfile.js ?ulpfile.js )

# Perform build tasks in the order specified
for REQUIRED_TASK in "${REQUIRED_TASKS[@]}"; do
    for BUILD_FILE in "${BUILD_FILES[@]}"; do
        BUILD_TASKS=()
        case ${BUILD_FILE} in
            ?runtfile.js)
                BUILD_TASKS=( $(grunt -h --no-color | sed -n '/^Available tasks/,/^$/ {s/^  *\([^ ]\+\)  [^ ]\+.*$/\1/p}') )
                BUILD_UTILITY="grunt"
                ;;

            ?ulpfile.js)
                BUILD_TASKS=( $(gulp --tasks-simple) )
                BUILD_UTILITY="gulp"
                ;;
        esac

        if [[ "${BUILD_TASKS[*]/${REQUIRED_TASK}/XXfoundXX}" != "${BUILD_TASKS[*]}" ]]; then
            ${BUILD_UTILITY} ${REQUIRED_TASK}
            RESULT=$?
            if [ $RESULT -ne 0 ]; then
                echo -e "\n${BUILD_UTILITY} \"${TASK}\" task failed" >&2
                exit
            fi

            # Task complete so stop looking for build file supporting it
            break
        fi
    done
done

# Clean up
npm prune --production
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nnpm prune failed" >&2
   exit
fi

. ${AUTOMATION_DIR}/manageImages.sh
RESULT=$?
