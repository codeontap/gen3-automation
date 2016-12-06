#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

npm install --unsafe-perm
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nnpm install failed"
   exit
fi

# Run bower as part of the build if required
if [[ -f bower.json ]]; then
    bower install --allow-root
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo -e "\nbower install failed"
       exit
    fi
fi

# Grunt based build
if [[ -f gruntfile.js ]]; then
    grunt build
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo -e "\ngrunt build failed"
       exit
    fi
fi

# Gulp based build
if [[ -f gulpfile.js ]]; then
    gulp build
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo -e "\ngulp build failed"
       exit
    fi
fi

# Clean up
npm prune --production
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nnpm prune failed"
   exit
fi

. ${AUTOMATION_DIR}/manageImages.sh
RESULT=$?
