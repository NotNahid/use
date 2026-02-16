# QuickTools.ps1 - ULTIMATE EDITION WITH YOUR CUSTOM AVATAR ICON

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Drawing

# === DOWNLOAD YOUR AVATAR AS ICON ===
function Get-AvatarIcon {
    param([string]$imageUrl = "https://avatars.githubusercontent.com/u/218765473?v=4")

    $tempImagePath = "$env:TEMP\QuickToolsAvatar.png"
    $tempIconPath  = "$env:TEMP\QuickToolsAvatar.ico"

    try {
        Write-Host "Downloading your avatar..." -ForegroundColor Cyan
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($imageUrl, $tempImagePath)

        $image   = [System.Drawing.Image]::FromFile($tempImagePath)
        $bitmap  = New-Object System.Drawing.Bitmap(32, 32)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($image, 0, 0, 32, 32)

        $hIcon = $bitmap.GetHicon()
        $icon  = [System.Drawing.Icon]::FromHandle($hIcon)

        $fileStream = New-Object System.IO.FileStream($tempIconPath, [System.IO.FileMode]::Create)
        $icon.Save($fileStream)
        $fileStream.Close()

        $graphics.Dispose()
        $bitmap.Dispose()
        $image.Dispose()
        $webClient.Dispose()

        Write-Host "Avatar loaded successfully!" -ForegroundColor Green
        return $icon

    } catch {
        Write-Host "Could not load avatar, using default icon" -ForegroundColor Yellow
        return [System.Drawing.SystemIcons]::Application
    }
}

# Load your avatar icon
$icon = Get-AvatarIcon

# Create tray icon
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon    = $icon
$notifyIcon.Visible = $true
$notifyIcon.Text    = "QuickTools Ultimate - Right-click for options"

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# ╔══════════════════════════════════════════════════╗
# ║           PRODUCTIVITY TOOLS SECTION             ║
# ╚══════════════════════════════════════════════════╝

$prodHeader = New-Object System.Windows.Forms.ToolStripMenuItem
$prodHeader.Text    = "── Productivity ──"
$prodHeader.Enabled = $false
$contextMenu.Items.Add($prodHeader) | Out-Null

# === 1. CREATE SHORTCUT ===
$shortcutItem = New-Object System.Windows.Forms.ToolStripMenuItem
$shortcutItem.Text = "🔗  Create Shortcut on Desktop"
$shortcutItem.Add_Click({
    $target = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter path, URL, or app name:", "Create Shortcut", "")
    if ($target) {
        $name = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter shortcut name:", "Shortcut Name", "New Shortcut")
        if ($name) {
            $desktop  = [Environment]::GetFolderPath('Desktop')
            $shell    = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut("$desktop\$name.lnk")
            $shortcut.TargetPath = $target
            $shortcut.Save()
            [System.Windows.Forms.MessageBox]::Show(
                "Shortcut '$name' created on Desktop!", "Success")
        }
    }
})
$contextMenu.Items.Add($shortcutItem) | Out-Null

# === 2. QUICK NOTE ===
$noteItem = New-Object System.Windows.Forms.ToolStripMenuItem
$noteItem.Text = "📝  Quick Note to Desktop"
$noteItem.Add_Click({
    $note = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter your note:", "Quick Note", "")
    if ($note) {
        $desktop   = [Environment]::GetFolderPath('Desktop')
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $filename  = "Note_$timestamp.txt"
        $note | Out-File "$desktop\$filename"
        [System.Windows.Forms.MessageBox]::Show(
            "Note saved as: $filename", "Saved")
    }
})
$contextMenu.Items.Add($noteItem) | Out-Null

# === 3. SET QUICK TIMER ===
$timerItem = New-Object System.Windows.Forms.ToolStripMenuItem
$timerItem.Text = "⏱️  Set Quick Timer"
$timerItem.Add_Click({
    $minutes = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Timer in minutes:", "Quick Timer", "5")
    if ($minutes -match '^\d+$') {
        $message = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Reminder message:", "Message", "Time is up!")
        [System.Windows.Forms.MessageBox]::Show(
            "Timer set for $minutes minutes!", "Started")
        Start-Job -ScriptBlock {
            param($min, $msg)
            Start-Sleep -Seconds ($min * 60)
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show($msg, "Timer Alert!")
        } -ArgumentList $minutes, $message | Out-Null
    }
})
$contextMenu.Items.Add($timerItem) | Out-Null

# === 4. QUICK CALCULATE ===
$calcItem = New-Object System.Windows.Forms.ToolStripMenuItem
$calcItem.Text = "🧮  Quick Calculate"
$calcItem.Add_Click({
    $expression = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter calculation (e.g., 5*8+12):", "Calculator", "")
    if ($expression) {
        try {
            # Sanitise: only allow numbers and math operators
            $sanitised = $expression -replace '[^0-9\+\-\*\/\.\(\)\%\s]', ''
            $result = Invoke-Expression $sanitised
            [System.Windows.Forms.Clipboard]::SetText($result.ToString())
            [System.Windows.Forms.MessageBox]::Show(
                "$expression = $result`n`n(Copied to clipboard!)",
                "Result: $result")
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Invalid expression!", "Error")
        }
    }
})
$contextMenu.Items.Add($calcItem) | Out-Null

# === 5. GOOGLE SEARCH ===
$googleItem = New-Object System.Windows.Forms.ToolStripMenuItem
$googleItem.Text = "🔍  Quick Google Search"
$googleItem.Add_Click({
    $query = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Search Google for:", "Google Search", "")
    if ($query) {
        Start-Process "https://www.google.com/search?q=$([uri]::EscapeDataString($query))"
    }
})
$contextMenu.Items.Add($googleItem) | Out-Null

# === 6. SAVE CLIPBOARD TEXT ===
$clipboardItem = New-Object System.Windows.Forms.ToolStripMenuItem
$clipboardItem.Text = "📋  Save Clipboard Text"
$clipboardItem.Add_Click({
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $text      = [System.Windows.Forms.Clipboard]::GetText()
        $desktop   = [Environment]::GetFolderPath('Desktop')
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $text | Out-File "$desktop\Clipboard_$timestamp.txt"
        [System.Windows.Forms.MessageBox]::Show(
            "Clipboard saved to Desktop!", "Saved")
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Clipboard is empty!", "Warning")
    }
})
$contextMenu.Items.Add($clipboardItem) | Out-Null

