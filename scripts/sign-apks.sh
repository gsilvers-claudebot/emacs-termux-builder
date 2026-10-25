#!/usr/bin/env bash
# Re-sign the Emacs and Termux APKs with a single key, so that they can
# share the com.termux user ID, and check that they really match.
#
# Usage: sign-apks.sh IN_DIR OUT_DIR
#
# Environment:
#   APKSIGNER      path to apksigner (required)
#   KEYSTORE       keystore file (required)
#   KEYSTORE_PASS  keystore password (required)
#   KEY_ALIAS      key alias (required)
#   KEY_PASS       key password (default: KEYSTORE_PASS)
#
# Every *.apk in IN_DIR is signed into OUT_DIR, dropping any
# "-unsigned" suffix from the file name.
set -euo pipefail

in=${1:?usage: sign-apks.sh IN_DIR OUT_DIR}
out=${2:?usage: sign-apks.sh IN_DIR OUT_DIR}
: "${APKSIGNER:?}" "${KEYSTORE:?}" "${KEYSTORE_PASS:?}" "${KEY_ALIAS:?}"
export KEYSTORE_PASS
export KEY_PASS=${KEY_PASS:-$KEYSTORE_PASS}

mkdir -p "$out"
shopt -s nullglob
apks=("$in"/*.apk)
[ ${#apks[@]} -gt 0 ] || { echo "No APKs in $in" >&2; exit 1; }

certs=()
for apk in "${apks[@]}"; do
  name=$(basename "$apk")
  name=${name/-unsigned/}
  "$APKSIGNER" sign \
    --ks "$KEYSTORE" --ks-pass env:KEYSTORE_PASS \
    --ks-key-alias "$KEY_ALIAS" --key-pass env:KEY_PASS \
    --out "$out/$name" "$apk"
  rm -f "$out/$name.idsig"
  cert=$("$APKSIGNER" verify --print-certs "$out/$name" \
           | sed -n 's/^Signer #1 certificate SHA-256 digest: //p')
  echo "$name: $cert"
  certs+=("$cert")
done

if [ "$(printf '%s\n' "${certs[@]}" | sort -u | wc -l)" -ne 1 ]; then
  echo "APKs ended up with different signing certificates" >&2
  exit 1
fi
echo "${certs[0]}" > "$out/.signing-cert-sha256"
