#!/usr/bin/env bash
# GitHub exposes package inventory through gh api, but not Manage Actions access.
set -euo pipefail

if [ "${1:-}" = --help ]; then
  cat <<'HELP'
Usage: ci/package-access-migration.sh [--open]

Lists GHCR packages linked to lehigh-university-libraries/docker-builds.
Use --open to open their settings pages in your browser (requires Python 3).
Requires gh authenticated as a package admin with read:packages, and jq.

For EACH package, in this order:
  1. Under Manage Actions access, add buildkit with Admin access.
     Admin is needed by buildkit's scheduled package cleanup.
  2. Connect the package to buildkit; review inherited permissions.
  3. Confirm buildkit can publish, then remove docker-builds Actions access.

This script does not change access: GitHub's public API has no endpoint for
Manage Actions access. It cannot enumerate packages that grant docker-builds
Actions access but are linked to a different repository; review those manually.
All linked packages are listed, including base/go even though their source is
not imported. Save the output before changing repository links.
HELP
  exit 0
fi
if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != --open ]; }; then
  echo 'Usage: ci/package-access-migration.sh [--open]' >&2
  exit 2
fi
command -v gh >/dev/null
command -v jq >/dev/null
if [ "${1:-}" = --open ]; then command -v python3 >/dev/null; fi

org=lehigh-university-libraries
source_repo="$org/docker-builds"
# Verify both repositories before producing migration instructions.
gh api "repos/$source_repo" --silent
gh api "repos/$org/buildkit" --silent
inventory=$(gh api --paginate --slurp "orgs/$org/packages?package_type=container&per_page=100")
mapfile -t names < <(jq -r '.[][] | .name' <<<"$inventory")
printf 'PACKAGE\tSETTINGS\n'
for name in "${names[@]}"; do
  encoded=$(jq -rn --arg name "$name" '$name | @uri')
  package=$(gh api "orgs/$org/packages/container/$encoded")
  linked_repo=$(jq -r '.repository.full_name // ""' <<<"$package")
  if [ "$linked_repo" != "$source_repo" ]; then continue; fi
  url="https://github.com/orgs/$org/packages/container/$encoded/settings"
  printf '%s\t%s\n' "$name" "$url"
  if [ "${1:-}" = --open ]; then python3 -m webbrowser "$url"; fi
done
printf '\nAdd buildkit (Admin), verify publishing, then remove docker-builds in each package settings page.\n' >&2
printf 'No permissions were changed by this script. See --help for the full migration steps.\n' >&2
