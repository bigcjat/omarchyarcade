# Omarchy Arcade for Windows

Omarchy Arcade runs natively on Windows 10 and 11 with hardware acceleration via Qt Quick / DirectX 11 / OpenGL RHI and zero bloat.

---

## One-Command Quick Install (PowerShell)

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/packaging/windows/install.ps1 | iex
```

### What this does:
1. Verifies Python 3 is installed.
2. Installs the lightweight launcher payload to `%LOCALAPPDATA%\omarchy-arcade` (under 1MB, zero git clone).
3. Creates an isolated virtual environment with `PySide6`.
4. Creates high-DPI **Start Menu** and **Desktop** shortcuts (`Omarchy Arcade.lnk`).
5. Adds the `arcade` CLI shortcut to your user command line.

---

## Manual Run from Source

If you cloned the Git repository directly on Windows:

```powershell
# Create venv and install dependencies
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install PySide6

# Launch the Arcade
python launcher\main.py
```

---

## Uninstallation

To completely remove Omarchy Arcade and all downloaded games, simply delete the local application folder and shortcuts:

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\omarchy-arcade"
Remove-Item -Force "$([System.Environment]::GetFolderPath('Desktop'))\Omarchy Arcade.lnk"
Remove-Item -Force "$([System.Environment]::GetFolderPath('Programs'))\Omarchy Arcade.lnk"
```
Zero registry clutter, zero background daemons.
