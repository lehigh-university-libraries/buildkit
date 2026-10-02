#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
mkdir -p "$work_dir/bin" "$work_dir/images"
cp -R "$root_dir/images/actions-runner" "$root_dir/images/islandora" "$root_dir/images/php83" "$root_dir/images/php84" "$work_dir/images/"

# Model release downloads locally: each URL has distinct, deterministic bytes.
cat > "$work_dir/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
if [ "${FAIL_DOWNLOAD:-false}" = true ]; then exit 22; fi
while [ "$#" -gt 0 ]; do
  if [ "$1" = --output ]; then output=$2; shift; fi
  url=$1
  shift
done
printf '%s' "$url" > "$output"
CURL
chmod +x "$work_dir/bin/curl"
export PATH="$work_dir/bin:$PATH"
cd "$work_dir"

verify_sha() {
  local file=$1 arg=$2 url=$3 expected
  expected=$(printf '%s' "$url" | shasum -a 256 | awk '{print $1}')
  grep -Eq "${arg}=\"${expected}\"" "$file"
}

bash "$root_dir/ci/update-sha.sh" gha-runner 2.334.0 2.335.0 ''
verify_sha images/actions-runner/Dockerfile RUNNER_AMD64_SHA256 'https://github.com/actions/runner/releases/download/v2.335.0/actions-runner-linux-x64-2.335.0.tar.gz'
verify_sha images/actions-runner/Dockerfile RUNNER_ARM64_SHA256 'https://github.com/actions/runner/releases/download/v2.335.0/actions-runner-linux-arm64-2.335.0.tar.gz'
grep -qx 'GitHub Actions runner version 2.335.0.' images/actions-runner/README.md

bash "$root_dir/ci/update-sha.sh" crosswalk 0.3.9 0.4.0 ''
verify_sha images/islandora/Dockerfile CROSSWALK_AMD64_SHA256 'https://github.com/lehigh-university-libraries/crosswalk/releases/download/v0.4.0/crosswalk_Linux_x86_64.tar.gz'
verify_sha images/islandora/Dockerfile CROSSWALK_ARM64_SHA256 'https://github.com/lehigh-university-libraries/crosswalk/releases/download/v0.4.0/crosswalk_Linux_arm64.tar.gz'

commit=0123456789abcdef0123456789abcdef01234567
bash "$root_dir/ci/update-sha.sh" islandora-workbench simple-field-json simple-field-json "$commit"
verify_sha images/actions-runner/Dockerfile WORKBENCH_SHA256 "https://github.com/lehigh-university-libraries/islandora_workbench/archive/${commit}.tar.gz"

bash "$root_dir/ci/update-sha.sh" custom-composer 2.10.3 2.11.0 ''
for image in actions-runner php83 php84; do
  verify_sha "images/$image/Dockerfile" COMPOSER_SHA256 'https://getcomposer.org/download/2.11.0/composer.phar'
done

before=$(shasum -a 256 images/actions-runner/Dockerfile)
if FAIL_DOWNLOAD=true bash "$root_dir/ci/update-sha.sh" gha-runner 2.335.0 2.336.0 ''; then
  echo 'Failed download unexpectedly succeeded' >&2
  exit 1
fi
if bash "$root_dir/ci/update-sha.sh" islandora-workbench simple-field-json simple-field-json ''; then
  echo 'Missing Workbench digest unexpectedly succeeded' >&2
  exit 1
fi
test "$before" = "$(shasum -a 256 images/actions-runner/Dockerfile)"
