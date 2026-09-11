# ==============================================================================
# Omarchy Arcade • Windows PowerShell One-Command Installer
# Supports Windows 10 & 11 (x64 / ARM64). Zero bloat, offline-ready.
# Usage:
#   irm https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/packaging/windows/install.ps1 | iex
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  OMARCHY ARCADE • Windows Application Installer" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host ""

$APP_DIR = "$env:LOCALAPPDATA\omarchy-arcade"
$BIN_DIR = "$APP_DIR\bin"

# 1. Detect Python
$pythonExe = $null
if (Get-Command python.exe -ErrorAction SilentlyContinue) {
    $pythonExe = "python.exe"
} elseif (Get-Command py.exe -ErrorAction SilentlyContinue) {
    $pythonExe = "py.exe"
}

if (-not $pythonExe) {
    Write-Host "[!] Python 3 was not found on your system." -ForegroundColor Red
    Write-Host "    Please install Python 3 (Python 3.10, 3.11, or 3.12 recommended)." -ForegroundColor Yellow
    Write-Host "    Quick install via winget: winget install Python.Python.3.12" -ForegroundColor Cyan
    Write-Host "    Or download from: https://www.python.org/downloads/" -ForegroundColor Cyan
    Exit 1
}

Write-Host "==> Using Python interpreter: $pythonExe" -ForegroundColor Green

# 2. Prepare directories
New-Item -ItemType Directory -Force -Path "$APP_DIR\launcher" | Out-Null
New-Item -ItemType Directory -Force -Path "$APP_DIR\assets\covers" | Out-Null
New-Item -ItemType Directory -Force -Path "$APP_DIR\games" | Out-Null
New-Item -ItemType Directory -Force -Path "$BIN_DIR" | Out-Null

# 3. Install Launcher Application Files
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
$localRepoRoot = $null
if ($scriptDir) {
    $cand = (Resolve-Path "$scriptDir\..\..").Path
    if (Test-Path "$cand\launcher\main.py") {
        $localRepoRoot = $cand
    }
}

if ($localRepoRoot) {
    Write-Host "==> Installing launcher from local directory: $localRepoRoot" -ForegroundColor Green
    Copy-Item -Force "$localRepoRoot\catalog.json" "$APP_DIR\catalog.json"
    Copy-Item -Force -Recurse "$localRepoRoot\launcher\*" "$APP_DIR\launcher\"
    Copy-Item -Force "$localRepoRoot\assets\omarchy_arcade_logo.svg" "$APP_DIR\assets\omarchy_arcade_logo.svg" -ErrorAction SilentlyContinue
    if (Test-Path "$localRepoRoot\packaging\windows\arcade.ico") {
        Copy-Item -Force "$localRepoRoot\packaging\windows\arcade.ico" "$APP_DIR\assets\arcade.ico"
    }
    if (Test-Path "$localRepoRoot\packaging\windows\arcade.cmd") {
        Copy-Item -Force "$localRepoRoot\packaging\windows\arcade.cmd" "$BIN_DIR\arcade.cmd"
    }
    if (Test-Path "$localRepoRoot\assets\covers") {
        Copy-Item -Force -Recurse "$localRepoRoot\assets\covers\*" "$APP_DIR\assets\covers\" -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "==> Downloading Omarchy Arcade launcher payload from GitHub..." -ForegroundColor Green
    $baseUrl = "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main"

    Invoke-RestMethod -Uri "$baseUrl/catalog.json" -OutFile "$APP_DIR\catalog.json"
    Invoke-RestMethod -Uri "$baseUrl/assets/omarchy_arcade_logo.svg" -OutFile "$APP_DIR\assets\omarchy_arcade_logo.svg"
    Invoke-RestMethod -Uri "$baseUrl/packaging/windows/arcade.ico" -OutFile "$APP_DIR\assets\arcade.ico"
    Invoke-RestMethod -Uri "$baseUrl/packaging/windows/arcade.cmd" -OutFile "$BIN_DIR\arcade.cmd"

    $files = @(
        "main.py", "main.qml", "FloppyCard.qml", "GameDetailSheet.qml",
        "SplashScreen.qml", "ViewFeatured.qml", "ViewCarousel.qml",
        "ViewDesktop.qml", "ViewSidebar.qml", "omarchy_arcade_logo.svg",
        "omarchy_arcade_text.svg"
    )

    foreach ($f in $files) {
        Invoke-RestMethod -Uri "$baseUrl/launcher/$f" -OutFile "$APP_DIR\launcher/$f"
    }
}

# 4. Provision Isolated Virtual Environment
$venvPython = "$APP_DIR\venv\Scripts\python.exe"
$venvPythonw = "$APP_DIR\venv\Scripts\pythonw.exe"

if (-not (Test-Path $venvPython)) {
    Write-Host "==> Creating isolated user Python virtual environment..." -ForegroundColor Green
    & $pythonExe -m venv "$APP_DIR\venv"
}

Write-Host "==> Ensuring PySide6 runtime is installed in virtual environment..." -ForegroundColor Green
& $venvPython -m pip install --upgrade --quiet pip
& $venvPython -m pip install --quiet PySide6

# 5. Create Windows Shortcuts (Desktop & Start Menu)
try {
    $wsh = New-Object -ComObject WScript.Shell
    $iconPath = "$APP_DIR\assets\arcade.ico"

    # Start Menu Shortcut
    $startMenuPath = [System.Environment]::GetFolderPath('Programs')
    $shortcutStart = $wsh.CreateShortcut("$startMenuPath\Omarchy Arcade.lnk")
    $shortcutStart.TargetPath = $venvPythonw
    $shortcutStart.Arguments = "`"$APP_DIR\launcher\main.py`""
    $shortcutStart.WorkingDirectory = "$APP_DIR\launcher"
    $shortcutStart.Description = "Omarchy Arcade - Lightweight Retro Games Suite"
    if (Test-Path $iconPath) {
        $shortcutStart.IconLocation = "$iconPath, 0"
    }
    $shortcutStart.Save()

    # Desktop Shortcut
    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    $shortcutDesktop = $wsh.CreateShortcut("$desktopPath\Omarchy Arcade.lnk")
    $shortcutDesktop.TargetPath = $venvPythonw
    $shortcutDesktop.Arguments = "`"$APP_DIR\launcher\main.py`""
    $shortcutDesktop.WorkingDirectory = "$APP_DIR\launcher"
    $shortcutDesktop.Description = "Omarchy Arcade - Lightweight Retro Games Suite"
    if (Test-Path $iconPath) {
        $shortcutDesktop.IconLocation = "$iconPath, 0"
    }
    $shortcutDesktop.Save()

    Write-Host "==> Created Start Menu & Desktop shortcuts!" -ForegroundColor Green
} catch {
    Write-Host "[!] Notice: Could not create desktop shortcuts automatically: $_" -ForegroundColor Yellow
}

# 6. Add bin directory to User PATH if not present
try {
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$BIN_DIR*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$BIN_DIR", "User")
        Write-Host "==> Added 'arcade' command to user PATH ($BIN_DIR)" -ForegroundColor Green
    }
} catch {
    # Non-fatal
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Cyan
Write-Host "  You can launch Omarchy Arcade from:" -ForegroundColor White
Write-Host "    - Desktop / Start Menu: 'Omarchy Arcade'" -ForegroundColor White
Write-Host "    - Command prompt: arcade" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
