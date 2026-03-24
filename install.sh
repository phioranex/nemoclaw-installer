#!/usr/bin/env bash

set -Eeuo pipefail

REPO_URL="https://github.com/phioranex/nemoclaw-installer"
OPENCLAW_INSTALL_URL="https://openclaw.ai/install.sh"
MIN_NODE_MAJOR=22
MIN_NODE_MINOR=16
RECOMMENDED_NODE_MAJOR=24

COLOR_RESET="\033[0m"
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BLUE="\033[34m"
COLOR_CYAN="\033[36m"
COLOR_BOLD="\033[1m"
COLOR_DIM="\033[2m"

if [[ ! -t 1 ]]; then
  COLOR_RESET=""
  COLOR_RED=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_BLUE=""
  COLOR_CYAN=""
  COLOR_BOLD=""
  COLOR_DIM=""
fi

log() {
  printf "%b\n" "${COLOR_BLUE}==>${COLOR_RESET} $*"
}

success() {
  printf "%b\n" "${COLOR_GREEN}==>${COLOR_RESET} $*"
}

warn() {
  printf "%b\n" "${COLOR_YELLOW}warning:${COLOR_RESET} $*"
}

die() {
  printf "%b\n" "${COLOR_RED}error:${COLOR_RESET} $*" >&2
  exit 1
}

line() {
  printf "%b\n" "${COLOR_DIM}------------------------------------------------------------${COLOR_RESET}"
}

headline() {
  line
  printf "%b\n" "${COLOR_BOLD}$*${COLOR_RESET}"
  line
}

feature() {
  printf "%b\n" "  ${COLOR_CYAN}•${COLOR_RESET} $*"
}

step() {
  printf "%b\n" "${COLOR_CYAN}[$1/${TOTAL_STEPS}]${COLOR_RESET} $2"
}

print_banner() {
  cat <<'EOF'
 _   _                        ____ _                    
| \ | | ___ _ __ ___   ___  / ___| | __ ___      __    
|  \| |/ _ \ '_ ` _ \ / _ \| |   | |/ _` \ \ /\ / /    
| |\  |  __/ | | | | | (_) | |___| | (_| |\ V  V /     
|_| \_|\___|_| |_| |_|\___/ \____|_|\__,_| \_/\_/      

  _           _        _ _           
 (_)_ __  ___| |_ __ _| | | ___ _ __ 
 | | '_ \/ __| __/ _` | | |/ _ \ '__|
 | | | | \__ \ || (_| | | |  __/ |   
 |_|_| |_|___/\__\__,_|_|_|\___|_|   

  Community one-line installer for a NemoClaw-style setup
EOF
}

usage() {
  cat <<EOF
Usage: bash install.sh [options]

Options:
  --yes, -y         Non-interactive mode where possible
  --skip-onboard    Install OpenClaw but do not start onboarding
  --uninstall       Remove OpenClaw, its service, and common local data
  --help, -h        Show this help text

Repo: ${REPO_URL}
EOF
}

NONINTERACTIVE=0
SKIP_ONBOARD=0
UNINSTALL_MODE=0
TOTAL_STEPS=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)
      NONINTERACTIVE=1
      ;;
    --skip-onboard|--no-onboard)
      SKIP_ONBOARD=1
      ;;
    --uninstall)
      UNINSTALL_MODE=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift
done

SUDO=""
OS=""

trap 'die "Installation stopped unexpectedly. Scroll up for the failing step."' ERR

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

need_sudo() {
  [[ "${EUID:-$(id -u)}" -ne 0 ]]
}

setup_sudo() {
  if need_sudo; then
    require_cmd sudo || die "'sudo' is required to install system packages."
    SUDO="sudo"
  fi
}

run_cmd() {
  log "$*"
  "$@"
}

run_root() {
  log "$*"
  if [[ -n "$SUDO" ]]; then
    $SUDO "$@"
  else
    "$@"
  fi
}

detect_os() {
  case "$(uname -s)" in
    Darwin)
      OS="macos"
      ;;
    Linux)
      OS="linux"
      ;;
    *)
      die "Unsupported OS: $(uname -s). This installer supports macOS and Linux."
      ;;
  esac
}

node_version_ok() {
  if ! require_cmd node; then
    return 1
  fi

  local raw major minor
  raw="$(node -v | sed 's/^v//')"
  major="${raw%%.*}"
  minor="$(printf '%s' "$raw" | cut -d. -f2)"

  if (( major > MIN_NODE_MAJOR )); then
    return 0
  fi

  if (( major == MIN_NODE_MAJOR && minor >= MIN_NODE_MINOR )); then
    return 0
  fi

  return 1
}

