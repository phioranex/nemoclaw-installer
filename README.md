# NemoClaw Installer

This repository contains an interactive installer script for NemoClaw (NVIDIA/nemoclaw). The installer downloads the latest release binary, verifies its GPG signature and SHA256 checksum, and installs the `nemoclaw` binary into a user-local bin directory (`~/.local/bin` by default).

## Overview

- Verifies GPG signature & SHA256 checksum (when available).
- Supports Linux and macOS (x86_64 and ARM64 / aarch64).
- Installs to `~/.local/bin` by default and can add that directory to your `PATH`.

## Prerequisites

- `bash`, `curl` (or `wget`)
- `sha256sum` (on macOS install via `brew install coreutils`)
- `gpg` / `gnupg` (optional but recommended for signature verification)

On macOS you can install prerequisites with Homebrew:

```
brew install coreutils gnupg
```

Note: Homebrew's coreutils provides `gsha256sum` and a `gnubin` directory; adding Coreutils' gnubin to your PATH makes `sha256sum` available as expected by the installer.

## Security note
Do NOT run random installer scripts piped from the internet without reviewing them first. The installer deliberately downloads to a temporary file and performs GPG/SHA256 verification; review the `install.sh` contents before running.

## Installation

1. Download and inspect the installer:

```
curl -sSL https://raw.githubusercontent.com/NVIDIA/nemoclaw/main/install.sh -o install.sh
less install.sh
```

2. Run the installer interactively:

```
bash install.sh
```

The installer will:

- Detect your OS and architecture.
- Download the matching release binary and accompanying `SHA256SUMS` and signature.
- Attempt to import the project's public key and verify the signature (if `gpg` is present).
- Verify the SHA256 checksum of the downloaded binary.
- Copy the binary to `~/.local/bin/nemoclaw` (or another path you choose) and make it executable.
- Optionally add `~/.local/bin` to your shell startup file so `nemoclaw` is available on your `PATH`.

Important: The installer is interactive (prompts for confirmation and install path). If you want to run it on multiple machines, inspect or adapt the script for automation.

### One-line installer (quick)

You can run the installer with a single command (no sudo required — installs to your home directory):

```
curl -sSL https://raw.githubusercontent.com/NVIDIA/nemoclaw/main/install.sh | bash
```

This downloads and runs the installer script directly. The script performs signature and checksum verification when possible and is interactive by default.

If you prefer to inspect before running, download first and then run locally:

```
curl -sSL https://raw.githubusercontent.com/NVIDIA/nemoclaw/main/install.sh -o install.sh
less install.sh
bash install.sh
```

## Troubleshooting

- "GPG key import failed": `gpg` may not be installed — install `gnupg` and retry.
- "Signature verification failed": Do not proceed — verification is important. Ensure you have network access to fetch the correct key and that files downloaded correctly.
- "SHA256 verification failed": The binary may be corrupted or tampered with. Abort and report the issue.
- If the installer cannot find a binary for your architecture, open an issue: https://github.com/NVIDIA/nemoclaw/issues

## Uninstall

To remove the installed binary (default location):

```
rm -f ~/.local/bin/nemoclaw
```

If the installer added `~/.local/bin` to your shell rc file (e.g., `~/.zshrc`, `~/.bashrc`, or `~/.profile`), remove the lines it added.

## Manual install (alternate)

You can manually download a release binary and verify signatures if you prefer to avoid the installer:

- Releases: https://github.com/NVIDIA/nemoclaw/releases
- Docs: https://docs.nvidia.com/nemoclaw/
- Example policy: https://github.com/NVIDIA/nemoclaw/blob/main/examples/safe-policy.yaml

## Links

- Repository: https://github.com/NVIDIA/nemoclaw
- Docs: https://docs.nvidia.com/nemoclaw/
- Report issues: https://github.com/NVIDIA/nemoclaw/issues
