#!/bin/bash
# NemoClaw Installer — Official, Secure, Interactive
# ✅ Verifies GPG signature & SHA256 checksum
# ✅ Supports Linux/macOS/WSL | x86_64 / aarch64 / arm64
# ✅ Idempotent, safe, user-owned install (~/.local/bin)
# 🔗 Source: https://github.com/NVIDIA/nemoclaw
# 📜 Docs: https://docs.nvidia.com/nemoclaw/

set -euo pipefail

# --- CONFIG ---
NEMO_REPO="NVIDIA/nemoclaw"
NEMO_RELEASE_URL="https://api.github.com/repos/${NEMO_REPO}/releases/latest"
NEMO_KEY_URL="https://raw.githubusercontent.com/NVIDIA/nemoclaw/main/KEYS.asc"
INSTALL_DIR="${HOME}/.local/bin"
DEFAULT_INSTALL_PATH="${INSTALL_DIR}/nemoclaw"

# --- UTILS ---
log() { echo "✅ $1" >&2; }
warn() { echo "⚠️  $1" >&2; }
error() { echo "❌ $1" >&2; exit 1; }
prompt() { local d="${2:-N}"; read -rp "$1 [$d] " r; echo "${r:-$d}"; }

# portable fetch: prefer curl, fall back to wget
fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -sSL "$@"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$@"
  else
    error "curl or wget required to download assets."
  fi
}

# --- DETECT ARCH/OS ---
case "$(uname -s)" in
  Darwin) OS="darwin"; BIN_EXT="" ;;
  Linux)  OS="linux";  BIN_EXT="" ;;
  *) error "Unsupported OS: $(uname -s). Only macOS/Linux/WSL supported." ;;
esac

ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64)    ARCH_TAG="x86_64" ;;
  aarch64|arm64) ARCH_TAG="aarch64" ;;
  *) error "Unsupported architecture: ${ARCH}. Use x86_64 or ARM64." ;;
esac

BIN_NAME="nemoclaw-${OS}-${ARCH_TAG}"
log "Detected: ${OS}/${ARCH_TAG}"

# --- FETCH LATEST RELEASE ---
log "Fetching latest release info..."
RELEASE_JSON=$(fetch "${NEMO_RELEASE_URL}") ||
  error "Failed to fetch release info. Check internet/GitHub access."

DOWNLOAD_URL=$(echo "${RELEASE_JSON}" | grep -o '"browser_download_url": "[^"]*' | grep "${BIN_NAME}" | head -1 | cut -d'"' -f4) ||
  error "No ${BIN_NAME} binary found in latest release."

CHECKSUM_URL=$(echo "${RELEASE_JSON}" | grep -o '"browser_download_url": "[^"]*' | grep 'SHA256SUMS' | head -1 | cut -d'"' -f4) ||
  error "SHA256SUMS not found."

SIGNATURE_URL="${CHECKSUM_URL}.asc"

# --- DOWNLOAD ASSETS ---
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

log "Downloading ${BIN_NAME}..."
fetch "${DOWNLOAD_URL}" > "${TMP_DIR}/nemoclaw" ||
  error "Failed to download binary."

log "Downloading SHA256SUMS..."
fetch "${CHECKSUM_URL}" > "${TMP_DIR}/SHA256SUMS" ||
  error "Failed to download SHA256SUMS."

log "Downloading signature..."
fetch "${SIGNATURE_URL}" > "${TMP_DIR}/SHA256SUMS.asc" ||
  error "Failed to download signature."

# --- VERIFY SIGNATURE ---
log "Importing NVIDIA signing key..."
if command -v gpg >/dev/null 2>&1; then
  gpg --quiet --batch --yes --import <(fetch "${NEMO_KEY_URL}") 2>/dev/null ||
    warn "GPG key import failed. Signature checks may fail."
else
  warn "GPG not installed. Skipping key import; signature check will be skipped."
fi

if command -v gpg >/dev/null 2>&1; then
  if gpg --verify "${TMP_DIR}/SHA256SUMS.asc" "${TMP_DIR}/SHA256SUMS" 2>/dev/null; then
    log "✓ Signature verified."
  else
    error "Signature verification failed. Abort."
  fi
