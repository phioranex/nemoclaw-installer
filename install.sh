#!/usr/bin/env bash

set -Eeuo pipefail

REPO_URL="https://github.com/phioranex/nemoclaw-installer"
NEMOCLAW_INSTALL_URL="https://www.nvidia.com/nemoclaw.sh"
NEMOCLAW_UNINSTALL_URL="https://raw.githubusercontent.com/NVIDIA/NemoClaw/refs/heads/main/uninstall.sh"
OPENSHELL_INSTALL_URL="https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh"
OPENSHELL_LATEST_RELEASE_URL="https://github.com/NVIDIA/OpenShell/releases/latest"
MIN_NODE_MAJOR=20
MIN_NPM_MAJOR=10
RECOMMENDED_NODE_MAJOR=24
FALLBACK_OPENSHELL_VERSION="v0.0.14"

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

print_block() {
  printf "%b" "$1"
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

  Community one-line installer for NVIDIA NemoClaw
EOF
}

usage() {
  cat <<EOF
Usage: bash install.sh [options]

Options:
  --yes, -y            Non-interactive mode where possible
  --skip-onboard       Install the nemoclaw CLI only, then stop
  --uninstall          Run the official NemoClaw uninstaller
  --target VALUE       Uninstall target: nemoclaw, openclaw, or both
  --keep-openshell     Preserve the openshell binary during uninstall
  --delete-models      Remove Ollama models during uninstall
  --help, -h           Show this help text

Repo: ${REPO_URL}
EOF
}

NONINTERACTIVE=0
SKIP_ONBOARD=0
UNINSTALL_MODE=0
KEEP_OPENSHELL=0
DELETE_MODELS=0
TOTAL_STEPS=4
SUDO=""
OS=""
UNINSTALL_TARGET="ask"

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
    --target)
      shift
      [[ $# -gt 0 ]] || die "--target requires one of: nemoclaw, openclaw, both"
      UNINSTALL_TARGET="$1"
      ;;
    --keep-openshell)
      KEEP_OPENSHELL=1
      ;;
    --delete-models)
      DELETE_MODELS=1
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

trap 'die "Installation stopped unexpectedly. Scroll up for the failing step."' ERR

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

detect_shell_rc() {
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL:-}" == *"zsh" ]]; then
    echo "${HOME}/.zshrc"
  elif [[ -n "${BASH_VERSION:-}" ]] || [[ "${SHELL:-}" == *"bash" ]]; then
    echo "${HOME}/.bashrc"
  else
    echo "${HOME}/.profile"
  fi
}

ensure_line_in_file() {
  local file="$1"
  local line_text="$2"

  touch "$file"

  if ! grep -Fqx "$line_text" "$file" 2>/dev/null; then
    printf "\n%s\n" "$line_text" >> "$file"
    success "Updated $file so NemoClaw works in new terminals."
  fi
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

confirm() {
  local prompt="$1"

  if (( NONINTERACTIVE == 1 )); then
    return 0
  fi

  read -r -p "$prompt [Y/n] " reply
  reply="${reply:-Y}"
  [[ "$reply" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]
}

warn_about_github_token() {
  if [[ -n "${GH_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]]; then
    warn "Detected GH_TOKEN or GITHUB_TOKEN in the environment."
    warn "If the OpenShell installer fails with 'HTTP 401: Bad credentials', unset those variables and rerun."
  fi
}

latest_openshell_version() {
  local latest_url latest_tag

  latest_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "${OPENSHELL_LATEST_RELEASE_URL}" 2>/dev/null || true)"
  latest_tag="${latest_url##*/}"

  if [[ -n "$latest_tag" && "$latest_tag" == v* ]]; then
    printf "%s\n" "$latest_tag"
  else
    printf "%s\n" "${FALLBACK_OPENSHELL_VERSION}"
  fi
}

normalize_uninstall_target() {
  case "$1" in
    nemoclaw|nemo)
      printf "nemoclaw\n"
      ;;
    openclaw|open)
      printf "openclaw\n"
      ;;
    both|all)
      printf "both\n"
      ;;
    ask|"")
      printf "ask\n"
      ;;
    *)
      die "Unknown uninstall target '$1'. Use nemoclaw, openclaw, or both."
      ;;
  esac
}

choose_uninstall_target() {
  if (( NONINTERACTIVE == 1 )); then
    printf "both\n"
    return 0
  fi

  print_block "
${COLOR_BOLD}What do you want to remove?${COLOR_RESET}
  1. NemoClaw only
  2. OpenClaw only
  3. Both NemoClaw and OpenClaw

"

  while true; do
    read -r -p "Select 1, 2, or 3 [3]: " choice
    choice="${choice:-3}"
    case "$choice" in
      1) printf "nemoclaw\n"; return 0 ;;
      2) printf "openclaw\n"; return 0 ;;
      3) printf "both\n"; return 0 ;;
      *) warn "Please choose 1, 2, or 3." ;;
    esac
  done
}

