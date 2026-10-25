#!/usr/bin/env bash
# Download the ndk-build ports of Emacs's dependencies from the
# "Android ports for GNU Emacs" SourceForge project, verify them against
# ports.sha256, and unpack them.  Each ports.sha256 line is
# "SHA256  FILE [URL]"; without a URL, FILE comes from SourceForge.
#
# Usage: fetch-ports.sh DEST_DIR
#
# Prints the space-separated list of unpacked port directories on
# stdout, suitable for configure's --with-ndk-path.
set -euo pipefail

dest=${1:?usage: fetch-ports.sh DEST_DIR}
here=$(cd "$(dirname "$0")/.." && pwd)
manifest="$here/ports.sha256"
base_url=${PORTS_BASE_URL:-https://downloads.sourceforge.net/project/android-ports-for-gnu-emacs}

mkdir -p "$dest/tarballs"
dest=$(cd "$dest" && pwd)

while read -r sum file url; do
  [ -z "$file" ] && continue
  tarball="$dest/tarballs/$file"
  if [ ! -f "$tarball" ] || ! echo "$sum  $tarball" | sha256sum -c --status; then
    echo "Downloading $file" >&2
    # SourceForge mirrors are occasionally flaky; retry a few times.
    curl -fsSL --retry 5 --retry-delay 10 --retry-all-errors \
      -o "$tarball" "${url:-$base_url/$file}"
  fi
  echo "$sum  $tarball" | sha256sum -c >&2
done < "$manifest"

dirs=()
while read -r _ file _; do
  [ -z "$file" ] && continue
  top=$(tar tzf "$dest/tarballs/$file" | awk -F/ 'NR == 1 { print $1 }')
  if [ ! -d "$dest/$top" ]; then
    tar xzf "$dest/tarballs/$file" -C "$dest"
  fi
  dirs+=("$dest/$top")
done < "$manifest"

echo "${dirs[*]}"
