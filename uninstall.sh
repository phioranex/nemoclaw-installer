#!/usr/bin/env bash

set -Eeuo pipefail

REPO_URL="https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${REPO_URL}" | bash -s -- --uninstall "$@"
elif command -v wget >/dev/null 2>&1; then
  wget -qO- "${REPO_URL}" | bash -s -- --uninstall "$@"
else
  printf "error: curl or wget is required to run the uninstaller.\n" >&2
  exit 1
fi