node_version_ok() {
  if ! require_cmd node; then
    return 1
  fi

  local raw major
  raw="$(node -v | sed 's/^v//')"
  major="${raw%%.*}"
  (( major >= MIN_NODE_MAJOR ))
}

npm_version_ok() {
  if ! require_cmd npm; then
    return 1
  fi

  local raw major
  raw="$(npm -v)"
  major="${raw%%.*}"
  (( major >= MIN_NPM_MAJOR ))
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

persist_macos_node_path() {
  local node24_bin shell_rc

  [[ "$OS" == "macos" ]] || return 0
  require_cmd brew || return 0

  node24_bin="$(brew --prefix node@24 2>/dev/null)/bin"
  [[ -d "$node24_bin" ]] || return 0

  shell_rc="$(detect_shell_rc)"
  ensure_line_in_file "$shell_rc" "export PATH=\"${node24_bin}:\$PATH\""
}

persist_npm_global_bin() {
  local npm_prefix npm_bin shell_rc

  require_cmd npm || return 0
  npm_prefix="$(npm prefix -g 2>/dev/null || true)"
  [[ -n "$npm_prefix" ]] || return 0

  npm_bin="${npm_prefix}/bin"
  [[ -d "$npm_bin" ]] || return 0

  case ":$PATH:" in
    *":${npm_bin}:"*)
      return 0
      ;;
  esac

  shell_rc="$(detect_shell_rc)"
  ensure_line_in_file "$shell_rc" "export PATH=\"${npm_bin}:\$PATH\""
  export PATH="${npm_bin}:$PATH"
}

install_macos_prereqs() {
  ensure_brew
  run_cmd brew update
  run_cmd brew install curl git

  if ! node_version_ok || ! npm_version_ok; then
    run_cmd brew install node@24
    export PATH="$(brew --prefix node@24)/bin:$PATH"
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
  [[ -n "$pm" ]] || die "No supported package manager found. Please install curl, git, Node.js, npm, and Docker manually."

  case "$pm" in
    apt)
      run_root apt-get update
      run_root apt-get install -y ca-certificates curl git build-essential
      if ! node_version_ok || ! npm_version_ok; then
        run_cmd bash -c "$(curl -fsSL https://deb.nodesource.com/setup_24.x)"
        run_root apt-get install -y nodejs
      fi
      ;;
    dnf)
      run_root dnf install -y ca-certificates curl git gcc-c++ make
      if ! node_version_ok || ! npm_version_ok; then
        run_root dnf module disable -y nodejs || true
        run_cmd bash -c "$(curl -fsSL https://rpm.nodesource.com/setup_24.x)"
        run_root dnf install -y nodejs
      fi
      ;;
    yum)
      run_root yum install -y ca-certificates curl git gcc-c++ make
      if ! node_version_ok || ! npm_version_ok; then
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

ensure_prereqs() {
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
    die "Node.js $(node -v) is too old. NemoClaw requires Node ${MIN_NODE_MAJOR}+."
  fi

  if ! npm_version_ok; then
    die "npm $(npm -v) is too old. NemoClaw requires npm ${MIN_NPM_MAJOR}+."
  fi

  persist_macos_node_path
  persist_npm_global_bin
}

docker_ready() {
  require_cmd docker || return 1
  docker info >/dev/null 2>&1
}

ensure_macos_runtime() {
  if docker_ready; then
    return 0
  fi

  if require_cmd colima; then
    log "Starting Colima so NemoClaw has a supported container runtime"
    colima start
  else
    warn "No running Docker-compatible runtime detected."
    warn "NVIDIA docs list Colima or Docker Desktop as the supported macOS runtimes for NemoClaw."
    if confirm "Install Colima and Docker CLI automatically with Homebrew?"; then
      run_cmd brew install colima docker
      run_cmd colima start
    fi
  fi

  docker_ready || die "A running Docker-compatible runtime is required. Install Docker Desktop or Colima, then rerun the installer."
}

ensure_linux_runtime() {
  if docker_ready; then
    return 0
  fi

  warn "NemoClaw requires a running Docker daemon on Linux."
  die "Install and start Docker, then rerun this installer."
}

ensure_runtime() {
  step 2 "Checking the container runtime"

  case "$OS" in
    macos)
      ensure_macos_runtime
      ;;
    linux)
      ensure_linux_runtime
      ;;
  esac

  success "Container runtime is ready."
}

