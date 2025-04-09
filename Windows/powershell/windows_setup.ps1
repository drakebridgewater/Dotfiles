# Windows Machine Setup Script
# This script automates the setup of a Windows machine with common software

# Run this script as Administrator

# Check if script is running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script needs to be run as Administrator. Please restart with admin privileges."
    break
}

# Set execution policy to allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

# Define log file
$logFile = "$env:USERPROFILE\windows_setup_log.txt"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$timestamp - Windows Setup Script Started" | Out-File -FilePath $logFile -Append

function Log-Message {
    param(
        [string]$message,
        [switch]$error
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($error) {
        Write-Host "[ERROR] $message" -ForegroundColor Red
        "$timestamp - [ERROR] $message" | Out-File -FilePath $logFile -Append
    } else {
        Write-Host "[INFO] $message" -ForegroundColor Green
        "$timestamp - [INFO] $message" | Out-File -FilePath $logFile -Append
    }
}

#------------------------------------
# Install Chocolatey Package Manager
#------------------------------------
Log-Message "Installing Chocolatey package manager..."
try {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        refreshenv
        Log-Message "Chocolatey installed successfully"
    } else {
        Log-Message "Chocolatey is already installed"
    }
} catch {
    Log-Message "Failed to install Chocolatey: $_" -error
}

#------------------------------------
# Install Common Software Packages
#------------------------------------
Log-Message "Installing common software packages..."

# Define common software packages to install
$commonPackages = @(
    # Development Tools
    "git",
    "vim",
    "neovim",
    "vscode",
    "nodejs",
    "python",
    "curl",
    "awscli",
    "docker-desktop",
    "putty.install",
    "postman",

    # Terminal Emulators
    "wezterm",

    # Browsers
    "googlechrome",
    "firefox",

    # Utilities
    "7zip",
    "notepadplusplus",
    "sysinternals",
    "speedtest",
    "powertoys",
    "greenshot",

    # Communication
    "slack",
    "microsoft-teams",

    # Media
    "vlc",
    "spotify",

    # Cloud Storage
    "onedrive",

    # Developer Fonts (available via Chocolatey)
    "firacode",
    "cascadiacode",
    "jetbrainsmono",
    "sourcecodepro"
)

# Allow user to select packages (remove comment to enable selection)
# $selectedPackages = $commonPackages | Out-GridView -Title "Select packages to install" -PassThru

# Install packages
foreach ($package in $commonPackages) {
    try {
        Log-Message "Installing $package..."
        choco install $package -y
        Log-Message "$package installed successfully"
    } catch {
        Log-Message "Failed to install $package: $_" -error
    }
}

#------------------------------------
# Configure Git (if not already configured)
#------------------------------------
Log-Message "Configuring Git..."

$gitUserName = Read-Host -Prompt "Enter your Git username (or press Enter to skip)"
$gitEmail = Read-Host -Prompt "Enter your Git email (or press Enter to skip)"

if ($gitUserName -ne "") {
    git config --global user.name "$gitUserName"
    Log-Message "Git username set to: $gitUserName"
}

if ($gitEmail -ne "") {
    git config --global user.email "$gitEmail"
    Log-Message "Git email set to: $gitEmail"
}

# Configure Git default branch
git config --global init.defaultBranch main
Log-Message "Git default branch set to main"

#------------------------------------
# Clone and Configure WezTerm
#------------------------------------
Log-Message "Configuring WezTerm..."

$weztermConfigPath = "$env:USERPROFILE\.config\wezterm"

# Create .config directory if it doesn't exist
if (!(Test-Path "$env:USERPROFILE\.config")) {
    New-Item -ItemType Directory -Path "$env:USERPROFILE\.config" | Out-Null
    Log-Message "Created .config directory"
}

# Remove existing WezTerm config if it exists
if (Test-Path $weztermConfigPath) {
    $backupPath = "$weztermConfigPath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Rename-Item -Path $weztermConfigPath -NewName $backupPath
    Log-Message "Existing WezTerm configuration backed up to $backupPath"
}