# === 7. SCREENSHOT ===
$screenshotItem = New-Object System.Windows.Forms.ToolStripMenuItem
$screenshotItem.Text = "📸  Take Screenshot"
$screenshotItem.Add_Click({
    $desktop   = [Environment]::GetFolderPath('Desktop')
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $filename  = "$desktop\Screenshot_$timestamp.png"
    $bounds    = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap    = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics  = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bitmap.Save($filename)
    $graphics.Dispose()
    $bitmap.Dispose()
    [System.Windows.Forms.MessageBox]::Show(
        "Screenshot saved to Desktop!", "Captured")
})
$contextMenu.Items.Add($screenshotItem) | Out-Null

# === NEW 8. MULTI-CLIPBOARD MANAGER ===
$script:clipHistory = [System.Collections.ArrayList]@()
$clipManagerItem = New-Object System.Windows.Forms.ToolStripMenuItem
$clipManagerItem.Text = "📚  Clipboard History Manager"

$clipSaveItem = New-Object System.Windows.Forms.ToolStripMenuItem
$clipSaveItem.Text = "Save current clipboard to history"
$clipSaveItem.Add_Click({
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $text = [System.Windows.Forms.Clipboard]::GetText()
        $script:clipHistory.Add($text) | Out-Null
        $notifyIcon.BalloonTipTitle = "Clipboard Saved"
        $notifyIcon.BalloonTipText  = "Entry #$($script:clipHistory.Count) saved"
        $notifyIcon.ShowBalloonTip(1500)
    }
})
$clipManagerItem.DropDownItems.Add($clipSaveItem) | Out-Null

$clipViewItem = New-Object System.Windows.Forms.ToolStripMenuItem
$clipViewItem.Text = "View & restore from history"
$clipViewItem.Add_Click({
    if ($script:clipHistory.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Clipboard history is empty!", "Empty")
        return
    }
    $list = ""
    for ($i = 0; $i -lt $script:clipHistory.Count; $i++) {
        $preview = $script:clipHistory[$i]
        if ($preview.Length -gt 60) { $preview = $preview.Substring(0,60) + "..." }
        $list += "$($i+1). $preview`n"
    }
    $choice = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Clipboard History:`n$list`nEnter number to restore:", "Clipboard History", "1")
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $script:clipHistory.Count) {
            [System.Windows.Forms.Clipboard]::SetText($script:clipHistory[$idx])
            $notifyIcon.BalloonTipTitle = "Clipboard Restored"
            $notifyIcon.BalloonTipText  = "Entry #$choice copied to clipboard"
            $notifyIcon.ShowBalloonTip(1500)
        }
    }
})
$clipManagerItem.DropDownItems.Add($clipViewItem) | Out-Null

$clipClearItem = New-Object System.Windows.Forms.ToolStripMenuItem
$clipClearItem.Text = "Clear history"
$clipClearItem.Add_Click({
    $script:clipHistory.Clear()
    [System.Windows.Forms.MessageBox]::Show("Clipboard history cleared!", "Done")
})
$clipManagerItem.DropDownItems.Add($clipClearItem) | Out-Null

$contextMenu.Items.Add($clipManagerItem) | Out-Null

# === NEW 9. TEXT TRANSFORMER ===
$textTransformItem = New-Object System.Windows.Forms.ToolStripMenuItem
$textTransformItem.Text = "🔤  Text Transformer (clipboard)"

$toUpperItem = New-Object System.Windows.Forms.ToolStripMenuItem
$toUpperItem.Text = "UPPERCASE"
$toUpperItem.Add_Click({
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $t = [System.Windows.Forms.Clipboard]::GetText().ToUpper()
        [System.Windows.Forms.Clipboard]::SetText($t)
        $notifyIcon.BalloonTipText = "Text converted to UPPERCASE"
        $notifyIcon.ShowBalloonTip(1500)
    }
})
$textTransformItem.DropDownItems.Add($toUpperItem) | Out-Null

$toLowerItem = New-Object System.Windows.Forms.ToolStripMenuItem
$toLowerItem.Text = "lowercase"
$toLowerItem.Add_Click({
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $t = [System.Windows.Forms.Clipboard]::GetText().ToLower()
        [System.Windows.Forms.Clipboard]::SetText($t)
        $notifyIcon.BalloonTipText = "Text converted to lowercase"
        $notifyIcon.ShowBalloonTip(1500)
    }
})
$textTransformItem.DropDownItems.Add($toLowerItem) | Out-Null

$toTitleItem = New-Object System.Windows.Forms.ToolStripMenuItem
$toTitleItem.Text = "Title Case"
$toTitleItem.Add_Click({
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $t = (Get-Culture).TextInfo.ToTitleCase(
            [System.Windows.Forms.Clipboard]::GetText().ToLower())
        [System.Windows.Forms.Clipboard]::SetText($t)
        $notifyIcon.BalloonTipText = "Text converted to Title Case"
        $notifyIcon.ShowBalloonTip(1500)
    }
})
$textTransformItem.DropDownItems.Add($toTitleItem) | Out-Null

$reverseItem = New-Object System.Windows.Forms.ToolStripMenuItem
$reverseItem.Text = "Reverse Text"
$reverseItem.Add_Click({
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $chars = [System.Windows.Forms.Clipboard]::GetText().ToCharArray()
        [Array]::Reverse($chars)
        [System.Windows.Forms.Clipboard]::SetText(-join $chars)
        $notifyIcon.BalloonTipText = "Text reversed!"
        $notifyIcon.ShowBalloonTip(1500)
    }
})
$textTransformItem.DropDownItems.Add($reverseItem) | Out-Null

$trimLinesItem = New-Object System.Windows.Forms.ToolStripMenuItem
$trimLinesItem.Text = "Remove empty lines"
$trimLinesItem.Add_Click({
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $t = ([System.Windows.Forms.Clipboard]::GetText() -split "`r?`n" |
              Where-Object { $_.Trim() -ne '' }) -join "`r`n"
        [System.Windows.Forms.Clipboard]::SetText($t)
        $notifyIcon.BalloonTipText = "Empty lines removed!"
        $notifyIcon.ShowBalloonTip(1500)
    }
})
$textTransformItem.DropDownItems.Add($trimLinesItem) | Out-Null

$sortLinesItem = New-Object System.Windows.Forms.ToolStripMenuItem
$sortLinesItem.Text = "Sort lines A-Z"
$sortLinesItem.Add_Click({
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $t = ([System.Windows.Forms.Clipboard]::GetText() -split "`r?`n" |
              Sort-Object) -join "`r`n"
        [System.Windows.Forms.Clipboard]::SetText($t)
        $notifyIcon.BalloonTipText = "Lines sorted A-Z!"
        $notifyIcon.ShowBalloonTip(1500)
    }
})
$textTransformItem.DropDownItems.Add($sortLinesItem) | Out-Null