ensure_openshell() {
  local openshell_version

  if require_cmd openshell; then
    success "OpenShell is already installed."
    return 0
  fi

  step 3 "Installing OpenShell"
  warn_about_github_token

  openshell_version="$(latest_openshell_version)"
  log "Installing OpenShell ${openshell_version}"

  env -u GH_TOKEN -u GITHUB_TOKEN bash -lc \
    "curl -LsSf '${OPENSHELL_INSTALL_URL}' | OPENSHELL_VERSION='${openshell_version}' sh"

  require_cmd openshell || die "OpenShell installation did not finish cleanly. Try installing it manually from https://github.com/NVIDIA/OpenShell/releases"
  success "OpenShell ${openshell_version} is installed."
}

install_nemoclaw_cli() {
  step 4 "Installing the NemoClaw CLI"
  run_cmd npm install -g nemoclaw
  persist_npm_global_bin
  require_cmd nemoclaw || die "The NemoClaw CLI installed, but 'nemoclaw' is not in PATH yet. Open a new terminal and try again."
  success "NemoClaw CLI is installed."
}

run_nemoclaw_onboard() {
  step 5 "Launching the NemoClaw onboarding wizard"
  print_block "
${COLOR_BOLD}Heads up${COLOR_RESET}
- The official wizard will prompt for your NVIDIA API key.
- The first run stores it in ${COLOR_CYAN}~/.nemoclaw/credentials.json${COLOR_RESET}, per NVIDIA's docs.
- NemoClaw will create a sandboxed OpenClaw instance during onboarding.

"
  if (( NONINTERACTIVE == 1 )); then
    warn "Non-interactive mode installs the CLI, but onboarding still requires interactive answers for the API key and sandbox setup."
  fi

  warn_about_github_token
  run_cmd nemoclaw onboard
}

run_official_installer() {
  step 4 "Running NVIDIA's official NemoClaw installer"
  print_block "
${COLOR_BOLD}Heads up${COLOR_RESET}
- The official installer will prompt for your NVIDIA API key.
- NemoClaw creates a fresh OpenClaw instance inside the sandbox during onboarding.
- After install, use ${COLOR_CYAN}nemoclaw --help${COLOR_RESET} for the full CLI reference.

"
  warn_about_github_token
  curl -fsSL "${NEMOCLAW_INSTALL_URL}" | bash
}

print_install_summary() {
  headline "You are ready to launch"
  print_block "
${COLOR_GREEN}${COLOR_BOLD}NemoClaw install complete.${COLOR_RESET}

Recommended next steps:
1. Run ${COLOR_CYAN}nemoclaw --help${COLOR_RESET} to see the host-side commands.
2. Run ${COLOR_CYAN}nemoclaw list${COLOR_RESET} to see your registered sandboxes.
3. Connect with ${COLOR_CYAN}nemoclaw <sandbox-name> connect${COLOR_RESET}.
4. In the sandbox shell, use ${COLOR_CYAN}openclaw tui${COLOR_RESET} for chat.

Useful references:
- NVIDIA docs: https://docs.nvidia.com/nemoclaw/latest/index.html
- Quickstart: https://docs.nvidia.com/nemoclaw/latest/quickstart.html
- Commands: https://docs.nvidia.com/nemoclaw/latest/reference/commands.html

"
}

run_nemoclaw_uninstall() {
  log "Running NVIDIA's official NemoClaw uninstaller"
  if (( NONINTERACTIVE == 1 )) && (( KEEP_OPENSHELL == 1 )) && (( DELETE_MODELS == 1 )); then
    curl -fsSL "${NEMOCLAW_UNINSTALL_URL}" | bash -s -- --yes --keep-openshell --delete-models
  elif (( NONINTERACTIVE == 1 )) && (( KEEP_OPENSHELL == 1 )); then
    curl -fsSL "${NEMOCLAW_UNINSTALL_URL}" | bash -s -- --yes --keep-openshell
  elif (( NONINTERACTIVE == 1 )) && (( DELETE_MODELS == 1 )); then
    curl -fsSL "${NEMOCLAW_UNINSTALL_URL}" | bash -s -- --yes --delete-models
  elif (( KEEP_OPENSHELL == 1 )) && (( DELETE_MODELS == 1 )); then
    curl -fsSL "${NEMOCLAW_UNINSTALL_URL}" | bash -s -- --keep-openshell --delete-models
  elif (( NONINTERACTIVE == 1 )); then
    curl -fsSL "${NEMOCLAW_UNINSTALL_URL}" | bash -s -- --yes
  elif (( KEEP_OPENSHELL == 1 )); then
    curl -fsSL "${NEMOCLAW_UNINSTALL_URL}" | bash -s -- --keep-openshell
  elif (( DELETE_MODELS == 1 )); then
    curl -fsSL "${NEMOCLAW_UNINSTALL_URL}" | bash -s -- --delete-models
  else
    curl -fsSL "${NEMOCLAW_UNINSTALL_URL}" | bash
  fi
}

