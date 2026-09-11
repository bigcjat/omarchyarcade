@echo off
setlocal
set "APP_DIR=%LOCALAPPDATA%\omarchy-arcade"

if exist "%APP_DIR%\venv\Scripts\pythonw.exe" (
    start "" "%APP_DIR%\venv\Scripts\pythonw.exe" "%APP_DIR%\launcher\main.py" %*
) else if exist "%APP_DIR%\venv\Scripts\python.exe" (
    start "" "%APP_DIR%\venv\Scripts\python.exe" "%APP_DIR%\launcher\main.py" %*
) else (
    echo [Omarchy Arcade] Error: Virtual environment not found at %APP_DIR%\venv
    echo Run the installer to install or repair:
    echo   powershell -c "irm https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/packaging/windows/install.ps1 | iex"
    pause
)
