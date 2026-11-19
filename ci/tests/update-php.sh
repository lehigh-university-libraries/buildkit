#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for flavor in php83 php84; do
minor="8.${flavor: -1}"
mkdir -p "$tmp/ci" "$tmp/images/$flavor/build" "$tmp/bin"
cp "$root/ci/update-php.sh" "$tmp/ci/"
cp "$root/images/$flavor/build/APKBUILD" "$tmp/images/$flavor/build/"
cp "$root/images/$flavor/Dockerfile" "$tmp/images/$flavor/"
cat > "$tmp/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
for arg in "$@"; do
    if [[ "$arg" == *releases/index.php* ]]; then
        sum=$(printf archive | sha256sum | cut -d ' ' -f1)
        [[ "${BAD_CHECKSUM:-0}" == 0 ]] || sum=$(printf wrong | sha256sum | cut -d ' ' -f1)
        printf '{"source":[{"filename":"php-%s.99.tar.xz","sha256":"%s"}]}' "$minor" "$sum"
        exit
    fi
done
printf archive > "${@: -1}"
MOCK
chmod +x "$tmp/bin/curl"
export PATH="$tmp/bin:$PATH"
export minor
bash "$tmp/ci/update-php.sh" "$flavor" "$minor.99"
grep -q "^pkgver=$minor.99$" "$tmp/images/$flavor/build/APKBUILD"
grep -q "SOFTWARE_VERSION=$minor.99-r0" "$tmp/images/$flavor/Dockerfile"
sum=$(printf archive | sha512sum | cut -d ' ' -f1)
grep -q "^$sum  php-$minor.99.tar.xz$" "$tmp/images/$flavor/build/APKBUILD"
cp "$tmp/images/$flavor/build/APKBUILD" "$tmp/before"
if BAD_CHECKSUM=1 bash "$tmp/ci/update-php.sh" "$flavor" "$minor.99"; then exit 1; fi
cmp "$tmp/before" "$tmp/images/$flavor/build/APKBUILD"
for invalid in 8.5.0 "8x${flavor: -1}.99" "$minor.99RC1"; do
    if bash "$tmp/ci/update-php.sh" "$flavor" "$invalid"; then exit 1; fi
done
done
echo 'PHP updater checks passed'
