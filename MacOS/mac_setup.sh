#!/bin/bash

# Exit on error and print commands as they execute
set -e
set -x

HOME=/Users/drake/

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add Homebrew to path
  echo '# Set PATH, MANPATH, etc., for Homebrew.' >>$HOME/.zprofile
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>$HOME/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew already installed."
fi

# Check if Xcode command line tools are installed
if ! xcode-select -p &>/dev/null; then
  echo "Installing Xcode command line tools..."
  xcode-select --install
else
  echo "Xcode command line tools already installed."
fi

# Install Python
echo "Installing Python..."
brew install python@3.11

# Coding tools
echo "Installing coding tools..."
brew install --cask jetbrains-toolbox  # Manage JetBrains IDEs
brew install --cask sublime-text       # Text editor
brew install --cask iterm2             # Terminal
brew install --cask docker             # Containerization
brew install --cask visual-studio-code # Code editor
brew install --cask postman            # API testing
brew install --cask rapidapi           # API testing
brew install --cask mqtt-explorer      # MQTT testing

# Productivity tools
echo "Installing productivity tools..."
brew install --cask alt-tab         # Better alt-tab
brew install --cask scroll-reverser # Reverse scrolling direction
brew install --cask istat-menus     # System monitoring
brew install --cask shottr          # Screenshot utility
brew install --cask meetingbar      # Calendar in menu bar
brew install --cask clop            # Clipboard manager

# VPN tools
echo "Installing VPN tools..."
brew install --cask tailscale # Mesh VPN
brew install --cask protonvpn # Secure VPN

# System maintenance
echo "Installing system utilities..."
brew install --cask the-unarchiver # Better archive utility
brew install --cask balenaetcher   # USB image writer
brew install --cask magnet         # Window management
# brew install --cask bettermouse  # Mouse utility

# Optional alternatives
# brew install --cask rectangle    # Window management (alternative to Magnet)
# brew install --cask alfred       # Spotlight alternative

# Menu bar management
echo "Installing menu bar management..."
brew install --cask bartender # Hide menu bar icons
# Alternative: brew install --cask hiddenbar

# Social and communication apps
echo "Installing social and communication apps..."
brew install --cask \
  steam \
  signal \
  slack \
  zoom \
  discord \
  microsoft-teams

# Office suites and email clients
echo "Installing office and email apps..."
brew install --cask microsoft-office  # Office suite
brew install --cask protonmail-bridge # Email client (ProtonMail)
brew install --cask proton-mail       # Email client (ProtonMail)
# Optional: brew install --cask mimestream  # Email client (Google [Paid])

# General applications
echo "Installing general applications..."
brew install --cask firefox-developer-edition # Web browser
brew install --cask spotify                   # Music streaming
brew install --cask appcleaner                # App uninstaller
brew install --cask obs                       # Screen recording
brew install --cask michaelvillar-timer       # Pomodoro timer
brew install --cask raycast                   # Spotlight alternative
brew install --cask 1password

# LaTeX tools
# echo "Installing LaTeX tools..."
# brew install --cask mactex # LaTeX distribution
# brew install --cask texmaker # LaTeX editor if needed

# Note taking apps
echo "Installing note taking apps..."
brew install --cask obsidian # Knowledge base
brew install --cask notion   # Note taking

# Terminal enhancements
echo "Installing terminal enhancements..."
brew install --cask warp # Modern terminal

# CLI Tools
echo "Installing CLI tools..."
brew install glances       # System monitoring
brew install git           # Version control
brew install node          # JavaScript runtime
brew install fzf           # Fuzzy finder
brew install awscli        # AWS CLI
brew install tmux          # Terminal multiplexer
brew install tmuxinator    # Tmux sessions manager
brew install watch         # Watch command
brew install graphviz      # Graph visualization
brew install tree          # Directory tree
brew install 1password-cli # 1Password CLI
# brew install kcat       # Kafka CLI (commented out)

# Development tools
echo "Installing development tools..."
brew install gh     # GitHub CLI
brew install jq     # JSON processor
brew install httpie # HTTP client

