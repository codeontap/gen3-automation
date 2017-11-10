#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${GENERATION_DIR}/common.sh"

# Remember if anything was processed
SAVE_REQUIRED="false"

# Determine the units to process
LEVEL="account"
IFS="${DEPLOYMENT_UNIT_SEPARATORS}" read -ra UNITS <<< "${ACCOUNT_UNITS_LIST}"

# Reverse the order if we are deleting
[[ "${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOP}" ]] && reverseArray UNITS

for CURRENT_DEPLOYMENT_UNIT in "${UNITS[@]}"; do
  
  # Say what we are doing
  info "Processing \"${LEVEL}\" level, \"${CURRENT_DEPLOYMENT_UNIT}\" unit ...\n"

  # Generate the template if required
  if [[ ("${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_UPDATE}") ]]; then
    ${AUTOMATION_DIR}/createTemplates.sh -u "${CURRENT_DEPLOYMENT_UNIT}" -l "${LEVEL}" -c "${INFRASTRUCTURE_TAG}"
    RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit 
  fi

  ${AUTOMATION_DIR}/manageStacks.sh -u "${CURRENT_DEPLOYMENT_UNIT}" -l "${LEVEL}"
  RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit

  SAVE_REQUIRED="true"
done

# Update the code and credentials buckets if required
if [[ "${SYNC_ACCOUNT_BUCKETS}" == "true" ]]; then
    cd ${ACCOUNT_DIR}
    ${GENERATION_DIR}/syncAccountBuckets.sh -a ${ACCOUNT}
fi

# All good - save the result
if [[ "${SAVE_REQUIRED}" == "true" ]]; then
  info "Saving changes under tag \"${INFRASTRUCTURE_TAG}\" ..."

  save_product_infrastructure \
    "${DETAIL_MESSAGE}, level=segment, units=cmk" \
    "${PRODUCT_INFRASTRUCTURE_REFERENCE}" \
    "${INFRASTRUCTURE_TAG}"
  RESULT=$?
fi