remove_path_if_exists() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    log "Removing $target"
    rm -rf "$target"
  fi
}

run_openclaw_uninstall() {
  log "Removing OpenClaw"

  if require_cmd openclaw; then
    if openclaw uninstall --all --yes --non-interactive; then
      success "OpenClaw uninstall completed."
    else
      warn "OpenClaw CLI uninstall did not complete cleanly. Continuing with manual cleanup."
    fi
  else
    warn "'openclaw' command not found. Continuing with manual cleanup."
  fi

  if require_cmd npm; then
    npm rm -g openclaw >/dev/null 2>&1 || true
  fi

  case "$OS" in
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

  remove_path_if_exists "${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
  remove_path_if_exists "${HOME}/.openclaw-default"
  remove_path_if_exists "${HOME}/.config/openclaw"
  success "OpenClaw cleanup completed."
}

run_uninstall() {
  local target

  detect_os
  target="$(normalize_uninstall_target "${UNINSTALL_TARGET}")"
  if [[ "$target" == "ask" ]]; then
    target="$(choose_uninstall_target)"
  fi

  headline "Uninstall"
  feature "Target: ${target}"
  if [[ "$target" == "nemoclaw" || "$target" == "both" ]]; then
    feature "NemoClaw removal uses NVIDIA's official uninstaller."
  fi
  if [[ "$target" == "openclaw" || "$target" == "both" ]]; then
    feature "OpenClaw removal uses the CLI uninstall first, then local cleanup if needed."
  fi
  printf "\n"

  case "$target" in
    nemoclaw)
      confirm "Continue and remove NemoClaw?" || die "Removal cancelled by user."
      run_nemoclaw_uninstall
      ;;
    openclaw)
      confirm "Continue and remove OpenClaw?" || die "Removal cancelled by user."
      run_openclaw_uninstall
      ;;
    both)
      confirm "Continue and remove both NemoClaw and OpenClaw?" || die "Removal cancelled by user."
      run_nemoclaw_uninstall
      run_openclaw_uninstall
      ;;
  esac
}

show_intro() {
  clear 2>/dev/null || true
  print_banner
  headline "Beginner-friendly setup for NVIDIA NemoClaw"
  print_block "
${COLOR_BOLD}What NemoClaw is${COLOR_RESET}
"
  feature "the host-side security stack and CLI from NVIDIA"
  feature "a way to run OpenClaw inside NVIDIA OpenShell with managed policy and inference"
  feature "an onboarding flow that prompts for your NVIDIA API key and creates a sandboxed agent"
  print_block "
${COLOR_BOLD}What this script does${COLOR_RESET}
"
  feature "installs missing beginner-unfriendly dependencies"
  feature "checks for a supported container runtime"
  feature "installs the NemoClaw CLI or runs NVIDIA's official installer"
  feature "makes PATH updates stick for future terminals when needed"
  print_block "
Official docs verified on March 24, 2026:
- Quick install: ${NEMOCLAW_INSTALL_URL}
- API key prompt happens during ${COLOR_CYAN}nemoclaw onboard${COLOR_RESET}
- The first run saves credentials to ${COLOR_CYAN}~/.nemoclaw/credentials.json${COLOR_RESET}

"
}

show_install_overview() {
  TOTAL_STEPS=5
  headline "Installation plan"
  feature "Step 1: detect your OS and install missing tools"
  feature "Step 2: make sure a supported container runtime is available"
  feature "Step 3: install OpenShell first so NemoClaw onboarding does not get blocked"
  if (( SKIP_ONBOARD == 1 )); then
    feature "Step 4: install the nemoclaw CLI"
    feature "Step 5: stop before onboarding so you can run it later"
  else
    feature "Step 4: install NemoClaw using NVIDIA's official flow"
    feature "Step 5: complete onboarding and create a sandboxed OpenClaw instance"
  fi
  printf "\n"
}

main() {
  show_intro

  if (( UNINSTALL_MODE == 1 )); then
    run_uninstall
    exit 0
  fi

  show_install_overview

  if ! confirm "Continue with the automated NemoClaw install?"; then
    die "Installation cancelled by user."
  fi

  ensure_prereqs
  ensure_runtime
  ensure_openshell

  if (( SKIP_ONBOARD == 1 )); then
    install_nemoclaw_cli
    step 5 "Skipping onboarding"
    print_block "
${COLOR_GREEN}${COLOR_BOLD}NemoClaw CLI installed.${COLOR_RESET}

Next step:
- Run ${COLOR_CYAN}nemoclaw onboard${COLOR_RESET} when you are ready to enter your NVIDIA API key and create the sandbox.

"
  else
    run_official_installer
    step 5 "Wrapping up"
  fi

  print_install_summary
  success "All done."
}

main "$@"