# Terminal enhancements
echo "Installing terminal utilities..."
brew install ripgrep # Better grep
brew install bat     # Better cat
brew install exa     # Better ls
brew install fd      # Better find

# Calculator and utilities
echo "Installing calculator and utilities..."
brew install --cask numi   # Smart calculator
brew install --cask rocket # Emojis helper (trigger ":")

# Setup shell and configuration files
echo "Setting up shell environment..."

# Check if Dotfiles directory exists
if [ -d "$HOME/Dotfiles" ]; then
  echo "Setting up dotfiles..."
  cd $HOME

  # Create backups of existing files if they exist
  for file in .zshrc .p10k.zsh .tmux.conf .vimrc; do
    if [ -f "$file" ] && [ ! -L "$file" ]; then
      mv "$file" "${file}.backup.$(date +%Y%m%d%H%M%S)"
    fi
  done

  # Create symlinks
  ln -sf $HOME/Dotfiles/.zshrc .
  ln -sf $HOME/Dotfiles/.p10k.zsh .
  ln -sf $HOME/Dotfiles/.tmux.conf .
  ln -sf $HOME/Dotfiles/.vimrc .
else
  echo "Warning: Dotfiles directory not found at $HOME/Dotfiles"
  echo "Skipping dotfiles setup. Please create this directory and add your configuration files."
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "Oh My Zsh already installed."
fi

# Install Zinit for faster ZSH
if [ ! -d "$HOME/.zinit" ]; then
  echo "Installing Zinit..."
  bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
else
  echo "Zinit already installed."
fi

# Install NVM and Node.js
if [ ! -d "$HOME/.nvm" ]; then
  echo "Installing NVM..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash # Updated to latest NVM version

  # Load NVM
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  # Install latest LTS version of Node.js
  echo "Installing Node.js LTS..."
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default
else
  echo "NVM already installed."
fi

# Install Powerlevel10k theme
if [ ! -d "$HOME/powerlevel10k" ]; then
  echo "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k

  # Add to .zshrc if it's not already there
  if ! grep -q "powerlevel10k.zsh-theme" ~/.zshrc; then
    echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc
  fi
else
  echo "Powerlevel10k already installed."
fi

# Install Fuzzy Completion
echo "Installing FZF key bindings and completion..."
"$(brew --prefix)/opt/fzf/install" --all

# Setup home and end key to work correctly (external keyboards)
echo "Setting up keyboard shortcuts for external keyboards..."
mkdir -p ~/Library/KeyBindings

# Create DefaultKeyBinding.dict if it doesn't exist
if [ ! -f "$HOME/Dotfiles/DefaultKeyBinding.dict" ]; then
  echo "Creating DefaultKeyBinding.dict..."
  cat >~/Library/KeyBindings/DefaultKeyBinding.dict <<EOF
{
    /* Home Button*/
    "\UF729" = "moveToBeginningOfLine:";
    /* End Button */
    "\UF72B" = "moveToEndOfLine:";
    /* Shift + Home Button */
    "$\UF729" = "moveToBeginningOfLineAndModifySelection:";
    /* Shift + End Button */
    "$\UF72B" = "moveToEndOfLineAndModifySelection:";
    /* Ctrl + Home Button */
    "^\UF729" = "moveToBeginningOfDocument:";
    /* Ctrl + End Button */
    "^\UF72B" = "moveToEndOfDocument:";
    /* Shift + Ctrl + Home Button */
    "$^\UF729" = "moveToBeginningOfDocumentAndModifySelection:";
    /* Shift + Ctrl + End Button*/
    "$^\UF72B" = "moveToEndOfDocumentAndModifySelection:";
}
EOF
else
  cp "$HOME/Dotfiles/DefaultKeyBinding.dict" ~/Library/KeyBindings/DefaultKeyBinding.dict
fi

# Final cleanup and verification
echo "Checking for any Homebrew issues..."
brew doctor

# Check if any apps failed to install
echo "Checking for any failed installations..."
failed_apps=$(brew list --cask 2>/dev/null | wc -l)
echo "Successfully installed $failed_apps applications."

echo "Setup complete! Some tools may require additional configuration."
echo "Please restart your terminal to apply all changes."