show_intro() {
  clear 2>/dev/null || true
  print_banner
  headline "Beginner-friendly setup for a safer OpenClaw workflow"
  cat <<EOF

${COLOR_BOLD}What this script does${COLOR_RESET}
EOF
  feature "installs missing beginner-unfriendly system dependencies"
  feature "installs or upgrades Node.js when needed"
  feature "runs the public OpenClaw installer as the available base runtime"
  feature "leaves you with next steps for onboarding and safer setup"
  cat <<EOF

${COLOR_BOLD}What this script is not${COLOR_RESET}
EOF
  feature "not an official NVIDIA installer"
  feature "not a replacement for reading security guidance before enabling risky skills"
  cat <<EOF

Public context as of March 24, 2026:
- NVIDIA announced NemoClaw on March 22, 2026 as a security/privacy layer for OpenClaw.
- The public install flow available today is still the OpenClaw installer at ${OPENCLAW_INSTALL_URL}

EOF
}

confirm() {
  local prompt="$1"

  if (( NONINTERACTIVE == 1 )); then
    return 0
  fi

  read -r -p "$prompt [Y/n] " reply
  reply="${reply:-Y}"
  [[ "$reply" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]
}

show_install_overview() {
  TOTAL_STEPS=3
  headline "Installation plan"
  feature "Step 1: detect your OS and install missing tools"
  feature "Step 2: make sure Node.js is new enough"
  feature "Step 3: install OpenClaw and hand over next steps"
  printf "\n"
}

show_uninstall_overview() {
  TOTAL_STEPS=4
  headline "Removal plan"
  feature "Step 1: stop and uninstall the OpenClaw gateway if present"
  feature "Step 2: remove local state, workspace, and common service files"
  feature "Step 3: uninstall the global OpenClaw CLI"
  feature "Step 4: confirm what was removed and what to check manually"
  printf "\n"
}

install_homebrew() {
  require_cmd curl || die "'curl' is required to install Homebrew."
  require_cmd bash || die "'bash' is required to install Homebrew."

  if ! confirm "Homebrew is not installed. Install it automatically?"; then
    die "Homebrew is required on macOS for this automated path."
  fi

  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_brew() {
  if require_cmd brew; then
    return 0
  fi

  install_homebrew
  require_cmd brew || die "Homebrew installation completed, but 'brew' is still not available in PATH."
}

install_macos_prereqs() {
  ensure_brew
  run_cmd brew update
  run_cmd brew install git curl

  if ! node_version_ok; then
    run_cmd brew install node@24
    if [[ -d "$(brew --prefix node@24)/bin" ]]; then
      export PATH="$(brew --prefix node@24)/bin:$PATH"
    fi
  fi
}

linux_pkg_manager() {
  if require_cmd apt-get; then
    echo "apt"
  elif require_cmd dnf; then
    echo "dnf"
  elif require_cmd yum; then
    echo "yum"
  elif require_cmd pacman; then
    echo "pacman"
  elif require_cmd zypper; then
    echo "zypper"
  else
    echo ""
  fi
}

install_linux_prereqs() {
  local pm
  pm="$(linux_pkg_manager)"
  [[ -n "$pm" ]] || die "No supported package manager found. Please install git, curl, and Node.js manually."

  case "$pm" in
    apt)
      run_root apt-get update
      run_root apt-get install -y ca-certificates curl git build-essential
      if ! node_version_ok; then
        run_cmd bash -c "$(curl -fsSL https://deb.nodesource.com/setup_24.x)"
        run_root apt-get install -y nodejs
      fi
      ;;
    dnf)
      run_root dnf install -y ca-certificates curl git gcc-c++ make
      if ! node_version_ok; then
        run_root dnf module disable -y nodejs || true
        run_cmd bash -c "$(curl -fsSL https://rpm.nodesource.com/setup_24.x)"
        run_root dnf install -y nodejs
      fi
      ;;
    yum)
      run_root yum install -y ca-certificates curl git gcc-c++ make
      if ! node_version_ok; then
        run_cmd bash -c "$(curl -fsSL https://rpm.nodesource.com/setup_24.x)"
        run_root yum install -y nodejs
      fi
      ;;
    pacman)
      run_root pacman -Sy --noconfirm curl git base-devel nodejs npm
      ;;
    zypper)
      run_root zypper --non-interactive install curl git gcc-c++ make nodejs24 npm24 || \
        run_root zypper --non-interactive install curl git gcc-c++ make nodejs npm
      ;;
  esac
}

ensure_requirements() {
  step 1 "Preparing your machine"
  detect_os
  setup_sudo

  case "$OS" in
    macos)
      install_macos_prereqs
      ;;
    linux)
      install_linux_prereqs
      ;;
  esac

  require_cmd curl || die "'curl' is still missing after dependency installation."
  require_cmd git || die "'git' is still missing after dependency installation."
  require_cmd node || die "'node' is still missing after dependency installation."
  require_cmd npm || die "'npm' is still missing after dependency installation."

  if ! node_version_ok; then
    die "Node.js $(node -v) is too old. Please install Node ${MIN_NODE_MAJOR}.${MIN_NODE_MINOR}+ or Node ${RECOMMENDED_NODE_MAJOR}."
  fi
}

