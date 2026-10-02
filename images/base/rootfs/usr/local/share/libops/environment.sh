#!/usr/bin/env bash
# shellcheck shell=bash

function require_environment_variables {
    local name value missing=false

    for name in "$@"; do
        value=${!name-}
        if [ -z "${value}" ]; then
            echo "${name} must not be empty" >&2
            missing=true
        fi
    done
    if [ "${missing}" = "true" ]; then
        return 1
    fi
}
