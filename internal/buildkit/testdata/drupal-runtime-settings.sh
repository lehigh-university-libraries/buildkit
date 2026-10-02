#!/usr/bin/env bash

set -euo pipefail

export DRUPAL_SETUP_LIBRARY_ONLY=true
export LIBOPS_DATABASE_LIBRARY="$1"
export LIBOPS_ENVIRONMENT_LIBRARY="$2"
export DRUPAL_ROOT="$4"
export DRUPAL_DEFAULT_SETTINGS_FILE="$5"
export DRUPAL_DEFAULT_SUBDIR=default
# The third argument is the checked-in Drupal setup helper under test.
# shellcheck disable=SC1090
source "$3"

ensure_runtime_settings
ensure_runtime_settings
test "$(grep -Fc "require '/etc/drupal/libops.settings.php';" "$4/web/sites/default/settings.php")" -eq 1
grep -Fq "file_private_path" "$4/web/sites/default/settings.php"
