#!/usr/bin/env bash
# Generate a private signing key for your Emacs + Termux builds and
# store it as GitHub Actions secrets on this repository.
#
# Usage: make-keystore.sh [KEYSTORE_FILE]
#
# Needs keytool (from any JDK) and an authenticated `gh`.  Keep the
# keystore file somewhere safe and offline: if you lose it you can never
# publish an update that installs over your existing apps, and if
# someone else gets it they can.
set -euo pipefail

ks=${1:-emacs-termux.jks}
alias=emacs-termux
[ -e "$ks" ] && { echo "$ks already exists; refusing to overwrite" >&2; exit 1; }

pass=$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32)

keytool -genkeypair -v \
  -keystore "$ks" -storetype PKCS12 \
  -storepass "$pass" -keypass "$pass" \
  -alias "$alias" -keyalg RSA -keysize 4096 -validity 36500 \
  -dname "CN=emacs-termux-builder"

base64 -w0 "$ks" | gh secret set SIGNING_KEYSTORE_BASE64
printf %s "$pass" | gh secret set SIGNING_KEYSTORE_PASSWORD
printf %s "$alias" | gh secret set SIGNING_KEY_ALIAS

echo
echo "Created $ks and set the SIGNING_* secrets on $(gh repo view --json nameWithOwner -q .nameWithOwner)."
echo "Keystore password (store it with the keystore, e.g. in a password manager):"
echo "  $pass"
