#!/usr/bin/env bash
# Build an arm64 Emacs APK that shares the com.termux user ID.
#
# Usage: build-emacs.sh EMACS_SRC_DIR OUT_DIR
#
# Environment:
#   ANDROID_HOME        Android SDK root (required)
#   ANDROID_NDK_HOME    Android NDK root (required, r27 or later)
#   ANDROID_API         android.jar API level (default 36)
#   BUILD_TOOLS         build-tools version (default 36.0.0)
#   MIN_SDK             minimum Android API level (default 29)
#   EMACS_DEBUG         "true" for a debuggable build (default false)
#   PORTS_DIR           where to unpack dependency ports (default ./ports)
set -euo pipefail

src=${1:?usage: build-emacs.sh EMACS_SRC_DIR OUT_DIR}
out=${2:?usage: build-emacs.sh EMACS_SRC_DIR OUT_DIR}
here=$(cd "$(dirname "$0")" && pwd)

: "${ANDROID_HOME:?ANDROID_HOME must be set}"
: "${ANDROID_NDK_HOME:?ANDROID_NDK_HOME must be set}"
api=${ANDROID_API:-36}
build_tools=${BUILD_TOOLS:-36.0.0}
min_sdk=${MIN_SDK:-29}
ports_dir=${PORTS_DIR:-$PWD/ports}

toolchain="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
android_jar="$ANDROID_HOME/platforms/android-$api/android.jar"
android_cc="$toolchain/bin/aarch64-linux-android$min_sdk-clang"
cxx_shared="$toolchain/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"

for f in "$android_jar" "$android_cc" "$cxx_shared" \
         "$ANDROID_HOME/build-tools/$build_tools/apksigner"; do
  [ -e "$f" ] || { echo "Missing $f" >&2; exit 1; }
done

ndk_path=$("$here/fetch-ports.sh" "$ports_dir")
echo "Dependency ports: $ndk_path"

debug_flag=--without-android-debug
[ "${EMACS_DEBUG:-false}" = true ] && debug_flag=--with-android-debug

cd "$src"
[ -x configure ] || ./autogen.sh
./configure \
  --with-android="$android_jar" \
  ANDROID_CC="$android_cc" \
  SDK_BUILD_TOOLS="$ANDROID_HOME/build-tools/$build_tools" \
  --with-shared-user-id=com.termux \
  "$debug_flag" \
  --with-ndk-path="$ndk_path" \
  --with-ndk-cxx-shared="$cxx_shared"

make -j"$(nproc)" all

mkdir -p "$out"
shopt -s nullglob
apks=(java/emacs-*-arm64-v8a.apk)
[ ${#apks[@]} -eq 1 ] || { echo "Expected one APK, found: ${apks[*]:-none}" >&2; exit 1; }
cp "${apks[0]}" "$out/"
echo "Built $out/$(basename "${apks[0]}")"