# Clone the WezTerm config repository
try {
    git clone "https://github.com/KevinSilvester/wezterm-config.git" $weztermConfigPath
    Log-Message "WezTerm configuration cloned successfully"
} catch {
    Log-Message "Failed to clone WezTerm configuration: $_" -error
}

#------------------------------------
# Add PowerShell Profile Configuration
#------------------------------------
Log-Message "Setting up PowerShell profile..."

$psProfilePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$psProfileDir = Split-Path -Parent $psProfilePath

# Create profile directory if it doesn't exist
if (!(Test-Path $psProfileDir)) {
    New-Item -ItemType Directory -Path $psProfileDir -Force | Out-Null
    Log-Message "Created PowerShell profile directory"
}

# Backup existing profile if it exists
if (Test-Path $psProfilePath) {
    $profileBackupPath = "$psProfilePath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item -Path $psProfilePath -Destination $profileBackupPath
    Log-Message "Existing PowerShell profile backed up to $profileBackupPath"
}

# Create/Append to PowerShell profile
$profileContent = @"
# PowerShell Profile - Created by Windows Setup Script
# $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Set encoding to UTF-8
`$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# Import PSReadLine for better command line editing
Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Better directory navigation
function cd.. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

# Common aliases
Set-Alias -Name g -Value git
Set-Alias -Name np -Value notepad++
Set-Alias -Name code -Value code-insiders -ErrorAction SilentlyContinue

# Custom prompt
function prompt {
    `$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    `$principal = [Security.Principal.WindowsPrincipal] `$identity
    `$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

    `$prefix = ""
    if (`$principal.IsInRole(`$adminRole)) {
        `$prefix = "[ADMIN] "
    }

    `$path = `$ExecutionContext.SessionState.Path.CurrentLocation.Path
    `$path = `$path.Replace(`$HOME, "~")

    Write-Host "`n`$prefix" -NoNewline -ForegroundColor Yellow
    Write-Host "`$path" -NoNewline -ForegroundColor Cyan
    return "> "
}

# Custom functions
function Update-System {
    Write-Host "Updating Windows packages..." -ForegroundColor Green
    choco upgrade all -y

    Write-Host "Updating PowerShell modules..." -ForegroundColor Green
    Update-Module -Force

    Write-Host "System update completed!" -ForegroundColor Green
}

# WezTerm integration (if installed)
if (Get-Command wezterm -ErrorAction SilentlyContinue) {
    Write-Host "WezTerm detected - enabling terminal integration" -ForegroundColor Green
}

# Welcome message
Write-Host "PowerShell profile loaded - Happy coding!" -ForegroundColor Magenta
"@

$profileContent | Out-File -FilePath $psProfilePath -Encoding utf8
Log-Message "PowerShell profile created/updated at $psProfilePath"

#------------------------------------
# Create Desktop Shortcut for Script
#------------------------------------
$scriptPath = $MyInvocation.MyCommand.Path
$shortcutPath = "$env:USERPROFILE\Desktop\Update-System.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
$Shortcut.WorkingDirectory = Split-Path -Parent $scriptPath
$Shortcut.IconLocation = "powershell.exe,0"
$Shortcut.Description = "Run Windows Setup/Update Script"
$Shortcut.Save()

Log-Message "Created desktop shortcut for easy updates"

#------------------------------------
# Final Setup and Cleanup
#------------------------------------
Log-Message "Refreshing environment variables..."
refreshenv

# Create a Windows Task Scheduler task to run weekly updates
Log-Message "Creating scheduled task for weekly updates..."
$taskName = "WindowsWeeklyUpdate"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -Command `"choco upgrade all -y`""
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Log-Message "Removed existing scheduled task"
}

Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Principal $principal -Settings $settings
Log-Message "Scheduled weekly updates successfully"

# Final message
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$timestamp - Windows Setup Script Completed" | Out-File -FilePath $logFile -Append

Log-Message "Setup completed! Log file saved to: $logFile"
Log-Message "Please restart your computer to ensure all changes take effect."

# Prompt for restart
$restart = Read-Host "Would you like to restart your computer now? (Y/N)"
if ($restart -eq "Y" -or $restart -eq "y") {
    Restart-Computer -Force
}