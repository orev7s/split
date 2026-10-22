#!/bin/sh
set -eu

cd "$(dirname "$0")"
# Derive from module.prop: a hardcoded string here shipped v1.0.0 names for
# months after the module itself moved on.
VERSION=$(sed -n 's/^version=//p' module/module.prop | tr -d '\r')
[ -n "$VERSION" ] || { echo "no version in module/module.prop" >&2; exit 1; }
OUT="Split-Module-${VERSION}.zip"

rm -f "$OUT"

# Normalise line endings: CRLF silently breaks module scripts.
for f in module/customize.sh module/service.sh module/uninstall.sh module/bin/splitctl \
         module/module.prop module/META-INF/com/google/android/update-binary; do
    tr -d '\r' < "$f" > "$f.tmp"
    mv "$f.tmp" "$f"
done

cd module
zip -r "../${OUT}" . -x '.*' -x '*/.DS_Store'
cd ..

echo "built ${OUT}"
unzip -l "${OUT}"