install_openclaw() {
  local flags=()

  if (( SKIP_ONBOARD == 1 )); then
    flags+=(--no-onboard)
  fi

  step 3 "Installing OpenClaw"
  log "Running the public OpenClaw installer"
  curl -fsSL "${OPENCLAW_INSTALL_URL}" | bash -s -- "${flags[@]}"
}

remove_path_if_exists() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    log "Removing $target"
    rm -rf "$target"
  fi
}

remove_openclaw_service() {
  step 1 "Stopping and removing the OpenClaw gateway"

  if require_cmd openclaw; then
    if openclaw uninstall --all --yes --non-interactive; then
      success "OpenClaw uninstall command completed."
      return 0
    fi

    warn "Built-in uninstall did not complete cleanly. Falling back to manual cleanup."
    openclaw gateway stop || true
    openclaw gateway uninstall || true
  else
    warn "'openclaw' command not found. Using manual cleanup only."
  fi

  case "${OS}" in
    macos)
      launchctl bootout "gui/${UID}/ai.openclaw.gateway" >/dev/null 2>&1 || true
      remove_path_if_exists "${HOME}/Library/LaunchAgents/ai.openclaw.gateway.plist"
      remove_path_if_exists "${HOME}/Library/LaunchAgents/com.openclaw.gateway.plist"
      ;;
    linux)
      if require_cmd systemctl; then
        systemctl --user disable --now openclaw-gateway.service >/dev/null 2>&1 || true
        remove_path_if_exists "${HOME}/.config/systemd/user/openclaw-gateway.service"
        systemctl --user daemon-reload >/dev/null 2>&1 || true
      fi
      ;;
  esac
}

remove_openclaw_data() {
  step 2 "Removing local state and workspace"
  remove_path_if_exists "${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
  remove_path_if_exists "${HOME}/.openclaw-default"
  remove_path_if_exists "${HOME}/.openclaw/workspace"
  remove_path_if_exists "${HOME}/.config/openclaw"
}

remove_openclaw_cli() {
  step 3 "Removing the global OpenClaw CLI"

  if require_cmd npm; then
    npm rm -g openclaw >/dev/null 2>&1 || warn "Global npm uninstall did not complete cleanly."
  else
    warn "'npm' is not available, so the global CLI could not be removed automatically."
  fi

  if [[ "$OS" == "macos" ]]; then
    remove_path_if_exists "/Applications/OpenClaw.app"
  fi
}

print_uninstall_summary() {
  step 4 "Review"
  cat <<EOF

${COLOR_GREEN}${COLOR_BOLD}Removal complete.${COLOR_RESET}

What was cleaned up:
EOF
  feature "gateway service when present"
  feature "default state and workspace locations"
  feature "global npm-installed OpenClaw CLI when npm was available"
  cat <<EOF

What may still need manual removal:
EOF
  feature "profile-specific state dirs such as ~/.openclaw-work or ~/.openclaw-lab"
  feature "custom config paths set through OPENCLAW_CONFIG_PATH"
  feature "custom workspaces outside the default OpenClaw state dir"
  printf "\n"
}

print_post_install() {
  headline "You are ready to launch"
  cat <<EOF

${COLOR_GREEN}${COLOR_BOLD}NemoClaw-style bootstrap complete.${COLOR_RESET}

Installed base runtime:
- OpenClaw CLI via the public installer

Recommended next steps:
1. Run ${COLOR_CYAN}openclaw --version${COLOR_RESET} to confirm the CLI is available.
2. Run ${COLOR_CYAN}openclaw doctor${COLOR_RESET} to catch config issues early.
3. If onboarding was skipped, run ${COLOR_CYAN}openclaw onboard --install-daemon${COLOR_RESET}.
4. Before enabling skills with terminal or file access, isolate this agent on a dedicated machine, VM, or low-privilege account.

Helpful links:
- OpenClaw install docs: https://docs.openclaw.ai/install/index
- OpenClaw security guidance: https://docs.openclaw.ai
- This installer repo: ${REPO_URL}

EOF
}

run_uninstall() {
  detect_os
  show_uninstall_overview

  if ! confirm "Continue and remove OpenClaw plus common local data?"; then
    die "Removal cancelled by user."
  fi

  remove_openclaw_service
  remove_openclaw_data
  remove_openclaw_cli
  print_uninstall_summary
  success "Everything requested has been removed."
}

main() {
  show_intro

  if (( UNINSTALL_MODE == 1 )); then
    run_uninstall
    exit 0
  fi

  show_install_overview

  if ! confirm "Continue with the automated install?"; then
    die "Installation cancelled by user."
  fi

  ensure_requirements
  step 2 "Checking your Node.js runtime"
  success "Node.js $(node -v) is ready."
  install_openclaw
  print_post_install
  success "All done."
}

main "$@"
