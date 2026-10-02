#!/usr/bin/env bash

set -euo pipefail

export DOWNLOAD_LIBRARY_ONLY=true
# The first argument is the checked-in helper selected by the Go test fixture.
# shellcheck disable=SC1090
source "$1"
# These globals are consumed by the sourced unpack function.
# shellcheck disable=SC2034
STRIP=true
# shellcheck disable=SC2034
REMOVE=()
unpack "$2" "$3"
