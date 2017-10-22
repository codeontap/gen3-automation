#!/bin/bash

# Automation framework common definitions
#
# This script is designed to be sourced into other scripts

. "${AUTOMATION_BASE_DIR}/utility.sh"
[[ -n "${GENERATION_DIR}" ]] && . "${GENERATION_DIR}/contextTree.sh"

# -- Repositories --

function save_repo() {
  local directory="$1"; shift
  local name="$1"; shift
  local message="$1"; shift
  local reference="$1"; shift
  local tag="$1"; shift
  ${AUTOMATION_DIR}/manageRepo.sh -p \
    -d "${directory}" \
    -l "${name}" \
    -m "${message}" \
    "${reference+-b ${reference}" \
    "${tag:+-t ${tag}"
}

function save_product_config() {
  local arguments=("$@")

  saveRepo "${PRODUCT_DIR}" "config" "${arguments[@]}"
}

function save_product_infrastructure() {
  local arguments=("$@")

  saveRepo "${PRODUCT_INFRASTRUCTURE_DIR}" "infrastructure" "${arguments[@]}"
}

# -- Context properties file --

function save_context_property() {
  local name="$1"; shift
  local value="$1"; shift
  
  [[ -n "${value}" ]] && local property_value="${value}" || local -n property_value="${value}"

  echo "${name}=${property_value}" >> ${AUTOMATION_DATA_DIR}/context.properties
}

function define_context_property() {
  local name="$1^^"; shift
  local value="$1"; shift
  local capitalisation="$1,,"; shift

  case "${capitalisation}" in
    lower)
      value="${value,,}"
      ;;
    upper)
      value="${value^^}"
      ;;
  esac
  
  declare -g ${name}="${value}"
  save_context_property "${name}" "${value}"
}

function save_gen3_dirs_in_context() {
  local prefix="$1"; shift

  local directories=(ROOT_DIR TENANT_DIR \
    ACCOUNT_DIR ACCOUNT_INFRASTRUCTURE_DIR ACCOUNT_APPSETTINGS_DIR ACCOUNT_CREDENTIALS_DIR \
    PRODUCT_DIR PRODUCT_INFRASTRUCTURE_DIR PRODUCT_APPSETTINGS_DIR PRODUCT_SOLUTIONS_DIR PRODUCT_CREDENTIALS_DIR \
    SEGMENT_DIR SEGMENT_APPSETTINGS_DIR SEGMENT_SOLUTIONS_DIR SEGMENT_CREDENTIALS_DIR)

  for directory in "${directories[@]}"; do 
    save_context_property "${directory}" "$(getGen3Env "${directory}" "${prefix}")"
  done

  return 0
}
