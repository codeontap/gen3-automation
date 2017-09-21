#!/bin/bash

# Utility Functions
#
# This script is designed to be sourced into other scripts

# -- Error handling  --

function message() {
    local LEVEL="${1}"; shift
    echo -e "\n(${LEVEL})" "$@"
}

function locationMessage() {
    echo "$@" "Are we in the right place?"
}

function cantProceedMessage() {
    echo "$@" "Nothing to do."
}

function debug() {
    [[ -n "${GENERATION_DEBUG}" ]] && message "Debug" "$@"
}

function trace() {
    message "Trace" "$@"
}

function info() {
    message "Info" "$@"
}

function warn() {
    message "Warning" "$@" >&2
}

function error() {
    message "Error" "$@" >&2
}

function fatal() {
    message "Fatal" "$@" >&2
    exit
}

function fatalOption() {
    fatal "Invalid option: \"-${1:-${OPTARG}}\""
}

function fatalOptionArgument() {
    fatal "Option \"-${1:-${OPTARG}}\" requires an argument"
}

function fatalCantProceed() {
    fatal $(cantProceedMessage "$@" )
}

function fatalLocation() {
    fatal $(locationMessage "$@")
}

function fatalDirectory() {
    fatalLocation "We don't appear to be in the ${1} directory."
}

function fatalMandatory() {
    fatal "Mandatory arguments missing. Check usage via -h option."
}