$wordCountItem = New-Object System.Windows.Forms.ToolStripMenuItem
$wordCountItem.Text = "Word / Char count"
$wordCountItem.Add_Click({
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $text   = [System.Windows.Forms.Clipboard]::GetText()
        $words  = ($text -split '\s+' | Where-Object { $_ }).Count
        $chars  = $text.Length
        $lines  = ($text -split "`r?`n").Count
        [System.Windows.Forms.MessageBox]::Show(
            "Characters: $chars`nWords: $words`nLines: $lines",
            "Text Statistics")
    }
})
$textTransformItem.DropDownItems.Add($wordCountItem) | Out-Null

$contextMenu.Items.Add($textTransformItem) | Out-Null

# === NEW 10. PASSWORD GENERATOR ===
$passwordItem = New-Object System.Windows.Forms.ToolStripMenuItem
$passwordItem.Text = "🔐  Password Generator"
$passwordItem.Add_Click({
    $length = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Password length:", "Password Generator", "16")
    if ($length -match '^\d+$') {
        $len   = [int]$length
        $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?'
        $bytes = New-Object byte[] $len
        $rng   = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
        $rng.GetBytes($bytes)
        $password = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
        $rng.Dispose()
        [System.Windows.Forms.Clipboard]::SetText($password)
        [System.Windows.Forms.MessageBox]::Show(
            "Generated Password:`n`n$password`n`n(Copied to clipboard!)",
            "Password Generator")
    }
})
$contextMenu.Items.Add($passwordItem) | Out-Null

# === NEW 11. HASH FILE CHECKER ===
$hashItem = New-Object System.Windows.Forms.ToolStripMenuItem
$hashItem.Text = "🔏  File Hash Checker"
$hashItem.Add_Click({
    $openFile = New-Object System.Windows.Forms.OpenFileDialog
    $openFile.Title = "Select file to hash"
    if ($openFile.ShowDialog() -eq 'OK') {
        $md5    = (Get-FileHash $openFile.FileName -Algorithm MD5).Hash
        $sha256 = (Get-FileHash $openFile.FileName -Algorithm SHA256).Hash
        $info   = "File: $($openFile.FileName | Split-Path -Leaf)`n`n"
        $info  += "MD5:`n$md5`n`nSHA256:`n$sha256"
        [System.Windows.Forms.Clipboard]::SetText($sha256)
        [System.Windows.Forms.MessageBox]::Show(
            "$info`n`n(SHA256 copied to clipboard)", "File Hash")
    }
})
$contextMenu.Items.Add($hashItem) | Out-Null

# === NEW 12. COLOR PICKER ===
$colorPickerItem = New-Object System.Windows.Forms.ToolStripMenuItem
$colorPickerItem.Text = "🎨  Color Picker"
$colorPickerItem.Add_Click({
    $colorDialog = New-Object System.Windows.Forms.ColorDialog
    $colorDialog.FullOpen = $true
    if ($colorDialog.ShowDialog() -eq 'OK') {
        $c   = $colorDialog.Color
        $hex = "#{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B
        $rgb = "rgb($($c.R), $($c.G), $($c.B))"
        $hsl = ""
        # Calculate HSL
        $r2 = $c.R / 255.0; $g2 = $c.G / 255.0; $b2 = $c.B / 255.0
        $max = [Math]::Max($r2, [Math]::Max($g2, $b2))
        $min = [Math]::Min($r2, [Math]::Min($g2, $b2))
        $l   = ($max + $min) / 2
        if ($max -eq $min) { $h = 0; $s = 0 }
        else {
            $d = $max - $min
            $s = if ($l -gt 0.5) { $d / (2 - $max - $min) } else { $d / ($max + $min) }
            $h = switch ($max) {
                $r2 { (($g2 - $b2) / $d + $(if ($g2 -lt $b2) {6} else {0})) }
                $g2 { (($b2 - $r2) / $d + 2) }
                $b2 { (($r2 - $g2) / $d + 4) }
            }
            $h = $h * 60
        }
        $hsl = "hsl($([math]::Round($h)), $([math]::Round($s*100))%, $([math]::Round($l*100))%)"
        [System.Windows.Forms.Clipboard]::SetText($hex)
        [System.Windows.Forms.MessageBox]::Show(
            "HEX: $hex`nRGB: $rgb`nHSL: $hsl`n`n(HEX copied to clipboard!)",
            "Color Picker")
    }
})
$contextMenu.Items.Add($colorPickerItem) | Out-Null

# === NEW 13. BASE64 ENCODE / DECODE ===
$base64Item = New-Object System.Windows.Forms.ToolStripMenuItem
$base64Item.Text = "🔄  Base64 Encode/Decode"

$b64EncodeItem = New-Object System.Windows.Forms.ToolStripMenuItem
$b64EncodeItem.Text = "Encode clipboard text"
$b64EncodeItem.Add_Click({
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $encoded = [Convert]::ToBase64String(
            [System.Text.Encoding]::UTF8.GetBytes(
                [System.Windows.Forms.Clipboard]::GetText()))
        [System.Windows.Forms.Clipboard]::SetText($encoded)
        [System.Windows.Forms.MessageBox]::Show(
            "Encoded and copied to clipboard!`n`n$encoded", "Base64 Encode")
    }
})
$base64Item.DropDownItems.Add($b64EncodeItem) | Out-Null

$b64DecodeItem = New-Object System.Windows.Forms.ToolStripMenuItem
$b64DecodeItem.Text = "Decode clipboard text"
$b64DecodeItem.Add_Click({
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        try {
            $decoded = [System.Text.Encoding]::UTF8.GetString(
                [Convert]::FromBase64String(
                    [System.Windows.Forms.Clipboard]::GetText().Trim()))
            [System.Windows.Forms.Clipboard]::SetText($decoded)
            [System.Windows.Forms.MessageBox]::Show(
                "Decoded and copied to clipboard!`n`n$decoded", "Base64 Decode")
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Clipboard does not contain valid Base64!", "Error")
        }
    }
})
$base64Item.DropDownItems.Add($b64DecodeItem) | Out-Null

$contextMenu.Items.Add($base64Item) | Out-Null

