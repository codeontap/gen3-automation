#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Update build references
${AUTOMATION_DIR}/manageBuildReferences.sh -u
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then exit; fi

# Get list of slices and associated with the reference
SLICE_ARRAY=(${SLICE_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})

${AUTOMATION_DIR}/manageRepo.sh -p \
    -d ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT} \
    -n config \
    -m "${DETAIL_MESSAGE}" \
    -b ${PRODUCT_CONFIG_REFERENCE}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then exit; fi

if [[ "$AUTODEPLOY" != "true" ]]; then
  echo -e "\nAUTODEPLOY is not true, triggering exit"
  RESULT=2
  exit
fi

# Record key parameters for downstream jobs
echo "SLICES=${SLICE_LIST}" >> $AUTOMATION_DATA_DIR/chain.properties

# All good
RESULT=0


