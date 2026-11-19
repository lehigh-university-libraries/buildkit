#!/usr/bin/env bash
set -euo pipefail

# Called by Renovate with a flavor, or manually with a flavor and version.
cd "$(dirname "$0")/.."
flavor=${1:?Usage: update-php.sh php83|php84 [version]}
case "$flavor" in php83) minor=8.3 ;; php84) minor=8.4 ;; *) echo 'Expected php83 or php84' >&2; exit 1 ;; esac
version=${2:-$(sed -n 's/^pkgver=//p' "images/$flavor/build/APKBUILD")}
[[ "$version" =~ ^8[.]${flavor: -1}[.][0-9]+$ ]] || { echo "Expected a stable PHP $minor.x version" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --connect-timeout 10 --max-time 180 --retry 3 "https://www.php.net/releases/index.php?json&version=$version" > "$tmp/release.json"
sha=$(jq -er --arg file "php-$version.tar.xz" '.source[] | select(.filename == $file) | .sha256' "$tmp/release.json")
[[ "$sha" =~ ^[a-f0-9]{64}$ ]]
curl -fsSL --connect-timeout 10 --max-time 180 --retry 3 "https://www.php.net/distributions/php-$version.tar.xz" -o "$tmp/php.tar.xz"
printf '%s  %s\n' "$sha" "$tmp/php.tar.xz" | sha256sum -c -
sum=$(sha512sum "$tmp/php.tar.xz" | cut -d ' ' -f1)
sed -i -E \
    -e "s/^pkgver=.*/pkgver=$version/" \
    -e 's/^pkgrel=.*/pkgrel=0/' \
    -e "s/^[a-f0-9]{128}  php-[0-9.]+\.tar\.xz$/$sum  php-$version.tar.xz/" \
    "images/$flavor/build/APKBUILD"
sed -i -E "s/SOFTWARE_VERSION=[0-9.]+-r[0-9]+/SOFTWARE_VERSION=$version-r0/" "images/$flavor/Dockerfile"
