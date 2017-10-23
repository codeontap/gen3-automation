#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Basic security setup
if [[ "${SETUP_CREDENTIALS}" == "true" ]]; then
  INFRASTRUCTURE_TAG="e${AUTOMATION_JOB_IDENTIFIER}-${SEGMENT}-segment-cmk"

  # First create the cmk
  ${AUTOMATION_DIR}/createTemplates.sh -l "segment" -u "cmk" -c "${INFRASTRUCTURE_TAG}"
  RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit

  ${AUTOMATION_DIR}/manageStacks.sh -l "segment" -u "cmk"
  RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit

  # Add the SSH key if required
  if [[ (! -f "${SEGMENT_CREDENTIALS_DIR}/aws-ssh-crt.pem") &&
        (! -f "${SEGMENT_CREDENTIALS_DIR}/aws-ssh-prv.pem") ]]; then
    pushd "${SEGMENT_DIR}" >/dev/null
    ${GENERATION_DIR}/addSSH.sh
    RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit

    # Encrypt the SSH key with the cmk
    ${GENERATION_DIR}/manageFileCrypto.sh -e -u aws-ssh-prv.pem
    RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit
    popd >/dev/null
  fi

  # All good - save the result
  MESSAGE="${DETAIL_MESSAGE}, level=segment, units=cmk"
  save_product_config \
    "${MESSAGE}" \
    "${PRODUCT_CONFIG_REFERENCE}" \
    "${INFRASTRUCTURE_TAG}"
  RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

  save_product_infrastructure \
    "${MESSAGE}" \
    "${PRODUCT_INFRASTRUCTURE_REFERENCE}" \
    "${INFRASTRUCTURE_TAG}"
  RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit
fi

# Process each template level
IFS="${DEPLOYMENT_UNIT_SEPARATORS}" read -ra LEVELS_REQUIRED <<< "${LEVELS}"
for LEVEL in "${LEVELS_REQUIRED[@]}"; do

  UNITS_LIST="${LEVEL^^}_UNITS_LIST"
  IFS="${DEPLOYMENT_UNIT_SEPARATORS}" read -ra UNITS <<< "${!UNITS_LIST}"

  # Manage the stacks individually in case of failure and becuase one can depend on the 
  # output of the previous one
  for CURRENT_DEPLOYMENT_UNIT in "${UNITS}"; do

    # A tag for the changes
    INFRASTRUCTURE_TAG="e${AUTOMATION_JOB_IDENTIFIER}-${SEGMENT}-${LEVEL}-${CURRENT_DEPLOYMENT_UNIT}"

    # Generate the template if required
    if [[ ("${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_UPDATE}") ||
             ("${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOPSTART}") ]]; then
      ${AUTOMATION_DIR}/createTemplates.sh -u "${CURRENT_DEPLOYMENT_UNIT}" -l "${LEVEL}" -c "${INFRASTRUCTURE_TAG}"
      RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit
  
    fi

    ${AUTOMATION_DIR}/manageStacks.sh -u "${CURRENT_DEPLOYMENT_UNIT}" -l "${LEVEL}"
    RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit
    
    # All good - save the result
    MESSAGE="${DETAIL_MESSAGE}, level=${LEVEL}, units=${CURRENT_DEPLOYMENT_UNIT}"
    save_product_config \
      "${MESSAGE}" \
      "${PRODUCT_CONFIG_REFERENCE}" \
      "${INFRASTRUCTURE_TAG}"
    RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

    save_product_infrastructure \
      "${MESSAGE}" \
      "${PRODUCT_INFRASTRUCTURE_REFERENCE}" \
      "${INFRASTRUCTURE_TAG}"
    RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit
  done
done

# Update the code and credentials buckets if required
if [[ "${SYNC_BUCKETS}" == "true" ]]; then
  cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}
  ${GENERATION_DIR}/syncAccountBuckets.sh -a ${ACCOUNT}
fi



