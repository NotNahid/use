@echo off
TITLE Cloud Server (Current Folder)
CLS

echo ==================================================
echo      Checking System Requirements...
echo ==================================================

:: 1. CHECK & INSTALL PYTHON
python --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo [!] Python is NOT installed. Installing now...
    winget install Python.Python.3.11
    echo [!] Install complete. Restarting script...
    timeout /t 3 >nul
    start "" "%~f0"
    exit
)

:: 2. CHECK & INSTALL CLOUDFLARE
cloudflared --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo [!] Cloudflare Tunnel is NOT installed. Installing now...
    winget install Cloudflare.cloudflared
    echo [!] Install complete. Restarting script...
    timeout /t 3 >nul
    start "" "%~f0"
    exit
)

echo.
echo ==================================================
echo      HOSTING THIS FOLDER:
echo      %CD%
echo ==================================================

:: 3. START PYTHON SERVER (Background Window)
:: This uses the current directory automatically
start "Local File Server" cmd /k "python -m http.server 8080"

echo [OK] Local Server is running.
echo [INFO] Generatng your Public Link below...
echo.

:: 4. START CLOUDFLARE TUNNEL (Main Window)
cloudflared tunnel --url http://localhost:8080
