#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Remember if anything was processed
SAVE_REQUIRED="false"

# Configuration reference tag
INFRASTRUCTURE_TAG="env${AUTOMATION_JOB_IDENTIFIER}-${SEGMENT}"

# Process each template level
IFS="${DEPLOYMENT_UNIT_SEPARATORS}" read -ra LEVELS_REQUIRED <<< "${LEVELS}"

# Reverse the order if we are deleting
[[ "${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOP}" ]] && reverseArray LEVELS_REQUIRED

for LEVEL in "${LEVELS_REQUIRED[@]}"; do
  UNITS_LIST="${LEVEL^^}_UNITS_LIST"
  IFS="${DEPLOYMENT_UNIT_SEPARATORS}" read -ra UNITS <<< "${!UNITS_LIST}"

  # Reverse the order if we are deleting
  [[ "${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOP}" ]] && reverseArray UNITS

  # Manage the stacks individually in case of failure and becuase one can depend on the 
  # output of the previous one
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
done

# Update the code and credentials buckets if required
if [[ "${SYNC_BUCKETS}" == "true" ]]; then
  cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}
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

