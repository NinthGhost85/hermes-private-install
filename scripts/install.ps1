<#
.SYNOPSIS
    Install Hermes Agent on Windows (custom path edition)
.DESCRIPTION
    This script installs the Hermes Agent on Windows with custom default locations:
    - HermesHome = C:\Hermes_home
    - InstallDir = C:\Hermes_home\hermes-agent
.PARAMETER HermesHome
    Override the Hermes home directory (default: C:\Hermes_home)
.PARAMETER InstallDir
    Override the installation directory (default: C:\Hermes_home\hermes-agent)
.PARAMETER Branch
    Git branch to clone (default: main)
.PARAMETER Tag
    Git tag to clone (overrides branch if specified)
.PARAMETER SkipSetup
    Skip the interactive setup wizard after installation
#>

param(
    [string]$HermesHome,
    [string]$InstallDir,
    [string]$Branch = "main",
    [string]$Tag,
    [switch]$SkipSetup
)

# Set error handling
$ErrorActionPreference = "Stop"

# Custom default paths (modified from original)
if (-not $HermesHome) {
    $HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { "C:\Hermes_home" }
}
if (-not $InstallDir) {
    $InstallDir = if ($env:HERMES_INSTALL_DIR) { $env:HERMES_INSTALL_DIR } else { "C:\Hermes_home\hermes-agent" }
}

Write-Host "Hermes Home: $HermesHome" -ForegroundColor Cyan
Write-Host "Install Dir : $InstallDir" -ForegroundColor Cyan

# Create directories if they don't exist
$null = New-Item -ItemType Directory -Force -Path $HermesHome
$null = New-Item -ItemType Directory -Force -Path $InstallDir

# Function to update PATH environment variable for current user
function Add-ToUserPath {
    param([string]$NewPath)
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$NewPath*") {
        $newPathValue = "$currentPath;$NewPath"
        [Environment]::SetEnvironmentVariable("Path", $newPathValue, "User")
        Write-Host "Added $NewPath to User PATH" -ForegroundColor Green
    }
}

# Check for Git
$gitPath = Join-Path $HermesHome "git\bin\git.exe"
if (-not (Test-Path $gitPath)) {
    Write-Host "Installing portable Git..." -ForegroundColor Yellow
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/PortableGit-2.47.1-64-bit.7z.exe"
    $gitInstaller = Join-Path $env:TEMP "PortableGit.exe"
    Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$HermesHome\git`"" -Wait
    Remove-Item $gitInstaller -Force
    # Add git to PATH temporarily
    $env:Path = "$HermesHome\git\bin;$env:Path"
} else {
    Write-Host "Git already installed at $gitPath" -ForegroundColor Green
    $env:Path = "$HermesHome\git\bin;$env:Path"
}

# Check for uv (fast Python package manager)
$uvExe = Join-Path $HermesHome "uv\uv.exe"
if (-not (Test-Path $uvExe)) {
    Write-Host "Installing uv..." -ForegroundColor Yellow
    $uvUrl = "https://github.com/astral-sh/uv/releases/download/0.4.27/uv-x86_64-pc-windows-msvc.zip"
    $uvZip = Join-Path $env:TEMP "uv.zip"
    Invoke-WebRequest -Uri $uvUrl -OutFile $uvZip
    Expand-Archive -Path $uvZip -DestinationPath "$HermesHome\uv" -Force
    Remove-Item $uvZip -Force
    $env:Path = "$HermesHome\uv;$env:Path"
} else {
    Write-Host "uv already installed" -ForegroundColor Green
    $env:Path = "$HermesHome\uv;$env:Path"
}

# Clone or update Hermes Agent repository
$repoUrl = "https://github.com/NousResearch/hermes-agent.git"
if (Test-Path (Join-Path $InstallDir ".git")) {
    Write-Host "Updating existing repository..." -ForegroundColor Yellow
    Push-Location $InstallDir
    & git fetch --all --tags
    if ($Tag) {
        & git checkout "tags/$Tag" -B "install-tag"
    } else {
        & git checkout $Branch
        & git pull origin $Branch
    }
    Pop-Location
} else {
    Write-Host "Cloning Hermes Agent repository..." -ForegroundColor Yellow
    if ($Tag) {
        & git clone --branch "$Tag" --depth 1 $repoUrl $InstallDir
    } else {
        & git clone --branch $Branch --depth 1 $repoUrl $InstallDir
    }
}

# Create Python virtual environment using uv
$venvPath = Join-Path $InstallDir ".venv"
if (-not (Test-Path $venvPath)) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    Push-Location $InstallDir
    & "$HermesHome\uv\uv.exe" venv $venvPath
    Pop-Location
} else {
    Write-Host "Virtual environment already exists" -ForegroundColor Green
}

# Install Hermes Agent and dependencies (Fixed Section)
Write-Host "Installing Hermes Agent and dependencies..." -ForegroundColor Yellow
Push-Location $InstallDir
& "$HermesHome\uv\uv.exe" pip install --upgrade pip setuptools wheel
& "$HermesHome\uv\uv.exe" pip install -e .
Pop-Location

# Create CLI entry point in bin folder
$binDir = Join-Path $InstallDir "bin"
$null = New-Item -ItemType Directory -Force -Path $binDir
$hermesBat = Join-Path $binDir "hermes.bat"
@"
@echo off
"$venvPath\Scripts\python.exe" "$InstallDir\hermes_agent\cli.py" %*
"@ | Out-File -FilePath $hermesBat -Encoding ASCII

# Add bin directory to user PATH
Add-ToUserPath -NewPath $binDir

# Set environment variables for the current session
[Environment]::SetEnvironmentVariable("HERMES_HOME", $HermesHome, "User")
[Environment]::SetEnvironmentVariable("HERMES_INSTALL_DIR", $InstallDir, "User")
$env:HERMES_HOME = $HermesHome
$env:HERMES_INSTALL_DIR = $InstallDir

# Refresh PATH in current session (so hermes command is available immediately)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "`nHermes Agent installation complete!" -ForegroundColor Green
Write-Host "Installation directory: $InstallDir" -ForegroundColor Cyan
Write-Host "Home directory: $HermesHome" -ForegroundColor Cyan
Write-Host "You may need to restart your terminal for PATH changes to take effect." -ForegroundColor Yellow

if (-not $SkipSetup) {
    Write-Host "`nRunning setup wizard..." -ForegroundColor Cyan
    & hermes setup
} else {
    Write-Host "`nSkipped setup. Run 'hermes setup' manually when ready." -ForegroundColor Yellow
}

Write-Host "`nTo verify installation, open a new terminal and run: hermes --version" -ForegroundColor Cyan