else
  warn "GPG not found. Skipping signature check (SHA256 only)."
fi

# --- VERIFY CHECKSUM ---
log "Verifying SHA256..."
if command -v sha256sum >/dev/null 2>&1; then
  if sha256sum -c "${TMP_DIR}/SHA256SUMS" --ignore-missing 2>/dev/null | grep -q "OK"; then
    log "✓ Binary checksum OK."
  else
    error "SHA256 verification failed."
  fi
elif command -v shasum >/dev/null 2>&1; then
  if shasum -a 256 -c "${TMP_DIR}/SHA256SUMS" 2>/dev/null | grep -q "OK"; then
    log "✓ Binary checksum OK."
  else
    error "SHA256 verification failed."
  fi
else
  warn "No sha256sum or shasum found; skipping checksum verification."
fi

# --- INSTALL LOCATION ---
log "Installing to ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

# --- INTERACTIVE PROMPTS ---
if [[ ! -f "${DEFAULT_INSTALL_PATH}" ]]; then
  # Fresh install → ask for custom path
  INSTALL_PATH=$(prompt "Install to ${DEFAULT_INSTALL_PATH}? [Y/n] " "Y")
  if [[ "${INSTALL_PATH}" =~ ^[yY][eE][sS]|[yY]$ ]]; then
    INSTALL_PATH="${DEFAULT_INSTALL_PATH}"
  else
    INSTALL_PATH=$(prompt "Enter full path (e.g., /usr/local/bin/nemoclaw): " "${DEFAULT_INSTALL_PATH}")
  fi
else
  # Already exists → confirm overwrite
  if prompt "nemoclaw already installed at ${DEFAULT_INSTALL_PATH}. Overwrite? [y/N] " "N" =~ ^[yY][eE][sS]|[yY]$; then
    INSTALL_PATH="${DEFAULT_INSTALL_PATH}"
  else
    error "Installation cancelled."
  fi
fi

# --- COPY & CHMOD ---
cp "${TMP_DIR}/nemoclaw" "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}"
if command -v realpath >/dev/null 2>&1; then
  INSTALLED_REALPATH=$(realpath "${INSTALL_PATH}")
elif command -v python3 >/dev/null 2>&1; then
  INSTALLED_REALPATH=$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "${INSTALL_PATH}")
else
  INSTALLED_REALPATH="${INSTALL_PATH}"
fi
log "✓ Installed: ${INSTALLED_REALPATH}"

# --- ADD TO PATH? ---
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
  if prompt "Add ${INSTALL_DIR} to your PATH? (required to run 'nemoclaw' globally) [Y/n] " "Y" =~ ^[yY][eE][sS]|[yY]$; then
    SHELL_RC=""
    [[ -f "${HOME}/.zshrc" ]] && SHELL_RC="${HOME}/.zshrc"
    [[ -f "${HOME}/.bashrc" ]] && SHELL_RC="${HOME}/.bashrc"
    [[ -z "${SHELL_RC}" ]] && SHELL_RC="${HOME}/.profile"

    if ! grep -q "export PATH=\"${INSTALL_DIR}:\$PATH\"" "${SHELL_RC}" 2>/dev/null; then
      echo "" >> "${SHELL_RC}"
      echo "# Added by NemoClaw installer" >> "${SHELL_RC}"
      echo "export PATH=\"${INSTALL_DIR}:\$PATH\"" >> "${SHELL_RC}"
      log "✓ Added to ${SHELL_RC}. Reload with: source ${SHELL_RC}"
    else
      log "✓ ${INSTALL_DIR} already in ${SHELL_RC}"
    fi
  else
    warn "Not added to PATH. Run '${INSTALL_PATH} --version' directly."
  fi
fi

# --- SUCCESS ---
echo ""
log "🎉 Installation complete!"
log "→ Run: nemoclaw --version"
log "→ Try: nemoclaw run --policy examples/safe-policy.yaml -- openclaw serve"
log ""
log "📚 Next steps:"
log "• View policies: https://docs.nvidia.com/nemoclaw/policies/"
log "• Example policy: https://github.com/NVIDIA/nemoclaw/blob/main/examples/safe-policy.yaml"
log "• Report issues: https://github.com/NVIDIA/nemoclaw/issues"