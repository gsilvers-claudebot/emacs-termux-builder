#!/usr/bin/env bash
# Build an unsigned arm64 release APK of the Termux app (apt-android-7
# bootstrap, the default for the upstream release tags).
#
# Usage: build-termux.sh TERMUX_SRC_DIR OUT_DIR VERSION_TAG
set -euo pipefail

src=${1:?usage: build-termux.sh TERMUX_SRC_DIR OUT_DIR VERSION_TAG}
out=${2:?usage: build-termux.sh TERMUX_SRC_DIR OUT_DIR VERSION_TAG}
tag=${3:?usage: build-termux.sh TERMUX_SRC_DIR OUT_DIR VERSION_TAG}

mkdir -p "$out"
out=$(cd "$out" && pwd)
cd "$src"

# Read by app/build.gradle: split per ABI so the APK only carries the
# aarch64 bootstrap, and name the output after the release.
export TERMUX_SPLIT_APKS_FOR_RELEASE_BUILDS=1
export TERMUX_APK_VERSION_TAG="$tag"

./gradlew --no-daemon assembleRelease

apk_dir=app/build/outputs/apk/release
apk="$apk_dir/termux-app_${tag}_arm64-v8a.apk"
[ -f "$apk" ] || { echo "Missing $apk; found:" >&2; ls -la "$apk_dir" >&2; exit 1; }
cp "$apk" "$out/termux-app_${tag}_arm64-v8a-unsigned.apk"
echo "Built $out/termux-app_${tag}_arm64-v8a-unsigned.apk"
