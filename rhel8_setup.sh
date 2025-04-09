#!/bin/bash
# =====================================================================
# Rocky Linux 8 System Setup Script
# =====================================================================
# This script sets up a Rocky Linux 8 system with necessary modules and packages
# Created: $(date)
# =====================================================================

# Exit on any error
set -e

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

# =====================================================================
# Neovim Installation
# =====================================================================
echo_msg "Installing Neovim and dependencies..."
cd ~/Downloads  # or any directory where you have permissions

# Clone the repository
git clone https://github.com/neovim/neovim

# Change to the cloned directory
cd neovim

# Build in a way that installs to your home directory
make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=$HOME/neovim
make install
dnf install -y nodejs npm

# Setup Python virtual environment for Neovim
NEOVIM_VIRT_ENV_DIR="$HOME/.neovim_env"
mkdir -p ${NEOVIM_VIRT_ENV_DIR}
python3 -m venv ${NEOVIM_VIRT_ENV_DIR}/nvim-venv
source ${NEOVIM_VIRT_ENV_DIR}/nvim-venv/bin/activate
pip install --upgrade pip
pip install pynvim
deactivate

# Install Node.js provider for Neovim
npm install -g neovim

# Setup Neovim configuration
git clone git@github.com:drakebridgewater/kickstart.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim

# Set Python path for Neovim
NEOVIM_VIRT_ENV_DIR="$HOME/.neovim_env"
cat << EOF >> $HOME/.config/nvim/init.lua
vim.g.python3_host_prog = '${NEOVIM_VIRT_ENV_DIR}/nvim-venv/bin/python'
EOF

# =====================================================================
# Service Configuration
# =====================================================================
echo_msg "Configuring and starting essential services..."

# Enable and start SSH
systemctl enable sshd
systemctl start sshd

# Open SSH port in firewall
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# =====================================================================
# Oh-My-Zsh Setup
# =====================================================================
echo_msg "Setting up Oh-My-Zsh..."

# Install Oh-My-Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh-My-Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh-My-Zsh is already installed."
fi

# Install Powerlevel10k theme
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# Install useful plugins
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# Create/update .zshrc
cat > $HOME/.zshrc << 'EOF'
# Enable Powerlevel10k theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set plugins
plugins=(
    git
    docker
    sudo
    tmux
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Source oh-my-zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='nvim'
export VISUAL='nvim'

# Aliases
alias vim='nvim'
alias vi='nvim'
alias ll='ls -la'
alias zshconfig='$EDITOR ~/.zshrc'
alias zshreload='source ~/.zshrc'
alias tmuxconfig='$EDITOR ~/.tmux.conf'

# Custom key bindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
EOF

# Set Zsh as default shell
chsh -s $(which zsh) $(whoami)

# =====================================================================
# Oh-My-Tmux Setup
# =====================================================================
echo_msg "Setting up Oh-My-Tmux..."

# Install Oh-My-Tmux (Tmux Plugin Manager)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    mkdir -p $HOME/.tmux/plugins
    git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
fi

# Install Oh-My-Tmux configuration
if [ ! -d "$HOME/.tmux" ]; then
    git clone https://github.com/gpakosz/.tmux.git $HOME/.tmux
    ln -s -f $HOME/.tmux/.tmux.conf $HOME
fi

# Create custom .tmux.conf.local
cat > $HOME/.tmux.conf.local << 'EOF'
# Increase history limit
set -g history-limit 50000

# Enable mouse support
set -g mouse on

# Set terminal to 256 colors
set -g default-terminal "screen-256color"

# Use vim key bindings in copy mode
setw -g mode-keys vi

# Plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-pain-control'
set -g @plugin 'tmux-plugins/tmux-prefix-highlight'

# Plugin settings
set -g @continuum-restore 'on'
set -g @resurrect-strategy-nvim 'session'

# Status bar customization
set -g status-left "#{prefix_highlight} #[fg=green]#S #[fg=yellow]#I #[fg=cyan]#P"
set -g status-right "#{prefix_highlight} #[fg=cyan]%a %d %b %R #[fg=green]#H"

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
EOF

# Install tmux plugins automatically
$HOME/.tmux/plugins/tpm/bin/install_plugins

# =====================================================================
# Cleanup
# =====================================================================
echo_msg "Cleaning up..."
dnf clean all

echo_msg "Installation complete! Your Rocky Linux 8 system is now set up with Oh-My-Zsh and Oh-My-Tmux."
echo "Please log out and log back in for Zsh changes to take effect."