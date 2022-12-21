#!/bin/bash -x 
# // Install Homebrew
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# // Add Paths for homebrew
# echo '# Set PATH, MANPATH, etc., for Homebrew.' >> /Users/drakebr/.zprofile
# echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/drakebr/.zprofile
# eval "$(/opt/homebrew/bin/brew shellenv)"

# // Install command line tools in xcode
# xcode-select --install

brew tap homebrew/cask-versions

brew install --cask \
  fontforge 

# brew install --cask slack

brew install --cask \
  firefox-developer-edition \
  sublime-text \
  visual-studio-code \
  iterm2 \
  docker \
  postman \
  spotify \
  zoom \
  discord \
  alfred \
  alt-tab \
  notion \
  1password \
  istat-menus \
  intellij-idea \
  appcleaner \
  steam \
  microsoft-office \
  obs \
  caffeine \
  hiddenbar \
  signal \
  lens \
  shottr \
  meetingbar \
  tailscale \
  mqtt-explorer \
  rapidapi \
  michaelvillar-timer \
  grammarly

brew install glances git node awscli tmux tmuxinator kcat

# Setup SSH Access
# ssh-keygen -t ed25519 -C "drake.bridgewater@dat.com"


# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Zinit for faster ZSH
bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"

# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 14.21.2
nvm alias default 14.21.2
nvm install default
nvm use default

