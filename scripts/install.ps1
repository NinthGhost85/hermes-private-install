# install.ps1
# Hermes Agent native Windows install script (custom directory version)
# Requires: PowerShell 5.1+, unrestricted execution policy for this session
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1
#
# This version installs the entire environment under C:\Hermes_home.
# Change $INSTALL_ROOT below to use a different location.

$ErrorActionPreference = "Stop"
#Requires -Version 5.1

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Hermes Agent - Native Windows Installer" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# -------------------------------------------------------------------
# 1. Determine install directory (custom location)
# -------------------------------------------------------------------
$INSTALL_ROOT = "C:\Hermes_home"         # <-- set your custom path here
$INSTALL_DIR  = $INSTALL_ROOT
Write-Host "[*] Install directory: $INSTALL_DIR" -ForegroundColor Yellow

# -------------------------------------------------------------------
# 2. Create directory structure (only the root and venv folder)
# -------------------------------------------------------------------
Write-Host "[*] Creating directory structure..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
New-Item -ItemType Directory -Force -Path "$INSTALL_DIR\venv" | Out-Null

# -------------------------------------------------------------------
# 3. Check/install uv (system-wide tool)
# -------------------------------------------------------------------
Write-Host "[*] Checking for uv..." -ForegroundColor Yellow
$uv = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uv) {
    Write-Host "[*] uv not found. Installing uv via official installer..." -ForegroundColor Yellow
    irm https://astral.sh/uv/install.ps1 | iex
    # Refresh PATH so that uv is available immediately
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uv) {
        Write-Error "uv installation failed. Please install uv manually: https://docs.astral.sh/uv/getting-started/installation/"
        exit 1
    }
}
Write-Host "[*] uv found at: $($uv.Source)" -ForegroundColor Green

# -------------------------------------------------------------------
# 4. Create Python virtual environment using uv
# -------------------------------------------------------------------
Write-Host "[*] Creating Python virtual environment (this may take a moment)..." -ForegroundColor Yellow
uv venv "$INSTALL_DIR\venv" --python 3.11
Write-Host "[*] Virtual environment created." -ForegroundColor Green

# -------------------------------------------------------------------
# 5. Install hermes-agent and dependencies
# -------------------------------------------------------------------
Write-Host "[*] Installing hermes-agent..." -ForegroundColor Yellow
& "$INSTALL_DIR\venv\Scripts\python.exe" -m pip install --upgrade pip
& "$INSTALL_DIR\venv\Scripts\pip.exe" install hermes-agent
Write-Host "[*] hermes-agent installed successfully." -ForegroundColor Green

# -------------------------------------------------------------------
# 6. Set HERMES_HOME environment variable (for CLI data)
# -------------------------------------------------------------------
Write-Host "[*] Setting HERMES_HOME=$INSTALL_ROOT" -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable("HERMES_HOME", $INSTALL_ROOT, "User")
$env:HERMES_HOME = $INSTALL_ROOT
Write-Host "[*] HERMES_HOME set. The CLI will create its data folders on first run." -ForegroundColor Green

# -------------------------------------------------------------------
# 7. Add venv Scripts to PATH (so 'hermes' is available globally)
# -------------------------------------------------------------------
$VENV_SCRIPTS = "$INSTALL_DIR\venv\Scripts"
Write-Host "[*] Adding to user PATH: $VENV_SCRIPTS" -ForegroundColor Yellow

# Add to current session PATH
$env:Path = "$VENV_SCRIPTS;$env:Path"

# Add permanently to user PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$VENV_SCRIPTS*") {
    [Environment]::SetEnvironmentVariable("Path", "$VENV_SCRIPTS;$userPath", "User")
    Write-Host "[*] Added to user PATH permanently." -ForegroundColor Green
} else {
    Write-Host "[*] Already in user PATH." -ForegroundColor Green
}

# -------------------------------------------------------------------
# 8. Test the installation
# -------------------------------------------------------------------
Write-Host "[*] Testing hermes CLI..." -ForegroundColor Yellow
$hermes = Get-Command hermes -ErrorAction SilentlyContinue
if ($hermes) {
    Write-Host "[*] Hermes CLI found at: $($hermes.Source)" -ForegroundColor Green
    & hermes --help
} else {
    Write-Host "[!] hermes not found on PATH. You may need to restart your terminal." -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Installation complete!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  You can now run 'hermes' from any terminal." -ForegroundColor White
Write-Host "  All user data will be stored under: $INSTALL_ROOT" -ForegroundColor White
Write-Host "  If the command is not found, restart your terminal or run:" -ForegroundColor White
Write-Host "      `$env:Path = `"$VENV_SCRIPTS;`$env:Path`"" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Cyan
