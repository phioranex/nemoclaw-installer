# NemoClaw Installer

One command for beginners who want NVIDIA NemoClaw installed without manually figuring out Node, npm, PATH issues, or basic container-runtime checks.

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh | bash
```

This repository is a community wrapper around the official NVIDIA NemoClaw install flow. It prepares the machine, checks prerequisites, and then runs the real NemoClaw setup path from NVIDIA's docs.

## What NemoClaw is

According to the NVIDIA NemoClaw Developer Guide, NemoClaw is:

- the host-side CLI and reference stack
- a way to run OpenClaw more safely inside NVIDIA OpenShell
- a system that manages sandboxing, network policy, inference routing, and onboarding
- a setup flow where `nemoclaw onboard` prompts for your NVIDIA API key and stores it in `~/.nemoclaw/credentials.json`

Important distinction:

- `nemoclaw` is what gets installed on the host
- OpenClaw gets created inside the sandbox during onboarding
- OpenShell is a required dependency in the NemoClaw flow
- if you only see `openclaw`, then you did not actually complete a NemoClaw install flow

## What this installer does

The script is designed for people who do not want to manually debug setup issues. It will:

- detect macOS or Linux
- install common missing packages like `curl`, `git`, Node.js, and npm when needed
- check for a supported container runtime
- install OpenShell first when it is missing, using the latest tagged OpenShell release
- on macOS, optionally install and start Colima for beginners if no supported runtime is running
- run NVIDIA's official NemoClaw installer
- optionally install only the `nemoclaw` CLI and let you run onboarding later
- provide a matching uninstall command

## Supported platforms

- macOS
- Linux with one of these package managers: `apt`, `dnf`, `yum`, `pacman`, or `zypper`

Official NVIDIA docs currently list these software requirements:

- Node.js 20 or later
- npm 10 or later
- a supported container runtime installed and running
- OpenShell installed as part of the NemoClaw setup flow

Official runtime support noted by NVIDIA:

- Linux: Docker
- macOS Apple Silicon: Colima or Docker Desktop
- Windows: WSL with Docker Desktop backend

This repo focuses on macOS and Linux. Windows users should use WSL and follow NVIDIA's official path there.

## Usage

### Standard install

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh | bash
```

### Skip onboarding

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh | bash -s -- --skip-onboard
```

This installs the `nemoclaw` CLI but stops before `nemoclaw onboard`.

### Non-interactive install

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh | bash -s -- --yes
```

This still may need interactive input later because the official onboarding wizard asks for your NVIDIA API key and sandbox settings.

### Non-interactive install and skip onboarding

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh | bash -s -- --yes --skip-onboard
```

## Uninstall

### Full removal

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/uninstall.sh | bash
```

This calls the official NVIDIA NemoClaw uninstaller. NVIDIA says it removes:

- NemoClaw state
- OpenShell sandboxes, gateway, and providers
- related Docker images and containers
- the global `nemoclaw` npm package

It does not remove shared tooling like Docker, Node.js, npm, or Ollama by default.

### Non-interactive full removal

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/uninstall.sh | bash -s -- --yes
```

### Keep OpenShell during uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/uninstall.sh | bash -s -- --keep-openshell
```

### Also remove Ollama models

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/uninstall.sh | bash -s -- --delete-models
```

## After install

Run these commands to verify that NemoClaw is what got installed:

```bash
nemoclaw --help
nemoclaw list
```

If you skipped onboarding, or want to start setup later:

```bash
nemoclaw onboard
```

During onboarding, NVIDIA's docs say NemoClaw will:

- prompt for your NVIDIA API key
- save it to `~/.nemoclaw/credentials.json`
- create the OpenShell gateway and providers
- build the sandbox image
- create a sandboxed OpenClaw instance

After onboarding, connect with:

```bash
nemoclaw <sandbox-name> connect
```

Inside the sandbox shell, start the OpenClaw interface with:

```bash
openclaw tui
```

## Why this wrapper exists

The hard part for many beginners is not the last command. It is everything around it:

- missing system packages
- outdated Node or npm versions
- PATH issues after install
- missing or stopped container runtime
- uncertainty about whether they installed `nemoclaw` or just `openclaw`

This project smooths out that host-side setup so the beginner can run one command and reach the actual NVIDIA NemoClaw flow more easily.

## Security note

NVIDIA marks NemoClaw as alpha software and says it is not production-ready. Treat it like an experimental agent stack with real file, tool, network, and credential risk.

Before you enable high-privilege skills:

- use a dedicated machine, VM, or low-privilege account
- prefer test credentials instead of personal or production accounts
- keep the host runtime and allowed endpoints tightly scoped
- review the NVIDIA docs for network policy and sandbox behavior

## Publish checklist

Before sharing the one-liner publicly:

1. Push `install.sh`, `uninstall.sh`, and `README.md` to `main`.
2. Confirm the raw GitHub URL works:
   `https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/install.sh`
3. Confirm the uninstall URL works:
   `https://raw.githubusercontent.com/phioranex/nemoclaw-installer/main/uninstall.sh`
4. Test on a clean machine or VM.
5. Verify that the install ends with a working `nemoclaw` command, not just `openclaw`.
6. Then share the command from the top of this README.

## Sources

- [NVIDIA NemoClaw Developer Guide](https://docs.nvidia.com/nemoclaw/latest/index.html)
- [NVIDIA NemoClaw Quickstart](https://docs.nvidia.com/nemoclaw/latest/quickstart.html)
- [NVIDIA NemoClaw Commands Reference](https://docs.nvidia.com/nemoclaw/latest/reference/commands.html)
- [NVIDIA/NemoClaw GitHub repository](https://github.com/NVIDIA/NemoClaw)
