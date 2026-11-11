#!/usr/bin/env bash
# Usage: curl -fsSL https://raw.githubusercontent.com/lvvittor/macos/main/bootstrap.sh | bash
# Downloads the repo as a tarball, so it needs no git and no GitHub login.
set -euo pipefail

REPO="${REPO:-lvvittor/macos}"
REF="${REF:-main}"
DEST="$HOME/mac-setup"

rm -rf "$DEST"
mkdir -p "$DEST"
curl -fsSL "https://github.com/$REPO/archive/refs/heads/$REF.tar.gz" | tar -xz -C "$DEST" --strip-components=1
exec bash "$DEST/install.sh" "$@" </dev/tty
