:: RESET WINDOWS TIME SERVICE
net stop w32time
w32tm /unregister
w32tm /register
net start w32time

:: FIX BAD REGISTRY SETTINGS
reg add HKLM\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient /v SpecialPollInterval /t REG_DWORD /d 900 /f
reg add HKLM\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient /v CompatibilityFlags /t REG_DWORD /d 0 /f

:: SET STABLE NTP SERVERS (GOOGLE + MICROSOFT + NIST)
w32tm /config /manualpeerlist:"time.google.com,0x1 time.windows.com,0x1 time.nist.gov,0x1" /syncfromflags:manual /update

:: ENSURE FIREWALL ALLOWS NTP (UDP 123)
netsh advfirewall firewall delete rule name="NTP"
netsh advfirewall firewall delete rule name="NTP-IN"
netsh advfirewall firewall add rule name="NTP" dir=out protocol=udp localport=123 action=allow
netsh advfirewall firewall add rule name="NTP-IN" dir=in protocol=udp localport=123 action=allow

:: RESTART SERVICE AGAIN
net stop w32time
net start w32time

:: FORCE TIME SYNC
w32tm /resync /force
