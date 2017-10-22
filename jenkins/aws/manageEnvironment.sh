#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Process each template level
IFS="${DEPLOYMENT_UNIT_SEPARATORS}" read -ra LEVELS_REQUIRED <<< "${LEVELS}"
for LEVEL in "${LEVELS_REQUIRED[@]}"; do

  UNITS_LIST="REQUIRED_${LEVEL^^}_UNITS"
  IFS="${DEPLOYMENT_UNIT_SEPARATORS}" read -ra UNITS <<< "${!UNITS_LIST}"
  
  # Generate the template if required
  if [[ ("${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_UPDATE}") ||
           ("${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOPSTART}") ]]; then
    ${AUTOMATION_DIR}/createTemplates.sh -u "${UNITS[*]}" -l "${LEVEL}"
    RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit

    save_product_config \
      "Stack changes as a result of applying ${DEPLOYMENT_MODE} mode at the ${LEVEL} level stack of the ${SEGMENT} segment for the following units (${UNITS_LIST})"
    RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

  fi

  # Manage the stacks individually in case of failure
  for CURRENT_DEPLOYMENT_UNIT in "${UNITS}"; do
    ${AUTOMATION_DIR}/manageStacks -u "${CURRENT_DEPLOYMENT_UNIT}" -l "${LEVEL}"
    RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit

    save_product_infrastructure \
      "Stack changes as a result of applying ${DEPLOYMENT_MODE} mode at the ${LEVEL} level stack of the ${SEGMENT} segment for the ${CURRENT_DEPLOYMENT_UNIT} unit"
    RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit
  done
done

# Update the code and credentials buckets if required
if [[ "${SYNC_BUCKETS}" == "true" ]]; then
  cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}
  ${GENERATION_DIR}/syncAccountBuckets.sh -a ${ACCOUNT}
fi