# === NEW 14. LOREM IPSUM GENERATOR ===
$loremItem = New-Object System.Windows.Forms.ToolStripMenuItem
$loremItem.Text = "📄  Lorem Ipsum Generator"
$loremItem.Add_Click({
    $paragraphs = [Microsoft.VisualBasic.Interaction]::InputBox(
        "How many paragraphs?", "Lorem Ipsum", "3")
    if ($paragraphs -match '^\d+$') {
        $lorem = @(
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
            "Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius, turpis et commodo pharetra, est eros bibendum elit, nec luctus magna felis sollicitudin mauris.",
            "Praesent dapibus, neque id cursus faucibus, tortor neque egestas augue, eu vulputate magna eros eu erat. Aliquam erat volutpat. Nam dui mi, tincidunt quis, accumsan porttitor, facilisis luctus, metus.",
            "Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Vestibulum tortor quam, feugiat vitae, ultricies eget, tempor sit amet, ante. Donec eu libero sit amet quam egestas semper."
        )
        $output = ""
        for ($i = 0; $i -lt [int]$paragraphs; $i++) {
            $output += $lorem[$i % $lorem.Count] + "`r`n`r`n"
        }
        [System.Windows.Forms.Clipboard]::SetText($output.Trim())
        [System.Windows.Forms.MessageBox]::Show(
            "$paragraphs paragraph(s) copied to clipboard!", "Lorem Ipsum")
    }
})
$contextMenu.Items.Add($loremItem) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

# ╔══════════════════════════════════════════════════╗
# ║            SYSTEM TOOLS SECTION                  ║
# ╚══════════════════════════════════════════════════╝

$sysHeader = New-Object System.Windows.Forms.ToolStripMenuItem
$sysHeader.Text    = "── System Tools ──"
$sysHeader.Enabled = $false
$contextMenu.Items.Add($sysHeader) | Out-Null

# === 15. QUICK OPEN LOCATIONS ===
$locationsMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$locationsMenu.Text = "📂  Quick Open..."

$desktopOpen = New-Object System.Windows.Forms.ToolStripMenuItem
$desktopOpen.Text = "Desktop"
$desktopOpen.Add_Click({ explorer ([Environment]::GetFolderPath('Desktop')) })
$locationsMenu.DropDownItems.Add($desktopOpen) | Out-Null

$downloadsOpen = New-Object System.Windows.Forms.ToolStripMenuItem
$downloadsOpen.Text = "Downloads"
$downloadsOpen.Add_Click({ explorer "$env:USERPROFILE\Downloads" })
$locationsMenu.DropDownItems.Add($downloadsOpen) | Out-Null

$documentsOpen = New-Object System.Windows.Forms.ToolStripMenuItem
$documentsOpen.Text = "Documents"
$documentsOpen.Add_Click({ explorer ([Environment]::GetFolderPath('MyDocuments')) })
$locationsMenu.DropDownItems.Add($documentsOpen) | Out-Null

$tempOpen = New-Object System.Windows.Forms.ToolStripMenuItem
$tempOpen.Text = "Temp Folder"
$tempOpen.Add_Click({ explorer $env:TEMP })
$locationsMenu.DropDownItems.Add($tempOpen) | Out-Null

$startupOpen = New-Object System.Windows.Forms.ToolStripMenuItem
$startupOpen.Text = "Startup Folder"
$startupOpen.Add_Click({
    explorer "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
})
$locationsMenu.DropDownItems.Add($startupOpen) | Out-Null

$hostsOpen = New-Object System.Windows.Forms.ToolStripMenuItem
$hostsOpen.Text = "Hosts File (Notepad)"
$hostsOpen.Add_Click({
    Start-Process notepad "C:\Windows\System32\drivers\etc\hosts"
})
$locationsMenu.DropDownItems.Add($hostsOpen) | Out-Null

$contextMenu.Items.Add($locationsMenu) | Out-Null

# === 16. SYSTEM INFO ===
$sysInfoItem = New-Object System.Windows.Forms.ToolStripMenuItem
$sysInfoItem.Text = "💻  System Info"
$sysInfoItem.Add_Click({
    $os      = Get-CimInstance Win32_OperatingSystem
    $cpu     = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ram     = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRam = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $uptime  = (Get-Date) - $os.LastBootUpTime
    $gpu     = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
    $info  = "Computer: $env:COMPUTERNAME`n"
    $info += "User: $env:USERNAME`n"
    $info += "OS: $($os.Caption)`n"
    $info += "CPU: $($cpu.Name)`n"
    $info += "GPU: $gpu`n"
    $info += "RAM: $freeRam GB free / $ram GB total`n"
    $info += "Uptime: $([math]::Round($uptime.TotalHours, 1)) hours"
    [System.Windows.Forms.MessageBox]::Show($info, "System Information")
})
$contextMenu.Items.Add($sysInfoItem) | Out-Null

# === 17. EMPTY RECYCLE BIN ===
$recycleItem = New-Object System.Windows.Forms.ToolStripMenuItem
$recycleItem.Text = "🗑️  Empty Recycle Bin"
$recycleItem.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Empty Recycle Bin?", "Confirm",
        [System.Windows.Forms.MessageBoxButtons]::YesNo)
    if ($result -eq 'Yes') {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show("Recycle Bin emptied!", "Done")
    }
})
$contextMenu.Items.Add($recycleItem) | Out-Null

# === 18. CLEAN TEMP FILES ===
$cleanItem = New-Object System.Windows.Forms.ToolStripMenuItem
$cleanItem.Text = "🧹  Clean Temp Files"
$cleanItem.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Delete temporary files?", "Confirm",
        [System.Windows.Forms.MessageBoxButtons]::YesNo)
    if ($result -eq 'Yes') {
        $before = (Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue |
                   Measure-Object -Property Length -Sum).Sum / 1MB
        Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        $after = (Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue |
                  Measure-Object -Property Length -Sum).Sum / 1MB
        $cleaned = [math]::Round($before - $after, 2)
        [System.Windows.Forms.MessageBox]::Show("Cleaned $cleaned MB!", "Done")
    }
})
$contextMenu.Items.Add($cleanItem) | Out-Null

# === 19. WIFI PASSWORD ===
$wifiItem = New-Object System.Windows.Forms.ToolStripMenuItem
$wifiItem.Text = "📶  Show WiFi Password"
$wifiItem.Add_Click({
    $networks = (netsh wlan show profiles) |
        Select-String "All User Profile" |
        ForEach-Object { ($_ -split ':')[1].Trim() }
    $list     = $networks -join "`n"
    $selected = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Available networks:`n$list`n`nEnter WiFi name:", "WiFi Password", "")
    if ($selected) {
        $password = (netsh wlan show profile name="$selected" key=clear) |
            Select-String "Key Content" |
            ForEach-Object { ($_ -split ':')[1].Trim() }
        if ($password) {
            [System.Windows.Forms.Clipboard]::SetText($password)
            [System.Windows.Forms.MessageBox]::Show(
                "WiFi: $selected`nPassword: $password`n`n(Copied to clipboard!)",
                "WiFi Password")
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "No password found!", "Not Found")
        }
    }
})
$contextMenu.Items.Add($wifiItem) | Out-Null

