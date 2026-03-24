# NemoClaw Installer

One command for beginners who want a NemoClaw-style setup without manually chasing system packages, Node versions, and CLI install steps.

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh | bash
```

This repository provides a community bootstrapper. It prepares the system, installs missing dependencies, and then runs the public OpenClaw installer, which is the install base currently documented publicly.

## What NemoClaw appears to do

Based on NVIDIA's March 22, 2026 announcement, NemoClaw is a security and privacy layer for OpenClaw. NVIDIA says it adds:

- an isolated sandbox through NVIDIA OpenShell
- policy-based security, network, and privacy guardrails
- support for local open models such as NVIDIA Nemotron
- a privacy router so agents can selectively use cloud frontier models
- a single-command experience for secure always-on agents

In plain English: OpenClaw is the agent runtime, and NemoClaw is meant to make that runtime safer and more enterprise-ready.

Important note: this repo is not an official NVIDIA project. It is a helper installer that recreates the beginner-friendly "one line" experience by automating the public prerequisites and OpenClaw install flow that are available today.

## What this installer does

The script is designed for people who do not want to manually debug setup issues. It will:

- detect macOS or Linux
- install common missing packages like `curl` and `git`
- install or upgrade Node.js when your version is too old
- run the official OpenClaw installer
- optionally skip onboarding when you want a non-interactive install
- provide a matching one-line uninstall path

## Supported platforms

- macOS
- Linux with one of these package managers: `apt`, `dnf`, `yum`, `pacman`, or `zypper`

Windows is not handled by this script directly. For Windows, the safest route is WSL2 and then running the same command inside the WSL terminal.

## Usage

### Standard install

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh | bash
```

### Skip onboarding

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh | bash -s -- --skip-onboard
```

### Non-interactive install

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh | bash -s -- --yes
```

### Non-interactive install and skip onboarding

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh | bash -s -- --yes --skip-onboard
```

## Uninstall

### Full removal

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/uninstall.sh | bash
```

This runs the installer in uninstall mode and removes:

- the OpenClaw gateway service when present
- the default local state directory such as `~/.openclaw`
- the default workspace inside that state directory
- the globally installed npm `openclaw` CLI

### Non-interactive full removal

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/uninstall.sh | bash -s -- --yes
```

### What may still remain

The uninstaller also tells the user this, but it is worth calling out here:

- profile-specific state directories like `~/.openclaw-work`
- custom config paths set with `OPENCLAW_CONFIG_PATH`
- custom workspaces outside the default OpenClaw state folder

## After install

Run these commands to verify everything:

```bash
openclaw --version
openclaw doctor
openclaw gateway status
```

If you skipped onboarding:

```bash
openclaw onboard --install-daemon
```

## Why this exists

The beginner pain is not usually the final install command. It is everything around it:

- missing package managers
- old Node versions
- missing `git` or `curl`
- uncertainty about what to run next

This project smooths out that setup path so someone can paste one command and let the script do the heavy lifting.

## Security note

OpenClaw-style agents can have real access to files, tools, networks, and accounts. Even NVIDIA's own public OpenClaw guidance warns about data exposure and malicious code risk.

Before you enable high-privilege skills:

- use a dedicated machine, VM, or low-privilege account
- avoid exposing the web UI to the public internet
- install only trusted skills
- treat terminal-enabled skills as high risk

## Publish checklist

Before sharing the one-liner publicly:

1. Push `install.sh`, `uninstall.sh`, and `README.md` to `main`.
2. Confirm the raw GitHub URL works:
   `https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh`
3. Confirm the uninstall URL works:
   `https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/uninstall.sh`
4. Test on a clean machine or VM.
5. Then share the command from the top of this README.

## Sources

- [NVIDIA press release, March 22, 2026](https://nvidianews.nvidia.com/_gallery/download_pdf/69b8651d3d633215999f2ac1/)
- [NVIDIA OpenClaw on DGX Spark guide](https://build.nvidia.com/spark/openclaw/overview)
- [OpenClaw install docs](https://docs.openclaw.ai/install/index)
