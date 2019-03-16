#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Change to the app directory
cd app

# Select the package manage to use
NODE_PACKAGE_MANAGER="${NODE_PACKAGE_MANAGER:-yarn}"

# Install required node modules
${NODE_PACKAGE_MANAGER} install
RESULT=$?
[[ $RESULT -ne 0 ]] && fatal "npm install failed"

# Build meteor but don't tar it
meteor build ../dist --directory
RESULT=$?
[[ $RESULT -ne 0 ]] && fatal "Meteor build failed"

cd ..

# Install the required node modules
(cd dist/bundle/programs/server && ${NODE_PACKAGE_MANAGER} install --production)
RESULT=$?
[[ $RESULT -ne 0 ]] && "Installation of app node modules failed"

# Sanity check on final size of build
MAX_METEOR_BUILD_SIZE=${MAX_METEOR_BUILD_SIZE:-100}
[[ $(du -s -m ./dist | cut -f 1) -gt ${MAX_METEOR_BUILD_SIZE} ]] && RESULT=1 &&
    fatal "Build size exceeds ${MAX_METEOR_BUILD_SIZE}M"

${AUTOMATION_DIR}/manageImages.sh
RESULT=$?