# === NEW 20. DISK SPACE ANALYZER ===
$diskItem = New-Object System.Windows.Forms.ToolStripMenuItem
$diskItem.Text = "💾  Disk Space Analyzer"
$diskItem.Add_Click({
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    $info   = ""
    foreach ($d in $drives) {
        $total    = [math]::Round($d.Size / 1GB, 1)
        $free     = [math]::Round($d.FreeSpace / 1GB, 1)
        $used     = $total - $free
        $pctUsed  = [math]::Round(($used / $total) * 100, 0)
        $bar      = ("█" * [math]::Floor($pctUsed / 5)) + ("░" * (20 - [math]::Floor($pctUsed / 5)))
        $info    += "Drive $($d.DeviceID)`n"
        $info    += "  [$bar] $pctUsed%`n"
        $info    += "  Used: $used GB / $total GB  (Free: $free GB)`n`n"
    }
    [System.Windows.Forms.MessageBox]::Show($info, "Disk Space Analyzer")
})
$contextMenu.Items.Add($diskItem) | Out-Null

# === NEW 21. TOP PROCESSES (RESOURCE MONITOR) ===
$topProcItem = New-Object System.Windows.Forms.ToolStripMenuItem
$topProcItem.Text = "📊  Top Processes (CPU / RAM)"
$topProcItem.Add_Click({
    $cpuProcs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 8
    $ramProcs = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 8

    $info  = "=== TOP CPU CONSUMERS ===`n"
    foreach ($p in $cpuProcs) {
        $cpuSec = [math]::Round($p.CPU, 1)
        $info  += "  $($p.ProcessName.PadRight(25)) CPU: $cpuSec s`n"
    }
    $info += "`n=== TOP RAM CONSUMERS ===`n"
    foreach ($p in $ramProcs) {
        $mb    = [math]::Round($p.WorkingSet64 / 1MB, 0)
        $info += "  $($p.ProcessName.PadRight(25)) RAM: $mb MB`n"
    }
    [System.Windows.Forms.MessageBox]::Show($info, "Top Processes")
})
$contextMenu.Items.Add($topProcItem) | Out-Null

# === NEW 22. QUICK KILL PROCESS ===
$killProcItem = New-Object System.Windows.Forms.ToolStripMenuItem
$killProcItem.Text = "☠️  Kill Process by Name"
$killProcItem.Add_Click({
    $name = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter process name to kill (e.g., notepad):", "Kill Process", "")
    if ($name) {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($procs) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Found $($procs.Count) instance(s) of '$name'.`nKill all?",
                "Confirm Kill", [System.Windows.Forms.MessageBoxButtons]::YesNo)
            if ($result -eq 'Yes') {
                $procs | Stop-Process -Force -ErrorAction SilentlyContinue
                [System.Windows.Forms.MessageBox]::Show(
                    "Process '$name' terminated!", "Done")
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "No process named '$name' found.", "Not Found")
        }
    }
})
$contextMenu.Items.Add($killProcItem) | Out-Null

# === NEW 23. NETWORK INFO ===
$netInfoItem = New-Object System.Windows.Forms.ToolStripMenuItem
$netInfoItem.Text = "🌐  Network Info"
$netInfoItem.Add_Click({
    $adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -ne '127.0.0.1' }
    $info = "=== LOCAL NETWORK ===`n"
    foreach ($a in $adapters) {
        $info += "  $($a.InterfaceAlias): $($a.IPAddress)/$($a.PrefixLength)`n"
    }
    $gateway = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Select-Object -First 1).NextHop
    $dns = (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.ServerAddresses } | Select-Object -First 1).ServerAddresses -join ', '
    $info += "`nGateway: $gateway`nDNS: $dns`n`n"

    # Public IP
    try {
        $pub = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 5).ip
        $info += "Public IP: $pub`n"
    } catch {
        $info += "Public IP: (could not retrieve)`n"
    }

    $mac = (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1).MacAddress
    $info += "MAC: $mac"

    [System.Windows.Forms.Clipboard]::SetText($info)
    [System.Windows.Forms.MessageBox]::Show(
        "$info`n`n(Copied to clipboard!)", "Network Info")
})
$contextMenu.Items.Add($netInfoItem) | Out-Null

# === NEW 24. PING / SPEED TEST ===
$pingItem = New-Object System.Windows.Forms.ToolStripMenuItem
$pingItem.Text = "📡  Quick Ping Test"
$pingItem.Add_Click({
    $host2 = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Host to ping:", "Ping Test", "8.8.8.8")
    if ($host2) {
        $results = Test-Connection -ComputerName $host2 -Count 5 -ErrorAction SilentlyContinue
        if ($results) {
            $avg = [math]::Round(($results | Measure-Object -Property Latency -Average).Average, 1)
            $min = [math]::Round(($results | Measure-Object -Property Latency -Minimum).Minimum, 1)
            $max = [math]::Round(($results | Measure-Object -Property Latency -Maximum).Maximum, 1)
            [System.Windows.Forms.MessageBox]::Show(
                "Ping to $host2 (5 packets)`n`nAvg: $avg ms`nMin: $min ms`nMax: $max ms",
                "Ping Results")
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "Could not reach $host2!", "Ping Failed")
        }
    }
})
$contextMenu.Items.Add($pingItem) | Out-Null

# === NEW 25. PORT SCANNER (QUICK) ===
$portScanItem = New-Object System.Windows.Forms.ToolStripMenuItem
$portScanItem.Text = "🔌  Quick Port Scanner"
$portScanItem.Add_Click({
    $target = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Target host/IP:", "Port Scanner", "localhost")
    if ($target) {
        $portStr = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Ports (comma-separated):", "Ports", "21,22,80,443,3389,8080")
        if ($portStr) {
            $ports   = $portStr -split ',' | ForEach-Object { [int]$_.Trim() }
            $results = ""
            foreach ($port in $ports) {
                try {
                    $tcp = New-Object System.Net.Sockets.TcpClient
                    $connect = $tcp.BeginConnect($target, $port, $null, $null)
                    $wait = $connect.AsyncWaitHandle.WaitOne(500, $false)
                    if ($wait -and $tcp.Connected) {
                        $results += "  Port $port : OPEN ✅`n"
                    } else {
                        $results += "  Port $port : CLOSED ❌`n"
                    }
                    $tcp.Close()
                } catch {
                    $results += "  Port $port : CLOSED ❌`n"
                }
            }
            [System.Windows.Forms.MessageBox]::Show(
                "Scan results for $target :`n`n$results", "Port Scanner")
        }
    }
})
$contextMenu.Items.Add($portScanItem) | Out-Null

# === NEW 26. FLUSH DNS ===
$flushDnsItem = New-Object System.Windows.Forms.ToolStripMenuItem
$flushDnsItem.Text = "🔃  Flush DNS Cache"
$flushDnsItem.Add_Click({
    ipconfig /flushdns | Out-Null
    [System.Windows.Forms.MessageBox]::Show("DNS cache flushed!", "Done")
})
$contextMenu.Items.Add($flushDnsItem) | Out-Null

