#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Make sure we are in the build source directory
cd ${AUTOMATION_BUILD_SRC_DIR}

# Select the package manage to use
if [[ -z "${NODE_PACKAGE_MANAGER}" ]]; then
    if $(which yarn > /dev/null 2>&1) ; then
        NODE_PACKAGE_MANAGER="yarn"
    else
        NODE_PACKAGE_MANAGER="npm"
    fi
fi

${NODE_PACKAGE_MANAGER} install
RESULT=$?
[[ $RESULT -ne 0 ]] && fatal "npm install failed"

# Run bower as part of the build if required
if [[ -f bower.json ]]; then
    bower install --allow-root
    RESULT=$?
    [[ $RESULT -ne 0 ]] && fatal "Bower install failed"
fi

# Determine required tasks
# Build is always first
REQUIRED_TASKS=( "build" )

# Perform format specific tasks if defined
IMAGE_FORMATS_ARRAY=(${IMAGE_FORMATS_LIST})
IFS="${IMAGE_FORMAT_SEPARATORS}" read -ra FORMATS <<< "${IMAGE_FORMATS_ARRAY[0]}"
REQUIRED_TASKS=( "${REQUIRED_TASKS[@]}" "${FORMATS[@]}" )

# The build file existence checks below rely on nullglob
# to return nothing if no match
shopt -s nullglob
BUILD_FILES=( ?runtfile.js ?ulpfile.js package.json)

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

            package.json)
                BUILD_TASKS=( $(jq -r '.scripts | select(.!=null) | keys[]' < package.json) )
                BUILD_UTILITY="${NODE_PACKAGE_MANAGER} run"
                ;;
        esac

        if [[ "${BUILD_TASKS[*]/${REQUIRED_TASK}/XXfoundXX}" != "${BUILD_TASKS[*]}" ]]; then
            ${BUILD_UTILITY} ${REQUIRED_TASK}
            RESULT=$?
            [[ $RESULT -ne 0 ]] && fatal "${BUILD_UTILITY} \"${TASK}\" task failed"

            # Task complete so stop looking for build file supporting it
            break
        fi
    done
done

# Clean up dev dependencies
case ${NODE_PACKAGE_MANAGER} in
    yarn)
        yarn install --production
        ;;
    *)
        npm prune --production
        ;;
esac
RESULT=$?
[[ $RESULT -ne 0 ]] && fatal "Prune failed"

${AUTOMATION_DIR}/manageImages.sh -f "${IMAGE_FORMATS_ARRAY[0]}"
RESULT=$?
