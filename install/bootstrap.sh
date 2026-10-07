#!/bin/sh
# =====================================================================
# Dotfiles bootstrap — the only script you need to run on a new host.
# =====================================================================
# Deliberately POSIX sh with no Python dependency: on a fresh machine the
# platform scripts below are what *install* Python in the first place.
#
# Usage:
#   install/bootstrap.sh [--skip-packages] [--skip-python] [--minimal] [--home DIR]
#
#   --skip-packages  don't run the OS package install (no root / no network)
#   --skip-python    don't install the Python tools
#   --minimal        symlinks only; implies --skip-packages --skip-python
#   --home DIR       target home directory (default: $HOME)
# =====================================================================
set -eu

REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
TARGET_HOME="${HOME}"
SKIP_PACKAGES=0
SKIP_PYTHON=0

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-packages) SKIP_PACKAGES=1 ;;
        --skip-python)   SKIP_PYTHON=1 ;;
        --minimal)       SKIP_PACKAGES=1; SKIP_PYTHON=1 ;;
        --home)          shift; TARGET_HOME="$1" ;;
        -h|--help)       sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

say() { printf '\n==> %s\n' "$1"; }

detect_platform() {
    case "$(uname -s)" in
        Darwin) echo macos ;;
        Linux)
            if [ -f /etc/unraid-version ]; then
                echo unraid
            elif [ -f /etc/os-release ] \
                && grep -qiE '^ID(_LIKE)?=.*(rhel|fedora|centos|rocky)' /etc/os-release; then
                echo rhel
            else
                echo linux
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*) echo windows ;;
        *) echo unknown ;;
    esac
}

PLATFORM="$(detect_platform)"
say "Platform: $PLATFORM   Repo: $REPO_DIR   Home: $TARGET_HOME"

# --- 1. OS packages -------------------------------------------------------
if [ "$SKIP_PACKAGES" -eq 0 ]; then
    case "$PLATFORM" in
        macos)   script="$REPO_DIR/install/macos.sh" ;;
        rhel)    script="$REPO_DIR/install/linux-rhel8.sh" ;;
        unraid)  script="$REPO_DIR/install/unraid/unraid_setup.sh" ;;
        windows) script="$REPO_DIR/install/windows.ps1" ;;
        *)       script="" ;;
    esac

    if [ -n "$script" ] && [ -f "$script" ]; then
        say "Running platform setup: $script"
        case "$script" in
            *.ps1) powershell -ExecutionPolicy Bypass -File "$script" ;;
            *)     sh "$script" ;;
        esac
    else
        say "No platform setup script for '$PLATFORM', skipping package install."
    fi
else
    say "Skipping OS package install."
fi

# --- 2. Symlinks ----------------------------------------------------------
say "Linking home/ into $TARGET_HOME"
sh "$REPO_DIR/install/symlinks.sh" "$TARGET_HOME"

# --- 3. Config scaffold ---------------------------------------------------
CONFIG_DIR="${XDG_CONFIG_HOME:-$TARGET_HOME/.config}/dotfiles"
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    say "Seeding $CONFIG_DIR/config.yaml from etc/config.example.yaml"
    mkdir -p "$CONFIG_DIR"
    cp "$REPO_DIR/etc/config.example.yaml" "$CONFIG_DIR/config.yaml"
    chmod 600 "$CONFIG_DIR/config.yaml"
    echo "    Edit it and add your tokens before using the work-report tools."
else
    say "Config already present at $CONFIG_DIR/config.yaml, leaving it alone."
fi

# --- 4. Python tools ------------------------------------------------------
if [ "$SKIP_PYTHON" -eq 0 ]; then
    say "Installing Python tools"
    if command -v uv >/dev/null 2>&1; then
        uv tool install --editable "$REPO_DIR" --with-editables "$REPO_DIR"
    elif command -v pipx >/dev/null 2>&1; then
        pipx install --editable "$REPO_DIR"
    elif command -v python3 >/dev/null 2>&1; then
        echo "    uv/pipx not found, falling back to 'pip install --user -e'"
        python3 -m pip install --user -e "$REPO_DIR"
    else
        echo "    No python3 found, skipping. Re-run without --skip-packages first." >&2
    fi
else
    say "Skipping Python tool install."
fi

say "Done. Start a new shell, or run 'DOTFILES_MINIMAL=1 zsh' for the stripped-down environment."