# === NEW 27. LISTENING PORTS ===
$listeningItem = New-Object System.Windows.Forms.ToolStripMenuItem
$listeningItem.Text = "👂  Show Listening Ports"
$listeningItem.Add_Click({
    $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Sort-Object LocalPort | Select-Object -First 25
    $info = "PORT".PadRight(10) + "PID".PadRight(10) + "PROCESS`n"
    $info += ("-" * 45) + "`n"
    foreach ($c in $connections) {
        $procName = (Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        $info += "$($c.LocalPort)".PadRight(10) +
                 "$($c.OwningProcess)".PadRight(10) +
                 "$procName`n"
    }
    [System.Windows.Forms.MessageBox]::Show($info, "Listening Ports (Top 25)")
})
$contextMenu.Items.Add($listeningItem) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

# ╔══════════════════════════════════════════════════╗
# ║             POWER & QUICK ACTIONS               ║
# ╚══════════════════════════════════════════════════╝

$powerHeader = New-Object System.Windows.Forms.ToolStripMenuItem
$powerHeader.Text    = "── Power & Actions ──"
$powerHeader.Enabled = $false
$contextMenu.Items.Add($powerHeader) | Out-Null

# === NEW 28. QUICK RUN COMMAND ===
$runCmdItem = New-Object System.Windows.Forms.ToolStripMenuItem
$runCmdItem.Text = "⚡  Quick Run Command"
$runCmdItem.Add_Click({
    $cmd = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter PowerShell command to execute:", "Quick Run", "")
    if ($cmd) {
        try {
            $output = Invoke-Expression $cmd 2>&1 | Out-String
            if ($output.Length -gt 2000) { $output = $output.Substring(0, 2000) + "`n...truncated" }
            [System.Windows.Forms.MessageBox]::Show($output, "Output")
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Error: $($_.Exception.Message)", "Error")
        }
    }
})
$contextMenu.Items.Add($runCmdItem) | Out-Null

# === NEW 29. STARTUP MANAGER ===
$startupItem = New-Object System.Windows.Forms.ToolStripMenuItem
$startupItem.Text = "🚀  View Startup Programs"
$startupItem.Add_Click({
    $reg1 = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
    $reg2 = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue

    $info = "=== CURRENT USER STARTUP ===`n"
    if ($reg1) {
        $reg1.PSObject.Properties | Where-Object {
            $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSProvider','PSDrive')
        } | ForEach-Object { $info += "  $($_.Name): $($_.Value)`n" }
    }
    $info += "`n=== ALL USERS STARTUP ===`n"
    if ($reg2) {
        $reg2.PSObject.Properties | Where-Object {
            $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSProvider','PSDrive')
        } | ForEach-Object { $info += "  $($_.Name): $($_.Value)`n" }
    }
    [System.Windows.Forms.MessageBox]::Show($info, "Startup Programs")
})
$contextMenu.Items.Add($startupItem) | Out-Null

# === NEW 30. WINDOW ALWAYS ON TOP (toggle for any window) ===
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WindowHelper {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetWindowPos(
        IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern int GetWindowText(
        IntPtr hWnd, System.Text.StringBuilder text, int count);

    public static readonly IntPtr HWND_TOPMOST    = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST  = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
}
"@

$script:topMostWindows = @{}
$alwaysOnTopItem = New-Object System.Windows.Forms.ToolStripMenuItem
$alwaysOnTopItem.Text = "📌  Toggle Always-On-Top (next click)"
$alwaysOnTopItem.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(
        "Click OK, then click on the window you want to toggle.`nYou have 3 seconds!",
        "Always On Top")
    Start-Sleep -Seconds 3
    $hwnd = [WindowHelper]::GetForegroundWindow()
    $sb   = New-Object System.Text.StringBuilder 256
    [WindowHelper]::GetWindowText($hwnd, $sb, 256) | Out-Null
    $title = $sb.ToString()

    if ($script:topMostWindows[$hwnd]) {
        [WindowHelper]::SetWindowPos(
            $hwnd, [WindowHelper]::HWND_NOTOPMOST, 0, 0, 0, 0,
            [WindowHelper]::SWP_NOMOVE -bor [WindowHelper]::SWP_NOSIZE) | Out-Null
        $script:topMostWindows.Remove($hwnd)
        $notifyIcon.BalloonTipText = "'$title' is no longer Always-On-Top"
    } else {
        [WindowHelper]::SetWindowPos(
            $hwnd, [WindowHelper]::HWND_TOPMOST, 0, 0, 0, 0,
            [WindowHelper]::SWP_NOMOVE -bor [WindowHelper]::SWP_NOSIZE) | Out-Null
        $script:topMostWindows[$hwnd] = $true
        $notifyIcon.BalloonTipText = "'$title' is now Always-On-Top!"
    }
    $notifyIcon.BalloonTipTitle = "Always-On-Top"
    $notifyIcon.ShowBalloonTip(2000)
})
$contextMenu.Items.Add($alwaysOnTopItem) | Out-Null

# === NEW 31. BULK FILE RENAMER ===
$renamerItem = New-Object System.Windows.Forms.ToolStripMenuItem
$renamerItem.Text = "✏️  Bulk File Renamer"
$renamerItem.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select folder with files to rename"
    if ($folderBrowser.ShowDialog() -eq 'OK') {
        $folder  = $folderBrowser.SelectedPath
        $pattern = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter file filter (e.g., *.jpg, *.txt):", "Filter", "*.txt")
        $prefix  = [Microsoft.VisualBasic.Interaction]::InputBox(
            "New name prefix (files will be: prefix_001, prefix_002...):",
            "Prefix", "file")
        if ($prefix) {
            $files   = Get-ChildItem "$folder\$pattern" -File | Sort-Object Name
            $counter = 1
            foreach ($f in $files) {
                $ext     = $f.Extension
                $newName = "{0}_{1:D3}{2}" -f $prefix, $counter, $ext
                Rename-Item $f.FullName -NewName $newName -ErrorAction SilentlyContinue
                $counter++
            }
            [System.Windows.Forms.MessageBox]::Show(
                "Renamed $($counter - 1) files!", "Done")
        }
    }
})
$contextMenu.Items.Add($renamerItem) | Out-Null

