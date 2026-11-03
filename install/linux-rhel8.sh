#!/bin/bash
# =====================================================================
# Rocky Linux 8 System Setup Script
# =====================================================================
# This script sets up a Rocky Linux 8 system with necessary modules and packages
# Created: $(date)
# =====================================================================

# Exit on any error
set -e

# Privilege detection: root-only steps are skipped when neither root nor passwordless sudo is available.
SUDO=""
HAVE_ROOT=0
if [ "$(id -u)" -eq 0 ]; then
    HAVE_ROOT=1
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    SUDO="sudo"
    HAVE_ROOT=1
fi

as_root() {
    if [ -n "$SUDO" ]; then sudo "$@"; else "$@"; fi
}

# Shadows the binary so every dnf call below picks up sudo when needed.
dnf() { as_root dnf "$@"; }

# Display a message with a border
echo_msg() {
    local msg="$1"
    local cols=$(tput cols)
    local line=$(printf '%*s' "$cols" | tr ' ' '=')
    echo -e "\n$line"
    echo -e "$msg"
    echo -e "$line\n"
}

# Function to enable a module stream
enable_module() {
    local module="$1"
    local stream="$2"
    echo "Enabling module $module:$stream..."
    dnf module enable -y "$module:$stream"
}

if [ "$HAVE_ROOT" -eq 1 ]; then

# Update system first
echo_msg "Updating system packages..."
dnf update -y

# =====================================================================
# Repository Setup
# =====================================================================
echo_msg "Setting up repositories..."

# EPEL Repository (Extra Packages for Enterprise Linux)
dnf install -y epel-release

# =====================================================================
# Module Stream Setup
# =====================================================================
echo_msg "Enabling required module streams..."

# Web and App Servers
enable_module httpd 2.4
enable_module nginx 1.14

# Programming Languages
enable_module nodejs 20
enable_module python36 3.6
enable_module python39 3.9
enable_module perl 5.26
enable_module ruby 2.5
enable_module php 7.2

# Database
enable_module mariadb 10.3

# Development Tools
enable_module llvm-toolset rhel8
enable_module container-tools rhel8

# Virtualization
enable_module virt rhel

# Source Control
enable_module subversion 1.10

# Java Support
enable_module javapackages-runtime 201801

# Perl Modules
enable_module perl-DBD-MySQL 4.046
enable_module perl-DBI 1.641
enable_module perl-IO-Socket-SSL 2.066
enable_module perl-YAML 1.24
enable_module perl-libwww-perl 6.34

# =====================================================================
# Package Installation
# =====================================================================
echo_msg "Installing packages by category..."

# System Utilities
echo "Installing system utilities..."
dnf install -y \
    bind-utils \
    curl \
    git \
    git-svn \
    htop \
    jq \
    net-tools \
    openssh-server \
    rsync \
    subversion-perl \
    tar \
    tmux \
    unzip \
    vim \
    wget \
    zip \
    zsh \
    ripgrep \
    fzf \
    util-linux-user
# =====================================================================
# Web Server Packages
# =====================================================================
echo "Installing web server components..."
dnf install -y \
    httpd \
    nginx \
    mod_ssl

# =====================================================================
# Database Packages
# =====================================================================
echo "Installing database components..."
dnf install -y \
    mariadb-server \
    mariadb

# =====================================================================
# Development Packages
# =====================================================================
echo "Installing development tools..."
dnf install -y \
    gcc \
    gcc-c++ \
    make \
    autoconf \
    automake \
    libtool \
    pkgconfig \
    cmake \
    bison \
    flex

# Optional: VS Code (if needed)
# dnf install -y code

# =====================================================================
# Programming Languages and Frameworks
# =====================================================================
echo "Installing programming languages..."
dnf install -y \
    nodejs \
    python36 \
    python39 \
    python3-pip \
    python3-devel \
    npm \
    perl \
    php \
    php-fpm \
    php-mysqlnd \
    php-gd \
    ruby

# =====================================================================
# Container Support
# =====================================================================
echo "Installing container tools..."
dnf install -y \
    podman \
    buildah \
    skopeo

else
    echo_msg "No root/sudo access: skipping repositories, module streams and system packages."
fi

# =====================================================================
# Neovim Installation
# =====================================================================
echo_msg "Installing Neovim and dependencies..."

