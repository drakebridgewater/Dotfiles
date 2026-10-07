# Dotfiles

Personal shell environment and tooling for macOS, Linux, RHEL/Rocky, Unraid and
Windows. One repo, one bootstrap command, works on personal and work hosts.

## Quick start

```bash
git clone https://github.com/drakebridgewater/Dotfiles.git ~/Dotfiles
~/Dotfiles/install/bootstrap.sh
```

Landing on a locked-down box with no root, no network, or no Python?

```bash
~/Dotfiles/install/bootstrap.sh --minimal   # symlinks only
```

Then `DOTFILES_MINIMAL=1 zsh` gives a plain environment — PATH, helper
functions and a simple prompt, with no oh-my-zsh, zinit, p10k or network access.
`.zshrc` also falls back to it automatically when `~/.oh-my-zsh` is missing.

## Layout

The repo is organised by **how a file reaches the machine**, not by language.

```text
home/       Symlinked verbatim into $HOME (.zshrc, .bashrc, .profile, .vimrc, ...)
config/     Each entry symlinked into ~/.config (nvim/)
shell/      Sourced by interactive shells
  loader.sh   Shared loader for shell/common (used by every rc file)
  minimal.sh  Stripped-down environment for bare machines
  common/     Helper functions loaded in every shell
  zsh/        zsh-only: completions, extras
  work/       Siemens EDA helpers, loaded only on /usr/mgc or /wv hosts
bin/        On $PATH
  work/       On $PATH only on Siemens hosts
  windows/    PowerShell utilities
lib/python/dotfiles/   Importable Python package behind the CLI tools
install/    Bootstrap: bootstrap.sh, symlinks.sh, per-platform scripts
etc/        Example configs (config.example.yaml, env.example)
docs/       Notes
```

## Three tiers

| Tier | Runs | Language |
| --- | --- | --- |
| **bootstrap** | once per host, often as root | native `sh` / `ps1` |
| **runtime** | every interactive shell | sourced shell |
| **tools** | on demand | Python package |

Bootstrap stays POSIX `sh` on purpose: the platform scripts are what *install*
Python, so they cannot be written in it. Runtime stays sourced shell because the
helpers define functions in your live shell and every terminal pays their
startup cost.

## Platforms

| Platform | Script | Notes |
| --- | --- | --- |
| macOS | `install/macos.sh` | Homebrew |
| RHEL/Rocky 8 | `install/linux-rhel8.sh` | dnf module streams |
| Unraid | `install/unraid/unraid_setup.sh` | Docker container |
| Windows | `install/windows.ps1` | PowerShell |

`install/bootstrap.sh` detects the platform and dispatches automatically.

### Unraid

Unraid's root filesystem is in RAM and wiped on every reboot, so instead of
installing host packages a Docker container provides the full environment.

```bash
git clone https://github.com/drakebridgewater/Dotfiles.git /boot/config/Dotfiles
bash /boot/config/Dotfiles/install/unraid/unraid_setup.sh
docker exec -it dotfiles-shell zsh
```

Setup registers a boot hook in `/boot/config/go` that starts the container each
reboot. The container mounts the repo read-only, plus SSH keys, the Docker
socket and `/mnt/user`.

## Python tools

Installed as a real package with console entry points, so there are no
hand-written wrapper scripts:

| Command | Module |
| --- | --- |
| `generate-work-report` | `dotfiles.work_report` |
| `generate-roadmap` | `dotfiles.roadmap` |
| `pick-commits` | `dotfiles.pick_commits` |
| `compare-tree` | `dotfiles.compare_tree` |
| `pushover-send` / `pushover-watch` | `dotfiles.pushover` |
| `work-report-mcp` | `dotfiles.work_report_mcp` (needs `[mcp]` extra) |

`bootstrap.sh` installs them with `uv`, falling back to `pipx`, then
`pip install --user -e`. To do it by hand:

```bash
uv tool install --editable ~/Dotfiles
# or
pipx install --editable ~/Dotfiles
```

## Configuration

Secrets live outside the repo. `bootstrap.sh` seeds
`~/.config/dotfiles/config.yaml` from `etc/config.example.yaml` with mode `600`.
Fill in your GitLab / Jira / Confluence tokens there. The repo ignores
`config.yaml` so a filled-in copy can never be committed by accident.

## How it works

- `install/symlinks.sh` links everything in `home/` into `$HOME` and everything
  in `config/` into `~/.config`, backing up any existing file to `.bak` first.
  Run it alone to enable Neovim: `~/Dotfiles/install/symlinks.sh`.
- Neovim config is `config/nvim` (lazy.nvim; plugins in `lua/plugins/`). The
  `lazy-lock.json` generated on first run is committed so plugin versions match
  across machines.
- `home/.profile` builds `$PATH` dynamically — only directories that exist are
  added — and exports `DOTFILES_DIR` for everything else to key off.
- `shell/loader.sh` sources `shell/common/*`, loading `logging` first (other
  helpers depend on it) and isolating failures so one broken file cannot abort
  your rc.
- `home/.zshrc` falls back to `home/.zshrc.legacy` on zsh < 5.1 (RHEL 7), and to
  `shell/minimal.sh` when there is no framework installed.
- Siemens EDA config, `shell/work/` and `bin/work/` load only on hosts with
  `/usr/mgc` or `/wv`.
- A non-writable or foreign-owned `$HOME` (UID-mismatched containers) reroutes
  caches and history to a temp dir instead of failing.