# === NEW 32. FIND LARGE FILES ===
$largeFiItem = New-Object System.Windows.Forms.ToolStripMenuItem
$largeFiItem.Text = "🔎  Find Large Files"
$largeFiItem.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select folder to scan"
    if ($folderBrowser.ShowDialog() -eq 'OK') {
        $sizeMB = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Minimum file size (MB):", "Size Threshold", "100")
        if ($sizeMB -match '^\d+$') {
            $files = Get-ChildItem $folderBrowser.SelectedPath -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -gt ([int]$sizeMB * 1MB) } |
                Sort-Object Length -Descending | Select-Object -First 20
            if ($files) {
                $info = "Files larger than $sizeMB MB:`n`n"
                foreach ($f in $files) {
                    $mb    = [math]::Round($f.Length / 1MB, 1)
                    $info += "  $mb MB  -  $($f.FullName)`n"
                }
                [System.Windows.Forms.MessageBox]::Show($info, "Large Files (Top 20)")
            } else {
                [System.Windows.Forms.MessageBox]::Show(
                    "No files larger than $sizeMB MB found!", "None Found")
            }
        }
    }
})
$contextMenu.Items.Add($largeFiItem) | Out-Null

# === NEW 33. SYSTEM UPTIME & BATTERY ===
$uptimeBattItem = New-Object System.Windows.Forms.ToolStripMenuItem
$uptimeBattItem.Text = "🔋  Uptime & Battery Status"
$uptimeBattItem.Add_Click({
    $os     = Get-CimInstance Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime
    $info   = "System Uptime: $([math]::Floor($uptime.TotalDays))d $($uptime.Hours)h $($uptime.Minutes)m`n`n"

    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        $info += "Battery: $($battery.EstimatedChargeRemaining)%`n"
        $info += "Status: $($battery.Status)`n"
        $info += "Plugged in: $(if ($battery.BatteryStatus -eq 2) {'Yes'} else {'No'})`n"
        $timeLeft = $battery.EstimatedRunTime
        if ($timeLeft -and $timeLeft -lt 71582788) {
            $info += "Time remaining: $([math]::Round($timeLeft / 60, 1)) hours"
        }
    } else {
        $info += "Battery: N/A (Desktop)"
    }
    [System.Windows.Forms.MessageBox]::Show($info, "Uptime & Battery")
})
$contextMenu.Items.Add($uptimeBattItem) | Out-Null

# === NEW 34. QUICK WINDOWS SETTINGS LAUNCHER ===
$settingsMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$settingsMenu.Text = "⚙️  Quick Settings..."

$settingsItems = @{
    "Display"             = "ms-settings:display"
    "Sound"               = "ms-settings:sound"
    "Wi-Fi"               = "ms-settings:network-wifi"
    "Bluetooth"           = "ms-settings:bluetooth"
    "Apps & Features"     = "ms-settings:appsfeatures"
    "Default Apps"        = "ms-settings:defaultapps"
    "Windows Update"      = "ms-settings:windowsupdate"
    "Power & Sleep"       = "ms-settings:powersleep"
    "Storage"             = "ms-settings:storagesense"
    "About (Device Specs)" = "ms-settings:about"
    "Privacy"             = "ms-settings:privacy"
    "Night Light"         = "ms-settings:nightlight"
}

foreach ($settingName in ($settingsItems.Keys | Sort-Object)) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = $settingName
    $uri  = $settingsItems[$settingName]
    $item.Add_Click({ Start-Process $uri }.GetNewClosure())
    $settingsMenu.DropDownItems.Add($item) | Out-Null
}
$contextMenu.Items.Add($settingsMenu) | Out-Null

# === NEW 35. SCHEDULE SHUTDOWN ===
$shutdownItem = New-Object System.Windows.Forms.ToolStripMenuItem
$shutdownItem.Text = "🕐  Schedule Shutdown/Restart"

$shutdownTimer = New-Object System.Windows.Forms.ToolStripMenuItem
$shutdownTimer.Text = "Shutdown in X minutes"
$shutdownTimer.Add_Click({
    $mins = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Shutdown in how many minutes?", "Schedule Shutdown", "60")
    if ($mins -match '^\d+$') {
        $secs = [int]$mins * 60
        shutdown /s /t $secs /c "QuickTools scheduled shutdown in $mins minutes"
        [System.Windows.Forms.MessageBox]::Show(
            "Shutdown scheduled in $mins minutes.`nRun 'shutdown /a' to abort.", "Scheduled")
    }
})
$shutdownItem.DropDownItems.Add($shutdownTimer) | Out-Null

$restartTimer = New-Object System.Windows.Forms.ToolStripMenuItem
$restartTimer.Text = "Restart in X minutes"
$restartTimer.Add_Click({
    $mins = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Restart in how many minutes?", "Schedule Restart", "60")
    if ($mins -match '^\d+$') {
        $secs = [int]$mins * 60
        shutdown /r /t $secs /c "QuickTools scheduled restart in $mins minutes"
        [System.Windows.Forms.MessageBox]::Show(
            "Restart scheduled in $mins minutes.`nRun 'shutdown /a' to abort.", "Scheduled")
    }
})
$shutdownItem.DropDownItems.Add($restartTimer) | Out-Null

$cancelShutdown = New-Object System.Windows.Forms.ToolStripMenuItem
$cancelShutdown.Text = "Cancel scheduled shutdown"
$cancelShutdown.Add_Click({
    shutdown /a 2>$null
    [System.Windows.Forms.MessageBox]::Show(
        "Scheduled shutdown/restart cancelled (if any).", "Cancelled")
})
$shutdownItem.DropDownItems.Add($cancelShutdown) | Out-Null

$lockItem = New-Object System.Windows.Forms.ToolStripMenuItem
$lockItem.Text = "Lock workstation now"
$lockItem.Add_Click({
    rundll32.exe user32.dll,LockWorkStation
})
$shutdownItem.DropDownItems.Add($lockItem) | Out-Null

$contextMenu.Items.Add($shutdownItem) | Out-Null

