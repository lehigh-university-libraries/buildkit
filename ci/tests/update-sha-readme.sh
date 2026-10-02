#!/usr/bin/env bash

set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "${work_dir}"' EXIT

# shellcheck disable=SC1090
UPDATE_SHA_LIBRARY_ONLY=true source "${root_dir}/ci/update-sha.sh" test 1.2.3 2.0.0 ignored

readme="${work_dir}/README.md"
printf '%s\n' 'Docker image version 1.2.3.' >"${readme}"
update_readme "${readme}" 1.2.3 2.0.0
grep -qx 'Docker image version 2.0.0.' "${readme}"

printf '%s\n' 'Docker image version 9.9.9.' >"${readme}"
if update_readme "${readme}" 1.2.3 2.0.0; then
  echo "Missing README source version unexpectedly succeeded" >&2
  exit 1
fi

printf '%s\n' 'First 1.2.3.' 'Second 1.2.3.' >"${readme}"
if update_readme "${readme}" 1.2.3 2.0.0; then
  echo "Ambiguous README source version unexpectedly succeeded" >&2
  exit 1
fi
