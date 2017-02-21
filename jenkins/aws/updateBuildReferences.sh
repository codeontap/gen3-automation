#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Update build references
${AUTOMATION_DIR}/manageBuildReferences.sh -u \
    -g ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT}/appsettings/${SEGMENT}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then exit; fi

TAG_SWITCH=()
if [[ -n "${RELEASE_MODE_TAG}" ]]; then
    TAG_SWITCH=("-t" "${RELEASE_MODE_TAG}")
fi

${AUTOMATION_DIR}/manageRepo.sh -p \
    -d ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT} \
    -l "config" \
    -m "${DETAIL_MESSAGE}" \
    "${TAG_SWITCH[@]}" \
    -b ${PRODUCT_CONFIG_REFERENCE}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then exit; fi

if [[ (-n "${AUTODEPLOY+x}") &&
        ("$AUTODEPLOY" != "true") ]]; then
  echo -e "\nAUTODEPLOY is not true, triggering exit"
  RESULT=2
  exit
fi

# Record key parameters for downstream jobs
echo "SLICES=${SLICE_LIST}" >> $AUTOMATION_DATA_DIR/chain.properties

# All good
RESULT=0