# === NEW 36. QUICK HOSTS FILE BLOCKER ===
$hostsBlockItem = New-Object System.Windows.Forms.ToolStripMenuItem
$hostsBlockItem.Text = "🚫  Block Domain (hosts file)"
$hostsBlockItem.Add_Click({
    $domain = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter domain to block (e.g., facebook.com):", "Block Domain", "")
    if ($domain) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Add '127.0.0.1 $domain' to hosts file?`n(Requires admin)",
            "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo)
        if ($result -eq 'Yes') {
            try {
                $hostsPath = "C:\Windows\System32\drivers\etc\hosts"
                $entry     = "`n127.0.0.1 $domain`n127.0.0.1 www.$domain"
                Add-Content -Path $hostsPath -Value $entry -ErrorAction Stop
                ipconfig /flushdns | Out-Null
                [System.Windows.Forms.MessageBox]::Show(
                    "$domain blocked! DNS flushed.", "Done")
            } catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed! Run QuickTools as Administrator.", "Admin Required")
            }
        }
    }
})
$contextMenu.Items.Add($hostsBlockItem) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

# ╔══════════════════════════════════════════════════╗
# ║                FUN & MISC                        ║
# ╚══════════════════════════════════════════════════╝

$funHeader = New-Object System.Windows.Forms.ToolStripMenuItem
$funHeader.Text    = "── Fun & Misc ──"
$funHeader.Enabled = $false
$contextMenu.Items.Add($funHeader) | Out-Null

# === NEW 37. QR CODE GENERATOR (text-based, opens browser) ===
$qrItem = New-Object System.Windows.Forms.ToolStripMenuItem
$qrItem.Text = "📱  Generate QR Code"
$qrItem.Add_Click({
    $text = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter text or URL for QR code:", "QR Generator", "https://github.com")
    if ($text) {
        $encoded = [uri]::EscapeDataString($text)
        Start-Process "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$encoded"
    }
})
$contextMenu.Items.Add($qrItem) | Out-Null

# === NEW 38. RANDOM MOTIVATIONAL QUOTE ===
$quoteItem = New-Object System.Windows.Forms.ToolStripMenuItem
$quoteItem.Text = "💬  Random Motivational Quote"
$quoteItem.Add_Click({
    $quotes = @(
        "The only way to do great work is to love what you do. - Steve Jobs",
        "Innovation distinguishes between a leader and a follower. - Steve Jobs",
        "Stay hungry, stay foolish. - Steve Jobs",
        "It does not matter how slowly you go as long as you do not stop. - Confucius",
        "The future belongs to those who believe in the beauty of their dreams. - Eleanor Roosevelt",
        "Success is not final, failure is not fatal: it is the courage to continue that counts. - Winston Churchill",
        "Believe you can and you're halfway there. - Theodore Roosevelt",
        "The best time to plant a tree was 20 years ago. The second best time is now. - Chinese Proverb",
        "Your time is limited, don't waste it living someone else's life. - Steve Jobs",
        "If you're going through hell, keep going. - Winston Churchill",
        "Talk is cheap. Show me the code. - Linus Torvalds",
        "First, solve the problem. Then, write the code. - John Johnson",
        "Code is like humor. When you have to explain it, it's bad. - Cory House",
        "Simplicity is the soul of efficiency. - Austin Freeman",
        "Any fool can write code that a computer can understand. Good programmers write code that humans can understand. - Martin Fowler"
    )
    $quote = $quotes | Get-Random
    [System.Windows.Forms.Clipboard]::SetText($quote)
    $notifyIcon.BalloonTipTitle = "💬 Motivational Quote"
    $notifyIcon.BalloonTipText  = $quote
    $notifyIcon.ShowBalloonTip(5000)
    [System.Windows.Forms.MessageBox]::Show(
        "$quote`n`n(Copied to clipboard!)", "Daily Motivation")
})
$contextMenu.Items.Add($quoteItem) | Out-Null

# === NEW 39. EPOCH / DATE CONVERTER ===
$epochItem = New-Object System.Windows.Forms.ToolStripMenuItem
$epochItem.Text = "🕰️  Epoch / Date Converter"

$dateToEpoch = New-Object System.Windows.Forms.ToolStripMenuItem
$dateToEpoch.Text = "Current time → Epoch"
$dateToEpoch.Add_Click({
    $epoch = [math]::Floor(
        (New-TimeSpan -Start (Get-Date "01/01/1970") -End (Get-Date).ToUniversalTime()).TotalSeconds)
    [System.Windows.Forms.Clipboard]::SetText($epoch.ToString())
    [System.Windows.Forms.MessageBox]::Show(
        "Current epoch: $epoch`n`n(Copied to clipboard!)", "Epoch")
})
$epochItem.DropDownItems.Add($dateToEpoch) | Out-Null

$epochToDate = New-Object System.Windows.Forms.ToolStripMenuItem
$epochToDate.Text = "Epoch → Date"
$epochToDate.Add_Click({
    $input2 = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter epoch timestamp:", "Epoch to Date", "")
    if ($input2 -match '^\d+$') {
        $date = (Get-Date "01/01/1970").AddSeconds([long]$input2)
        $result = "$date (UTC)"
        [System.Windows.Forms.Clipboard]::SetText($result)
        [System.Windows.Forms.MessageBox]::Show(
            "$result`n`n(Copied to clipboard!)", "Date")
    }
})
$epochItem.DropDownItems.Add($epochToDate) | Out-Null

$contextMenu.Items.Add($epochItem) | Out-Null

# === NEW 40. UUID GENERATOR ===
$uuidItem = New-Object System.Windows.Forms.ToolStripMenuItem
$uuidItem.Text = "🆔  Generate UUID/GUID"
$uuidItem.Add_Click({
    $uuid = [guid]::NewGuid().ToString()
    [System.Windows.Forms.Clipboard]::SetText($uuid)
    $notifyIcon.BalloonTipTitle = "UUID Generated"
    $notifyIcon.BalloonTipText  = $uuid
    $notifyIcon.ShowBalloonTip(2000)
    [System.Windows.Forms.MessageBox]::Show(
        "UUID: $uuid`n`n(Copied to clipboard!)", "UUID Generator")
})
$contextMenu.Items.Add($uuidItem) | Out-Null

# === NEW 41. WHAT IS MY IP (quick balloon) ===
$myIpItem = New-Object System.Windows.Forms.ToolStripMenuItem
$myIpItem.Text = "🌍  What Is My Public IP?"
$myIpItem.Add_Click({
    try {
        $ip = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 5).ip
        [System.Windows.Forms.Clipboard]::SetText($ip)
        $notifyIcon.BalloonTipTitle = "Your Public IP"
        $notifyIcon.BalloonTipText  = "$ip (copied!)"
        $notifyIcon.ShowBalloonTip(3000)
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not retrieve public IP!", "Error")
    }
})
$contextMenu.Items.Add($myIpItem) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

# === EXIT ===
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = "❌  Exit QuickTools"
$exitItem.Add_Click({
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
$contextMenu.Items.Add($exitItem) | Out-Null

# === WIRE UP ===
$notifyIcon.ContextMenuStrip  = $contextMenu
$notifyIcon.BalloonTipTitle   = "QuickTools Ultimate Active!"
$notifyIcon.BalloonTipText    = "Right-click the tray icon for 30+ tools"
$notifyIcon.ShowBalloonTip(3000)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   QuickTools ULTIMATE is running!     " -ForegroundColor Green
Write-Host "   30+ tools in your system tray       " -ForegroundColor Green
Write-Host "   Look for YOUR AVATAR in the tray!   " -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

[System.Windows.Forms.Application]::Run()
