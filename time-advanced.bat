@echo off
:: ============================================================
::  Windows Time Fix - Run as Administrator
::  Fixes drift, resets W32Time, sets reliable NTP servers
:: ============================================================

net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERROR: Run this script as Administrator.
    pause
    exit /b 1
)

echo [1/7] Stopping W32Time...
net stop w32time >nul 2>&1

echo [2/7] Re-registering W32Time service...
w32tm /unregister >nul 2>&1
w32tm /register >nul 2>&1

echo [3/7] Starting W32Time...
net start w32time

echo [4/7] Fixing registry settings...
:: Short poll interval (64s) to catch drift fast - default 900s is too slow
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" /v SpecialPollInterval /t REG_DWORD /d 64 /f >nul
:: Leave CompatibilityFlags at default (do NOT set to 0 - breaks some servers)
:: MaxPosPhaseCorrection / MaxNegPhaseCorrection - allow large corrections (fixes the 1-3 min jump)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config" /v MaxPosPhaseCorrection /t REG_DWORD /d 3600 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config" /v MaxNegPhaseCorrection /t REG_DWORD /d 3600 /f >nul
:: UpdateInterval - how often the clock is adjusted (default 30000 = ~5min, lower = smoother)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config" /v UpdateInterval /t REG_DWORD /d 100 /f >nul

echo [5/7] Setting NTP servers (Google + Microsoft + NIST)...
w32tm /config /manualpeerlist:"time.google.com,0x9 time.windows.com,0x9 time.nist.gov,0x9" /syncfromflags:manual /reliable:yes /update

echo [6/7] Fixing firewall rules for NTP (UDP 123)...
:: Delete old rules first (ignore errors if they don't exist)
netsh advfirewall firewall delete rule name="NTP" >nul 2>&1
netsh advfirewall firewall delete rule name="NTP-IN" >nul 2>&1
:: Outbound: remoteport=123 (we connect OUT to NTP servers)
netsh advfirewall firewall add rule name="NTP" dir=out protocol=udp remoteport=123 action=allow
:: Inbound rule only needed if this PC serves time to others - skip for clients

echo [7/7] Restarting service and forcing sync...
net stop w32time
net start w32time
w32tm /resync /force

echo.
echo ============================================================
echo  Done. Checking sync status...
echo ============================================================
w32tm /query /status

echo.
echo ============================================================
echo  Peer/server details:
echo ============================================================
w32tm /query /peers

echo.
echo If "Last Successful Sync Time" shows a recent timestamp above,
echo the fix worked. Poll interval is now 64s (was 900s).
echo.
echo NOTE: If time still drifts, check:
echo   - VM? Enable host time sync in hypervisor settings instead.
echo   - CMOS battery? Replace if PC clock resets on power loss.
pause
