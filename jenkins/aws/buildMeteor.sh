#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Change to the app directory
cd app

# Install required npm packages
npm install --production
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nnpm install failed"
   exit
fi

# Build meteor but don't tar it
meteor build ../dist --directory
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nmeteor build failed"
   exit
fi
cd ..

# Install the required node modules
(cd dist/bundle/programs/server && npm install --production)
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nInstallation of app node modules failed"
   exit
fi

# Sanity check on final size of build
MAX_METEOR_BUILD_SIZE=${MAX_METEOR_BUILD_SIZE:-100}
if [[ $(du -s -m ./dist | cut -f 1) -gt ${MAX_METEOR_BUILD_SIZE} ]]; then
    RESULT=1
    echo -e "\nBuild size exceeds ${MAX_METEOR_BUILD_SIZE}M"
    exit
fi

. ${AUTOMATION_DIR}/manageImages.sh
RESULT=$?
