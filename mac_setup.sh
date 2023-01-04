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

brew install \
  glances \
  git \
  node \
  awscli \
  tmux \
  tmuxinator \
  kcat \
  watch

# Setup SSH Access
# ssh-keygen -t ed25519 -C "drake.bridgewater@dat.com"

# Setup shell experience
HOME=/Users/drakebr/
cd $HOME || exit
git clone git@github.com:drakebridgewater/Dotfiles.git
ln -s $HOME/Dotfiles/.zshrc .
ln -s $HOME/Dotfiles/.p10k.zsh .
ln -s $HOME/Dotfiles/.tmux.conf .
ln -s $HOME/Dotfiles/.vimrc .

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Zinit for faster ZSH
bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"

# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 14.21.2
nvm install defaultv
nvm alias default 14.21.2
nvm use default

# Install Fuzzy Completion
brew install fzf
# To install useful key bindings and fuzzy completion:
$(brew --prefix)/opt/fzf/install

# Setup home and end key to work correctly (external keyboards) 
# Source: https://medium.com/@elhayefrat/how-to-fix-the-home-and-end-buttons-for-an-external-keyboard-in-mac-4da773a0d3a2 
mkdir -p ~/Library/KeyBindings
cp DefaultKeyBinding.dict ~/Library/KeyBindings/DefaultKeyBinding.dict



