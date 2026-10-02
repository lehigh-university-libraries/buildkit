#!/usr/bin/env bash
set -euo pipefail
root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
cat > "$work_dir/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  'api repos/lehigh-university-libraries/'*' --silent') ;;
  'api --paginate --slurp orgs/lehigh-university-libraries/packages?package_type=container&per_page=100')
    printf '%s' '[[{"name":"base"},{"name":"nested/image"}],[{"name":"unrelated"}]]' ;;
  'api orgs/lehigh-university-libraries/packages/container/base'|'api orgs/lehigh-university-libraries/packages/container/nested%2Fimage')
    printf '%s' '{"repository":{"full_name":"lehigh-university-libraries/docker-builds"}}' ;;
  'api orgs/lehigh-university-libraries/packages/container/unrelated')
    printf '%s' '{"repository":{"full_name":"lehigh-university-libraries/another-repo"}}' ;;
  *) echo "Unexpected API call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$work_dir/gh"
PATH="$work_dir:$PATH" bash "$root_dir/ci/package-access-migration.sh" > "$work_dir/result"
grep -Fq 'container/base/settings' "$work_dir/result"
grep -Fq 'container/nested%2Fimage/settings' "$work_dir/result"
if grep -Fq unrelated "$work_dir/result"; then exit 1; fi
