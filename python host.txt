
@echo off
:: Switch to the D drive (where your files are)
cd /d D:\
:: Run the server
python -m http.server --bind 0.0.0.0 8080




@echo off
:: Switch to the D drive (where your files are)
cd /d D:\The SUbtile meham
:: Run the server
python -m http.server --bind 0.0.0.0 8080


Alternative: The "Startup Folder" Method (Easier)
If you want the server to start only after you log in (and you want to see the black window so you know it's running), use this method instead.

Press Win + R on your keyboard.

Type shell:startup and press Enter. This opens the special Startup folder.

Right-click your start_server.bat file -> Create Shortcut.

Move that shortcut into the Startup folder you just opened.




> Cloudflair Way:
> If you haven't installed Cloudflare yet, run this in PowerShell (Run as Administrator):
> winget install Cloudflare.cloudflared
> cloudflared tunnel --url http://localhost:8080
