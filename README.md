# Dotfiles

Personal dotfiles for macOS, Linux, and Unraid. Source the same shell configuration across all platforms with automatic OS detection.

## Supported Platforms

| Platform | Setup Script | Notes |
|----------|-------------|-------|
| macOS | `MacOS/mac_setup.sh` | Homebrew-based package installation |
| RHEL/Rocky 8 | `rhel8_setup.sh` | dnf-based setup with module streams |
| Unraid | `Unraid/unraid_setup.sh` | Docker container with full shell environment |
| Windows | `Windows/powershell/windows_setup.ps1` | PowerShell-based setup |

## Quick Start

### macOS / Linux

```bash
git clone https://github.com/drakebridgewater/Dotfiles.git ~/Dotfiles
cd ~/Dotfiles
./setup_dotfile_symlinks ~
```

### Unraid

Unraid's root filesystem is in RAM and wiped on every reboot. Instead of installing packages on the host, a Docker container provides the full shell environment with zsh, oh-my-zsh, tmux, vim, and all dotfiles.

```bash
# 1. Clone to persistent storage
git clone https://github.com/drakebridgewater/Dotfiles.git /boot/config/Dotfiles

# 2. Run setup (builds container, registers boot script)
bash /boot/config/Dotfiles/Unraid/unraid_setup.sh

# 3. Attach to the shell
docker exec -it dotfiles-shell zsh
```

The setup script registers a boot hook in `/boot/config/go` that auto-starts the container on every reboot. The container mounts your Dotfiles (read-only), SSH keys, Docker socket, and `/mnt/user` shares.

## Structure

```
.zshrc              # Main zsh config (sources .profile and .aliases)
.zshrc.legacy       # Fallback for zsh < 5.1 (RHEL 7)
.bashrc             # Bash config
.profile            # Shared environment: PATH, exports (sourced by zsh and bash)
.aliases            # Shared aliases with OS-specific sections
.vimrc              # Vim configuration
.tmux.conf          # Tmux configuration (oh-my-tmux)
.tmux.conf.local    # Local tmux overrides
.p10k.zsh           # Powerlevel10k prompt theme
extra.zsh           # Optional extras (long-running command notifications)
setup_dotfile_symlinks  # Creates symlinks from repo into $HOME
```

### Platform-Specific Directories

```
MacOS/              # macOS Homebrew setup
Unraid/             # Unraid Docker container setup + boot scripts
Windows/            # Windows/PowerShell setup
bin/                # Personal scripts added to PATH
pushover/           # Pushover notification scripts
```

## How It Works

- `setup_dotfile_symlinks <home_dir>` symlinks all dotfiles (files starting with `.`) from this repo into the given home directory
- `.profile` builds `$PATH` dynamically — only directories that exist are added
- `.aliases` detects macOS vs Linux vs Unraid and adjusts commands accordingly
- `.zshrc` detects old zsh versions and falls back to `.zshrc.legacy`
- Siemens EDA configuration is only loaded when on Siemens hosts (checks for `/usr/mgc` or `/wv`)

### Unraid-Specific Behavior

- Uses a Docker container (`dotfiles-shell`) for the full shell environment
- `/boot/config/go` calls `Unraid/unraid_boot.sh` to start the container on boot
- Dotfiles are mounted read-only from `/boot/config/Dotfiles/` into the container
- Container has `host` networking, Docker socket access, and `/mnt/user` shares mounted
- SSH keys from the Unraid host are mounted read-only
- Set `UNRAID=true` environment variable is available for Unraid-specific logic