nvim_missing=""
for tool in git make cmake gcc; do
    command -v "$tool" >/dev/null 2>&1 || nvim_missing="$nvim_missing $tool"
done

if [ -x "$HOME/neovim/bin/nvim" ]; then
    echo "Neovim already installed in $HOME/neovim."
elif [ -n "$nvim_missing" ]; then
    echo "Skipping Neovim build; missing tools:$nvim_missing"
else
    # Subshell keeps the caller's working directory intact; installs to $HOME/neovim, no root needed.
    (
        mkdir -p ~/Downloads
        cd ~/Downloads
        [ -d neovim ] || git clone https://github.com/neovim/neovim
        cd neovim
        make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=$HOME/neovim
        make install
    )
fi

# Setup Python virtual environment for Neovim
if command -v python3 >/dev/null 2>&1; then
    NEOVIM_VIRT_ENV_DIR="$HOME/.neovim_env"
    mkdir -p ${NEOVIM_VIRT_ENV_DIR}
    python3 -m venv ${NEOVIM_VIRT_ENV_DIR}/nvim-venv
    source ${NEOVIM_VIRT_ENV_DIR}/nvim-venv/bin/activate
    pip install --upgrade pip
    pip install pynvim
    deactivate
else
    echo "python3 not found; skipping pynvim setup."
fi

# Install Node.js provider for Neovim (user prefix when not root; needs ~/.local/bin on PATH)
if command -v npm >/dev/null 2>&1; then
    if [ "$HAVE_ROOT" -eq 1 ]; then
        as_root npm install -g neovim
    else
        npm install -g --prefix "$HOME/.local" neovim
    fi
else
    echo "npm not found; skipping Node.js provider for Neovim."
fi

# Neovim config is symlinked from config/nvim by install/symlinks.sh;
# init.lua picks up the venv above automatically.

# =====================================================================
# Service Configuration
# =====================================================================
echo_msg "Configuring and starting essential services..."

if [ "$HAVE_ROOT" -eq 1 ]; then
    # Enable and start SSH
    as_root systemctl enable sshd
    as_root systemctl start sshd

    # Open SSH port in firewall
    as_root firewall-cmd --permanent --add-service=ssh
    as_root firewall-cmd --reload
else
    echo "No root/sudo access: skipping sshd and firewall configuration."
fi

# =====================================================================
# Oh-My-Zsh Setup
# =====================================================================
echo_msg "Setting up Oh-My-Zsh..."

# Install Oh-My-Zsh (its installer refuses to run without zsh)
if ! command -v zsh >/dev/null 2>&1; then
    echo "zsh not found; skipping Oh-My-Zsh setup."
elif [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh-My-Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh-My-Zsh is already installed."
fi

# Install Powerlevel10k theme
if [ -d "$HOME/.oh-my-zsh" ] && [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# Install useful plugins
if [ -d "$HOME/.oh-my-zsh" ] && [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

if [ -d "$HOME/.oh-my-zsh" ] && [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# Set Zsh as default shell (chsh needs a password or root; a failure here is non-fatal)
if command -v zsh >/dev/null 2>&1; then
    chsh -s "$(command -v zsh)" "$(whoami)" \
        || echo "Could not change default shell; add 'exec zsh -l' to ~/.bash_profile instead."
fi

# =====================================================================
# Oh-My-Tmux Setup
# =====================================================================
echo_msg "Setting up Oh-My-Tmux..."

# Install Oh-My-Tmux (Tmux Plugin Manager)
if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux not found; skipping Oh-My-Tmux setup."
else
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    mkdir -p $HOME/.tmux/plugins
    git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
fi

# Install Oh-My-Tmux configuration
if [ ! -d "$HOME/.tmux" ]; then
    git clone https://github.com/gpakosz/.tmux.git $HOME/.tmux
    ln -s -f $HOME/.tmux/.tmux.conf $HOME
fi
# Install tmux plugins automatically
$HOME/.tmux/plugins/tpm/bin/install_plugins
fi

# =====================================================================
# Cleanup
# =====================================================================
if [ "$HAVE_ROOT" -eq 1 ]; then
    echo_msg "Cleaning up..."
    dnf clean all
fi

echo_msg "Installation complete! Your Rocky Linux 8 system is now set up with Oh-My-Zsh and Oh-My-Tmux."
echo "Please log out and log back in for Zsh changes to take effect."