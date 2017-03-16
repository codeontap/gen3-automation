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

# Grunt based build (first letter can be upper or lower case)
GRUNT_FILES=( ?runtfile.js )
if (( ${#GRUNT_FILES[@]} )) ; then
    REQUIRED_TASKS="${REQUIRED_TASKS:-build lambda}"
    GRUNT_TASKS=( $(grunt -h --no-color | sed -n '/^Available tasks/,/^$/ {s/^  *\([^ ]\+\)  [^ ]\+.*$/\1/p}') )
    for REQUIRED_TASK in ${REQUIRED_TASKS}; do
        if [[ "${GRUNT_TASKS[*]/${REQUIRED_TASK}/XXfoundXX}" != "${GRUNT_TASKS[*]}" ]]; then
            grunt ${REQUIRED_TASK}
            RESULT=$?
            if [ $RESULT -ne 0 ]; then
                echo -e "\ngrunt \"${TASK}\" task failed" >&2
                exit
            fi
        else
            echo -e "\nWARNING: Task \"${REQUIRED_TASK}\" not found in Gruntfile" >&2
        fi
    done
fi

# Gulp based build
if [[ -f gulpfile.js ]]; then
    gulp build
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo -e "\ngulp build failed" >&2
       exit
    fi
fi

# Clean up
npm prune --production
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nnpm prune failed" >&2
   exit
fi

. ${AUTOMATION_DIR}/manageImages.sh
RESULT=$?
