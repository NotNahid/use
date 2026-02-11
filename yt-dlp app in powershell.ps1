#Region Initialization
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables for download control
$script:downloadProcess = $null
$script:isDownloading = $false
$script:outputEvent = $null
$script:errorEvent = $null
$script:exitEvent = $null
$script:downloadHistory = @()
$script:configFile = Join-Path $env:APPDATA "YouTubeDownloaderPro\config.json"
#EndRegion

#Region Configuration Management
function Save-Configuration {
    param($Config)
    
    try {
        $configDir = Split-Path $script:configFile -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        $Config | ConvertTo-Json | Set-Content -Path $script:configFile
    } catch {
        # Silent fail - not critical
    }
}

function Load-Configuration {
    try {
        if (Test-Path $script:configFile) {
            return Get-Content -Path $script:configFile -Raw | ConvertFrom-Json
        }
    } catch {
        # Silent fail - return defaults
    }
    return $null
}
#EndRegion

#Region Dependency Management
function Test-CommandExists {
    param($command)
    $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}

function Test-Dependencies {
    $issues = @()
    $canAutoFix = $false
    
    if (-not (Test-CommandExists 'yt-dlp')) {
        $issues += "❌ yt-dlp is NOT installed"
        $canAutoFix = $true
    } else {
        try {
            $version = & yt-dlp --version 2>$null
            $issues += "✅ yt-dlp is installed (version: $version)"
        } catch {
            $issues += "✅ yt-dlp is installed"
        }
    }
    
    if (-not (Test-CommandExists 'ffmpeg')) {
        $issues += "❌ ffmpeg is NOT installed (required for video merging and audio conversion)"
        $canAutoFix = $true
    } else {
        try {
            $version = & ffmpeg -version 2>$null | Select-Object -First 1
            $issues += "✅ ffmpeg is installed"
        } catch {
            $issues += "✅ ffmpeg is installed"
        }
    }
    
    if ($canAutoFix) {
        if (Test-CommandExists 'winget') {
            $issues += "✅ winget is available (can auto-install missing packages)"
        } else {
            $issues += "⚠️ winget not available (manual installation required)"
        }
    }
    
    return @{
        Issues = $issues
        CanAutoFix = $canAutoFix
        HasWinget = (Test-CommandExists 'winget')
        HasYtDlp = (Test-CommandExists 'yt-dlp')
        HasFfmpeg = (Test-CommandExists 'ffmpeg')
    }
}

function Install-Dependencies {
    param($StatusTextBox, $Form)
    
    if (-not (Test-CommandExists 'winget')) {
        [System.Windows.Forms.MessageBox]::Show("winget is not available. Please install yt-dlp and ffmpeg manually from:`n`nyt-dlp: https://github.com/yt-dlp/yt-dlp/releases`nffmpeg: https://ffmpeg.org/download.html", 'Manual Installation Required', 'OK', 'Warning')
        return $false
    }
    
    $Form.Invoke({
        $StatusTextBox.AppendText("Installing missing dependencies...`r`n`r`n")
    })
    
    try {
        if (-not (Test-CommandExists 'yt-dlp')) {
            $Form.Invoke({ $StatusTextBox.AppendText("Installing yt-dlp...`r`n") })
            $process = Start-Process -FilePath 'winget' -ArgumentList 'install', 'yt-dlp', '--silent', '--accept-package-agreements', '--accept-source-agreements' -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                $Form.Invoke({ $StatusTextBox.AppendText("✅ yt-dlp installed successfully`r`n") })
            } else {
                $Form.Invoke({ $StatusTextBox.AppendText("❌ Failed to install yt-dlp`r`n") })
                return $false
            }
        }
        
        if (-not (Test-CommandExists 'ffmpeg')) {
            $Form.Invoke({ $StatusTextBox.AppendText("Installing ffmpeg...`r`n") })
            $process = Start-Process -FilePath 'winget' -ArgumentList 'install', 'ffmpeg', '--silent', '--accept-package-agreements', '--accept-source-agreements' -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                $Form.Invoke({ $StatusTextBox.AppendText("✅ ffmpeg installed successfully`r`n") })
            } else {
                $Form.Invoke({ $StatusTextBox.AppendText("❌ Failed to install ffmpeg`r`n") })
                return $false
            }
        }
        
        $Form.Invoke({
            $StatusTextBox.AppendText("`r`n✅ All dependencies installed! Please restart this application.`r`n")
        })
        [System.Windows.Forms.MessageBox]::Show("Dependencies installed successfully!`n`nPlease close and restart this application for changes to take effect.", 'Success', 'OK', 'Information')
        return $true
        
    } catch {
        $Form.Invoke({
            $StatusTextBox.AppendText("❌ Error: $($_.Exception.Message)`r`n")
        })
        [System.Windows.Forms.MessageBox]::Show("Error installing dependencies: $($_.Exception.Message)", 'Error', 'OK', 'Error')
        return $false
    }
}
#EndRegion

#Region Download Engine
function Stop-Download {
    param($StatusTextBox, $Form)
    
    if ($script:downloadProcess -and -not $script:downloadProcess.HasExited) {
        try {
            $Form.Invoke({
                $StatusTextBox.AppendText("`r`n⚠️ Attempting graceful shutdown...`r`n")
            })
            
            # Try graceful shutdown first
            if (-not $script:downloadProcess.CloseMainWindow()) {
                Start-Sleep -Milliseconds 500
                if (-not $script:downloadProcess.HasExited) {
                    $Form.Invoke({
                        $StatusTextBox.AppendText("⚠️ Forcing termination...`r`n")
                    })
                    $script:downloadProcess.Kill()
                }
            }
            
            $script:downloadProcess = $null
            $script:isDownloading = $false
            return $true
        } catch {
            $Form.Invoke({
                $StatusTextBox.AppendText("❌ Error stopping download: $($_.Exception.Message)`r`n")
            })
            return $false
        }
    }
    return $false
}

function Build-YtDlpArguments {
    param(
        $RadioVideo,
        $RadioAudio,
        $RadioVideoMKV,
        $RadioAudioOther,
        $RadioCustom,
        $ComboVideoQuality,
        $ComboAudioQuality,
        $ComboAudioFormat,
        $CheckboxPlaylist,
        $CheckboxSubtitles,
        $CheckboxThumbnail,
        $CheckboxMetadata,
        $CheckboxRetry,
        $CheckboxRateLimit,
        $TextboxRateLimit,
        $TextboxCustom,
        $TextboxOutput,
        $URL
    )
    
    $ytdlpArgs = @()
    $ytdlpArgs += '--newline'
    $ytdlpArgs += '--no-warnings'
    $ytdlpArgs += '--progress'
    
    # Add retry support if enabled
    if ($CheckboxRetry.Checked) {
        $ytdlpArgs += '--retries', '10'
        $ytdlpArgs += '--fragment-retries', '10'
        $ytdlpArgs += '--retry-sleep', '3'
    }
    
    # Add rate limiting if enabled
    if ($CheckboxRateLimit.Checked -and -not [string]::IsNullOrWhiteSpace($TextboxRateLimit.Text)) {
        $ytdlpArgs += '--limit-rate', $TextboxRateLimit.Text
    }
    
    if ($RadioVideo.Checked) {
        switch ($ComboVideoQuality.SelectedItem) {
            'Best' { $ytdlpArgs += '-f', 'bestvideo+bestaudio/best' }
            '2160p (4K)' { $ytdlpArgs += '-f', 'bestvideo[height<=2160]+bestaudio/best[height<=2160]' }
            '1440p' { $ytdlpArgs += '-f', 'bestvideo[height<=1440]+bestaudio/best[height<=1440]' }
            '1080p' { $ytdlpArgs += '-f', 'bestvideo[height<=1080]+bestaudio/best[height<=1080]' }
            '720p' { $ytdlpArgs += '-f', 'bestvideo[height<=720]+bestaudio/best[height<=720]' }
            '480p' { $ytdlpArgs += '-f', 'bestvideo[height<=480]+bestaudio/best[height<=480]' }
            '360p' { $ytdlpArgs += '-f', 'bestvideo[height<=360]+bestaudio/best[height<=360]' }
        }
        $ytdlpArgs += '--merge-output-format', 'mp4'
    }
    elseif ($RadioAudio.Checked) {
        $ytdlpArgs += '-f', 'bestaudio'
        $ytdlpArgs += '--extract-audio'
        $ytdlpArgs += '--audio-format', 'mp3'
        $audioQuality = switch ($ComboAudioQuality.SelectedItem) {
            'Best (0)' { '0' }
            'High (2)' { '2' }
            'Medium (5)' { '5' }
            'Low (9)' { '9' }
        }
        $ytdlpArgs += '--audio-quality', $audioQuality
    }
    elseif ($RadioVideoMKV.Checked) {
        $ytdlpArgs += '-f', 'bestvideo+bestaudio'
        $ytdlpArgs += '--merge-output-format', 'mkv'
    }
    elseif ($RadioAudioOther.Checked) {
        $ytdlpArgs += '-f', 'bestaudio'
        $ytdlpArgs += '--extract-audio'
        $ytdlpArgs += '--audio-format', $ComboAudioFormat.SelectedItem
        $audioQuality = switch ($ComboAudioQuality.SelectedItem) {
            'Best (0)' { '0' }
            'High (2)' { '2' }
            'Medium (5)' { '5' }
            'Low (9)' { '9' }
        }
        $ytdlpArgs += '--audio-quality', $audioQuality
    }
    else {
        # Custom format - use proper parser
        $customOptions = $TextboxCustom.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($customOptions)) {
            throw "Please enter custom options."
        }
        
        # Parse with proper quote handling
        try {
            $tokens = [System.Management.Automation.PSParser]::Tokenize($customOptions, [ref]$null)
            $parsed = $tokens | Where-Object { $_.Type -in @('CommandArgument', 'String') } | ForEach-Object {
                if ($_.Type -eq 'String') {
                    $_.Content.Trim('"', "'")
                } else {
                    $_.Content
                }
            }
            $ytdlpArgs += $parsed
        } catch {
            # Fallback to simple split if parser fails
            $ytdlpArgs += $customOptions -split '\s+'
        }
    }
    
    if ($CheckboxPlaylist.Checked) {
        $ytdlpArgs += '--yes-playlist'
    } else {
        $ytdlpArgs += '--no-playlist'
    }
    
    if ($CheckboxSubtitles.Checked) {
        $ytdlpArgs += '--write-subs', '--write-auto-subs', '--sub-lang', 'en', '--embed-subs'
    }
    
    if ($CheckboxThumbnail.Checked) {
        $ytdlpArgs += '--embed-thumbnail'
    }
    
    if ($CheckboxMetadata.Checked) {
        $ytdlpArgs += '--embed-metadata'
    }
    
    # Improved playlist output with zero-padded numbering
    if ($CheckboxPlaylist.Checked) {
        $ytdlpArgs += '-o', (Join-Path $TextboxOutput.Text '%(playlist)s/%(playlist_index)02d - %(title)s.%(ext)s')
    } else {
        $ytdlpArgs += '-o', (Join-Path $TextboxOutput.Text '%(title)s.%(ext)s')
    }
    
    $ytdlpArgs += $URL
    
    return $ytdlpArgs
}

function Update-Progress {
    param($Line, $Form, $ProgressBar, $LabelPercentage, $LabelSpeed, $LabelETA, $LabelStatusValue, $LabelCurrentFileValue)
    
    # Improved regex for better accuracy
    if ($Line -match '\[download\]\s+(\d+(?:\.\d+)?)%\s+of\s+~?\s*([\d\.]+\S*)\s+at\s+([\d\.]+\S*/s)\s+ETA\s+(\S+)') {
        $percent = [math]::Round([double]$matches[1], 1)
        $totalSize = $matches[2]
        $speed = $matches[3]
        $eta = $matches[4]
        
        $Form.Invoke({
            $ProgressBar.Value = [math]::Min([int]$percent, 100)
            $LabelPercentage.Text = "📈 Progress: $percent%"
            $LabelSpeed.Text = "⚡ Speed: $speed"
            $LabelETA.Text = "⏱️ ETA: $eta"
            $LabelStatusValue.Text = "Downloading... $percent% complete"
            $LabelStatusValue.ForeColor = [System.Drawing.Color]::DarkBlue
        })
    }
    elseif ($Line -match '\[download\]\s+(\d+(?:\.\d+)?)%') {
        $percent = [math]::Round([double]$matches[1], 1)
        $Form.Invoke({
            $ProgressBar.Value = [math]::Min([int]$percent, 100)
            $LabelPercentage.Text = "📈 Progress: $percent%"
        })
    }
    elseif ($Line -match '\[download\]\s+Destination:\s+(.+)') {
        $fileName = Split-Path $matches[1] -Leaf
        $Form.Invoke({
            $LabelCurrentFileValue.Text = $fileName
            $LabelStatusValue.Text = "Starting download..."
            $LabelStatusValue.ForeColor = [System.Drawing.Color]::Green
        })
    }
    elseif ($Line -match '\[download\]\s+(.+)\s+has already been downloaded') {
        $Form.Invoke({
            $LabelStatusValue.Text = "⚠️ File already exists, skipping..."
            $LabelStatusValue.ForeColor = [System.Drawing.Color]::Orange
        })
    }
    elseif ($Line -match '\[ExtractAudio\]') {
        $Form.Invoke({
            $LabelStatusValue.Text = "🎵 Extracting audio..."
            $LabelStatusValue.ForeColor = [System.Drawing.Color]::Purple
            $ProgressBar.Style = 'Marquee'
            $ProgressBar.MarqueeAnimationSpeed = 30
        })
    }
    elseif ($Line -match '\[ffmpeg\]') {
        $Form.Invoke({
            $LabelStatusValue.Text = "🎬 Processing with ffmpeg..."
            $LabelStatusValue.ForeColor = [System.Drawing.Color]::DarkMagenta
        })
    }
    elseif ($Line -match '\[Merger\]') {
        $Form.Invoke({
            $LabelStatusValue.Text = "🔗 Merging video and audio..."
            $LabelStatusValue.ForeColor = [System.Drawing.Color]::DarkCyan
        })
    }
    elseif ($Line -match '\[EmbedThumbnail\]') {
        $Form.Invoke({
            $LabelStatusValue.Text = "🖼️ Embedding thumbnail..."
            $LabelStatusValue.ForeColor = [System.Drawing.Color]::SaddleBrown
        })
    }
    elseif ($Line -match '\[EmbedSubtitle\]') {
        $Form.Invoke({
            $LabelStatusValue.Text = "📝 Embedding subtitles..."
            $LabelStatusValue.ForeColor = [System.Drawing.Color]::Navy
        })
    }
    elseif ($Line -match '\[Metadata\]') {
        $Form.Invoke({
            $LabelStatusValue.Text = "📊 Embedding metadata..."
            $LabelStatusValue.ForeColor = [System.Drawing.Color]::Teal
        })
    }
}

function Add-ToHistory {
    param($FileName, $Status, $OutputPath)
    
    $script:downloadHistory += [PSCustomObject]@{
        FileName = $FileName
        Status = $Status
        Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Path = $OutputPath
    }
}
#EndRegion

#Region UI Creation
function New-MainForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'YouTube Downloader Pro - Production Edition v4.0'
    $form.Size = New-Object System.Drawing.Size(1000, 850)
    $form.MinimumSize = New-Object System.Drawing.Size(950, 750)
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 250)
    $form.FormBorderStyle = 'Sizable'
    
    # Load saved configuration
    $config = Load-Configuration
    if ($config -and $config.OutputPath) {
        $defaultOutputPath = $config.OutputPath
    } else {
        $defaultOutputPath = [Environment]::GetFolderPath('MyVideos')
        if ([string]::IsNullOrEmpty($defaultOutputPath)) {
            $defaultOutputPath = [Environment]::GetFolderPath('MyDocuments') + '\Downloads'
        }
    }
    
    # Create main container
    $mainPanel = New-Object System.Windows.Forms.Panel
    $mainPanel.Dock = 'Fill'
    $mainPanel.AutoScroll = $true
    $mainPanel.Padding = New-Object System.Windows.Forms.Padding(15)
    $form.Controls.Add($mainPanel)
    
    $currentY = 0
    
    # Menu Strip
    $menuStrip = New-Object System.Windows.Forms.MenuStrip
    $menuStrip.BackColor = [System.Drawing.Color]::White
    
    $menuTools = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuTools.Text = '&Tools'
    
    $menuCheckDeps = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuCheckDeps.Text = 'Check Dependencies'
    
    $menuUpdateYtDlp = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuUpdateYtDlp.Text = 'Update yt-dlp'
    
    $menuShowFormats = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuShowFormats.Text = 'Show Available Formats'
    
    $menuViewHistory = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuViewHistory.Text = 'View Download History'
    
    $menuAbout = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuAbout.Text = '&Help'
    $menuAboutItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuAboutItem.Text = 'About'
    
    $menuTools.DropDownItems.Add($menuCheckDeps) | Out-Null
    $menuTools.DropDownItems.Add($menuUpdateYtDlp) | Out-Null
    $menuTools.DropDownItems.Add($menuShowFormats) | Out-Null
    $menuTools.DropDownItems.Add($menuViewHistory) | Out-Null
    $menuAbout.DropDownItems.Add($menuAboutItem) | Out-Null
    $menuStrip.Items.Add($menuTools) | Out-Null
    $menuStrip.Items.Add($menuAbout) | Out-Null
    $form.Controls.Add($menuStrip)
    
    #Region URL Section
    $urlPanel = New-Object System.Windows.Forms.GroupBox
    $urlPanel.Location = New-Object System.Drawing.Point(0, $currentY)
    $urlPanel.Size = New-Object System.Drawing.Size(940, 110)
    $urlPanel.Text = '📺 YouTube URL'
    $urlPanel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $urlPanel.Anchor = 'Top,Left,Right'
    
    $labelURL = New-Object System.Windows.Forms.Label
    $labelURL.Text = 'Enter YouTube video or playlist URL:'
    $labelURL.Location = New-Object System.Drawing.Point(15, 30)
    $labelURL.Size = New-Object System.Drawing.Size(300, 20)
    $labelURL.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $urlPanel.Controls.Add($labelURL)
    
    $textboxURL = New-Object System.Windows.Forms.TextBox
    $textboxURL.Location = New-Object System.Drawing.Point(15, 55)
    $textboxURL.Size = New-Object System.Drawing.Size(900, 25)
    $textboxURL.Font = New-Object System.Drawing.Font("Consolas", 10)
    $textboxURL.Anchor = 'Top,Left,Right'
    $urlPanel.Controls.Add($textboxURL)
    
    # Add drag-drop support for URLs
    $textboxURL.AllowDrop = $true
    $textboxURL.Add_DragEnter({
        if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::Text)) {
            $_.Effect = 'Copy'
        }
    })
    $textboxURL.Add_DragDrop({
        $textboxURL.Text = $_.Data.GetData([System.Windows.Forms.DataFormats]::Text)
    })
    
    $checkboxPlaylist = New-Object System.Windows.Forms.CheckBox
    $checkboxPlaylist.Location = New-Object System.Drawing.Point(15, 85)
    $checkboxPlaylist.Size = New-Object System.Drawing.Size(250, 20)
    $checkboxPlaylist.Text = '📋 Download entire playlist'
    $checkboxPlaylist.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $urlPanel.Controls.Add($checkboxPlaylist)
    
    $mainPanel.Controls.Add($urlPanel)
    $currentY += 120
    #EndRegion
    
    #Region Download Type Section
    $typePanel = New-Object System.Windows.Forms.GroupBox
    $typePanel.Location = New-Object System.Drawing.Point(0, $currentY)
    $typePanel.Size = New-Object System.Drawing.Size(940, 180)
    $typePanel.Text = '📥 Download Type'
    $typePanel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $typePanel.Anchor = 'Top,Left,Right'
    
    $radioVideo = New-Object System.Windows.Forms.RadioButton
    $radioVideo.Location = New-Object System.Drawing.Point(15, 30)
    $radioVideo.Size = New-Object System.Drawing.Size(400, 25)
    $radioVideo.Text = '🎬 Video (Best Quality - MP4)'
    $radioVideo.Checked = $true
    $radioVideo.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $typePanel.Controls.Add($radioVideo)
    
    $radioAudio = New-Object System.Windows.Forms.RadioButton
    $radioAudio.Location = New-Object System.Drawing.Point(15, 60)
    $radioAudio.Size = New-Object System.Drawing.Size(400, 25)
    $radioAudio.Text = '🎵 Audio Only (MP3 - Best Quality)'
    $radioAudio.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $typePanel.Controls.Add($radioAudio)
    
    $radioVideoMKV = New-Object System.Windows.Forms.RadioButton
    $radioVideoMKV.Location = New-Object System.Drawing.Point(15, 90)
    $radioVideoMKV.Size = New-Object System.Drawing.Size(400, 25)
    $radioVideoMKV.Text = '🎞️ Video + Audio (MKV - No Re-encode)'
    $radioVideoMKV.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $typePanel.Controls.Add($radioVideoMKV)
    
    $radioAudioOther = New-Object System.Windows.Forms.RadioButton
    $radioAudioOther.Location = New-Object System.Drawing.Point(15, 120)
    $radioAudioOther.Size = New-Object System.Drawing.Size(200, 25)
    $radioAudioOther.Text = '🎼 Audio (Other Format):'
    $radioAudioOther.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $typePanel.Controls.Add($radioAudioOther)
    
    $comboAudioFormat = New-Object System.Windows.Forms.ComboBox
    $comboAudioFormat.Location = New-Object System.Drawing.Point(220, 121)
    $comboAudioFormat.Size = New-Object System.Drawing.Size(150, 25)
    $comboAudioFormat.DropDownStyle = 'DropDownList'
    $comboAudioFormat.Items.AddRange(@('mp3', 'aac', 'flac', 'opus', 'wav', 'm4a', 'vorbis'))
    $comboAudioFormat.SelectedIndex = 0
    $comboAudioFormat.Enabled = $false
    $comboAudioFormat.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $typePanel.Controls.Add($comboAudioFormat)
    
    $radioCustom = New-Object System.Windows.Forms.RadioButton
    $radioCustom.Location = New-Object System.Drawing.Point(15, 150)
    $radioCustom.Size = New-Object System.Drawing.Size(200, 25)
    $radioCustom.Text = '⚙️ Custom Command'
    $radioCustom.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $typePanel.Controls.Add($radioCustom)
    
    $mainPanel.Controls.Add($typePanel)
    $currentY += 190
    #EndRegion
    
    #Region Quality & Options Section
    $qualityPanel = New-Object System.Windows.Forms.GroupBox
    $qualityPanel.Location = New-Object System.Drawing.Point(0, $currentY)
    $qualityPanel.Size = New-Object System.Drawing.Size(940, 180)
    $qualityPanel.Text = '🎨 Quality & Options'
    $qualityPanel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $qualityPanel.Anchor = 'Top,Left,Right'
    
    # First row - Quality settings
    $labelVideoQuality = New-Object System.Windows.Forms.Label
    $labelVideoQuality.Location = New-Object System.Drawing.Point(15, 35)
    $labelVideoQuality.Size = New-Object System.Drawing.Size(80, 20)
    $labelVideoQuality.Text = 'Resolution:'
    $labelVideoQuality.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $qualityPanel.Controls.Add($labelVideoQuality)
    
    $comboVideoQuality = New-Object System.Windows.Forms.ComboBox
    $comboVideoQuality.Location = New-Object System.Drawing.Point(100, 33)
    $comboVideoQuality.Size = New-Object System.Drawing.Size(120, 25)
    $comboVideoQuality.DropDownStyle = 'DropDownList'
    $comboVideoQuality.Items.AddRange(@('Best', '2160p (4K)', '1440p', '1080p', '720p', '480p', '360p'))
    $comboVideoQuality.SelectedIndex = 0
    $comboVideoQuality.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $qualityPanel.Controls.Add($comboVideoQuality)
    
    $labelAudioQuality = New-Object System.Windows.Forms.Label
    $labelAudioQuality.Location = New-Object System.Drawing.Point(240, 35)
    $labelAudioQuality.Size = New-Object System.Drawing.Size(90, 20)
    $labelAudioQuality.Text = 'Audio Quality:'
    $labelAudioQuality.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $qualityPanel.Controls.Add($labelAudioQuality)
    
    $comboAudioQuality = New-Object System.Windows.Forms.ComboBox
    $comboAudioQuality.Location = New-Object System.Drawing.Point(335, 33)
    $comboAudioQuality.Size = New-Object System.Drawing.Size(120, 25)
    $comboAudioQuality.DropDownStyle = 'DropDownList'
    $comboAudioQuality.Items.AddRange(@('Best (0)', 'High (2)', 'Medium (5)', 'Low (9)'))
    $comboAudioQuality.SelectedIndex = 0
    $comboAudioQuality.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $qualityPanel.Controls.Add($comboAudioQuality)
    
    # Second row - Additional options
    $checkboxSubtitles = New-Object System.Windows.Forms.CheckBox
    $checkboxSubtitles.Location = New-Object System.Drawing.Point(15, 70)
    $checkboxSubtitles.Size = New-Object System.Drawing.Size(100, 20)
    $checkboxSubtitles.Text = '📝 Subtitles'
    $checkboxSubtitles.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $qualityPanel.Controls.Add($checkboxSubtitles)
    
    $checkboxThumbnail = New-Object System.Windows.Forms.CheckBox
    $checkboxThumbnail.Location = New-Object System.Drawing.Point(130, 70)
    $checkboxThumbnail.Size = New-Object System.Drawing.Size(110, 20)
    $checkboxThumbnail.Text = '🖼️ Thumbnail'
    $checkboxThumbnail.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $qualityPanel.Controls.Add($checkboxThumbnail)
    
    $checkboxMetadata = New-Object System.Windows.Forms.CheckBox
    $checkboxMetadata.Location = New-Object System.Drawing.Point(255, 70)
    $checkboxMetadata.Size = New-Object System.Drawing.Size(110, 20)
    $checkboxMetadata.Text = '📊 Metadata'
    $checkboxMetadata.Checked = $true
    $checkboxMetadata.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $qualityPanel.Controls.Add($checkboxMetadata)
    
    # Third row - NEW: Retry and Rate Limit options
    $checkboxRetry = New-Object System.Windows.Forms.CheckBox
    $checkboxRetry.Location = New-Object System.Drawing.Point(15, 100)
    $checkboxRetry.Size = New-Object System.Drawing.Size(220, 20)
    $checkboxRetry.Text = '🔄 Enable Retry (10x, unstable nets)'
    $checkboxRetry.Checked = $true
    $checkboxRetry.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $qualityPanel.Controls.Add($checkboxRetry)
    
    $checkboxRateLimit = New-Object System.Windows.Forms.CheckBox
    $checkboxRateLimit.Location = New-Object System.Drawing.Point(255, 100)
    $checkboxRateLimit.Size = New-Object System.Drawing.Size(100, 20)
    $checkboxRateLimit.Text = '🚦 Rate Limit:'
    $checkboxRateLimit.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $qualityPanel.Controls.Add($checkboxRateLimit)
    
    $textboxRateLimit = New-Object System.Windows.Forms.TextBox
    $textboxRateLimit.Location = New-Object System.Drawing.Point(360, 98)
    $textboxRateLimit.Size = New-Object System.Drawing.Size(95, 25)
    $textboxRateLimit.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $textboxRateLimit.Text = '2M'
    $textboxRateLimit.Enabled = $false
    $qualityPanel.Controls.Add($textboxRateLimit)
    
    # Custom command section
    $labelCustom = New-Object System.Windows.Forms.Label
    $labelCustom.Location = New-Object System.Drawing.Point(15, 135)
    $labelCustom.Size = New-Object System.Drawing.Size(150, 20)
    $labelCustom.Text = 'Custom yt-dlp options:'
    $labelCustom.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $labelCustom.Enabled = $false
    $qualityPanel.Controls.Add($labelCustom)
    
    $textboxCustom = New-Object System.Windows.Forms.TextBox
    $textboxCustom.Location = New-Object System.Drawing.Point(15, 155)
    $textboxCustom.Size = New-Object System.Drawing.Size(905, 25)
    $textboxCustom.Font = New-Object System.Drawing.Font("Consolas", 9)
    $textboxCustom.Text = '-f bestaudio --extract-audio --audio-format mp3 --audio-quality 0'
    $textboxCustom.Enabled = $false
    $textboxCustom.Anchor = 'Top,Left,Right'
    $qualityPanel.Controls.Add($textboxCustom)
    
    $mainPanel.Controls.Add($qualityPanel)
    $currentY += 190
    #EndRegion
    
    #Region Output Folder Section
    $outputPanel = New-Object System.Windows.Forms.GroupBox
    $outputPanel.Location = New-Object System.Drawing.Point(0, $currentY)
    $outputPanel.Size = New-Object System.Drawing.Size(940, 85)
    $outputPanel.Text = '📁 Output Location'
    $outputPanel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $outputPanel.Anchor = 'Top,Left,Right'
    
    $labelOutput = New-Object System.Windows.Forms.Label
    $labelOutput.Location = New-Object System.Drawing.Point(15, 30)
    $labelOutput.Size = New-Object System.Drawing.Size(100, 20)
    $labelOutput.Text = 'Save files to:'
    $labelOutput.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $outputPanel.Controls.Add($labelOutput)
    
    $textboxOutput = New-Object System.Windows.Forms.TextBox
    $textboxOutput.Location = New-Object System.Drawing.Point(15, 55)
    $textboxOutput.Size = New-Object System.Drawing.Size(795, 25)
    $textboxOutput.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $textboxOutput.Anchor = 'Top,Left,Right'
    $textboxOutput.Text = $defaultOutputPath
    $outputPanel.Controls.Add($textboxOutput)
    
    $buttonBrowse = New-Object System.Windows.Forms.Button
    $buttonBrowse.Location = New-Object System.Drawing.Point(820, 53)
    $buttonBrowse.Size = New-Object System.Drawing.Size(100, 28)
    $buttonBrowse.Text = '📂 Browse'
    $buttonBrowse.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $buttonBrowse.BackColor = [System.Drawing.Color]::White
    $buttonBrowse.FlatStyle = 'Flat'
    $buttonBrowse.Cursor = 'Hand'
    $buttonBrowse.Anchor = 'Top,Right'
    $outputPanel.Controls.Add($buttonBrowse)
    
    $mainPanel.Controls.Add($outputPanel)
    $currentY += 95
    #EndRegion
    
    #Region Action Buttons
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Location = New-Object System.Drawing.Point(0, $currentY)
    $buttonPanel.Size = New-Object System.Drawing.Size(940, 50)
    $buttonPanel.Anchor = 'Top,Left,Right'
    
    $buttonDownload = New-Object System.Windows.Forms.Button
    $buttonDownload.Location = New-Object System.Drawing.Point(520, 10)
    $buttonDownload.Size = New-Object System.Drawing.Size(150, 35)
    $buttonDownload.Text = '⬇️ Download'
    $buttonDownload.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $buttonDownload.BackColor = [System.Drawing.Color]::FromArgb(76, 175, 80)
    $buttonDownload.ForeColor = [System.Drawing.Color]::White
    $buttonDownload.FlatStyle = 'Flat'
    $buttonDownload.FlatAppearance.BorderSize = 0
    $buttonDownload.Cursor = 'Hand'
    $buttonDownload.Anchor = 'Top,Right'
    $buttonPanel.Controls.Add($buttonDownload)
    
    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Location = New-Object System.Drawing.Point(680, 10)
    $buttonCancel.Size = New-Object System.Drawing.Size(80, 35)
    $buttonCancel.Text = '⏹️ Cancel'
    $buttonCancel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $buttonCancel.BackColor = [System.Drawing.Color]::FromArgb(244, 67, 54)
    $buttonCancel.ForeColor = [System.Drawing.Color]::White
    $buttonCancel.FlatStyle = 'Flat'
    $buttonCancel.FlatAppearance.BorderSize = 0
    $buttonCancel.Cursor = 'Hand'
    $buttonCancel.Enabled = $false
    $buttonCancel.Anchor = 'Top,Right'
    $buttonPanel.Controls.Add($buttonCancel)
    
    $buttonOpenFolder = New-Object System.Windows.Forms.Button
    $buttonOpenFolder.Location = New-Object System.Drawing.Point(770, 10)
    $buttonOpenFolder.Size = New-Object System.Drawing.Size(75, 35)
    $buttonOpenFolder.Text = '📂 Open'
    $buttonOpenFolder.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $buttonOpenFolder.BackColor = [System.Drawing.Color]::FromArgb(33, 150, 243)
    $buttonOpenFolder.ForeColor = [System.Drawing.Color]::White
    $buttonOpenFolder.FlatStyle = 'Flat'
    $buttonOpenFolder.FlatAppearance.BorderSize = 0
    $buttonOpenFolder.Cursor = 'Hand'
    $buttonOpenFolder.Anchor = 'Top,Right'
    $buttonPanel.Controls.Add($buttonOpenFolder)
    
    $buttonClear = New-Object System.Windows.Forms.Button
    $buttonClear.Location = New-Object System.Drawing.Point(855, 10)
    $buttonClear.Size = New-Object System.Drawing.Size(65, 35)
    $buttonClear.Text = '🗑️ Clear'
    $buttonClear.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $buttonClear.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $buttonClear.FlatStyle = 'Flat'
    $buttonClear.Cursor = 'Hand'
    $buttonClear.Anchor = 'Top,Right'
    $buttonPanel.Controls.Add($buttonClear)
    
    $mainPanel.Controls.Add($buttonPanel)
    $currentY += 60
    #EndRegion
    
    #Region Progress Section
    $progressPanel = New-Object System.Windows.Forms.GroupBox
    $progressPanel.Location = New-Object System.Drawing.Point(0, $currentY)
    $progressPanel.Size = New-Object System.Drawing.Size(940, 170)
    $progressPanel.Text = '📊 Download Progress'
    $progressPanel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $progressPanel.Anchor = 'Top,Left,Right'
    $progressPanel.BackColor = [System.Drawing.Color]::White
    
    $labelCurrentFile = New-Object System.Windows.Forms.Label
    $labelCurrentFile.Location = New-Object System.Drawing.Point(15, 30)
    $labelCurrentFile.Size = New-Object System.Drawing.Size(100, 20)
    $labelCurrentFile.Text = 'Current File:'
    $labelCurrentFile.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $progressPanel.Controls.Add($labelCurrentFile)
    
    $labelCurrentFileValue = New-Object System.Windows.Forms.Label
    $labelCurrentFileValue.Location = New-Object System.Drawing.Point(120, 30)
    $labelCurrentFileValue.Size = New-Object System.Drawing.Size(800, 20)
    $labelCurrentFileValue.Text = 'Waiting for download...'
    $labelCurrentFileValue.Font = New-Object System.Drawing.Font("Consolas", 9)
    $labelCurrentFileValue.ForeColor = [System.Drawing.Color]::DarkBlue
    $labelCurrentFileValue.Anchor = 'Top,Left,Right'
    $progressPanel.Controls.Add($labelCurrentFileValue)
    
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(15, 60)
    $progressBar.Size = New-Object System.Drawing.Size(905, 30)
    $progressBar.Style = 'Continuous'
    $progressBar.Anchor = 'Top,Left,Right'
    $progressPanel.Controls.Add($progressBar)
    
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Location = New-Object System.Drawing.Point(15, 100)
    $statsPanel.Size = New-Object System.Drawing.Size(905, 60)
    $statsPanel.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 255)
    $statsPanel.BorderStyle = 'FixedSingle'
    $statsPanel.Anchor = 'Top,Left,Right'
    
    $labelPercentage = New-Object System.Windows.Forms.Label
    $labelPercentage.Location = New-Object System.Drawing.Point(10, 10)
    $labelPercentage.Size = New-Object System.Drawing.Size(200, 25)
    $labelPercentage.Text = '📈 Progress: 0%'
    $labelPercentage.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $labelPercentage.ForeColor = [System.Drawing.Color]::DarkGreen
    $statsPanel.Controls.Add($labelPercentage)
    
    $labelSpeed = New-Object System.Windows.Forms.Label
    $labelSpeed.Location = New-Object System.Drawing.Point(230, 10)
    $labelSpeed.Size = New-Object System.Drawing.Size(200, 20)
    $labelSpeed.Text = '⚡ Speed: 0 B/s'
    $labelSpeed.Font = New-Object System.Drawing.Font("Consolas", 9)
    $statsPanel.Controls.Add($labelSpeed)
    
    $labelETA = New-Object System.Windows.Forms.Label
    $labelETA.Location = New-Object System.Drawing.Point(450, 10)
    $labelETA.Size = New-Object System.Drawing.Size(150, 20)
    $labelETA.Text = '⏱️ ETA: --:--'
    $labelETA.Font = New-Object System.Drawing.Font("Consolas", 9)
    $statsPanel.Controls.Add($labelETA)
    
    $labelStatusInfo = New-Object System.Windows.Forms.Label
    $labelStatusInfo.Location = New-Object System.Drawing.Point(10, 35)
    $labelStatusInfo.Size = New-Object System.Drawing.Size(60, 20)
    $labelStatusInfo.Text = 'Status:'
    $labelStatusInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $statsPanel.Controls.Add($labelStatusInfo)
    
    $labelStatusValue = New-Object System.Windows.Forms.Label
    $labelStatusValue.Location = New-Object System.Drawing.Point(75, 35)
    $labelStatusValue.Size = New-Object System.Drawing.Size(815, 20)
    $labelStatusValue.Text = 'Idle - Ready to download'
    $labelStatusValue.Font = New-Object System.Drawing.Font("Consolas", 9)
    $labelStatusValue.ForeColor = [System.Drawing.Color]::DarkSlateGray
    $labelStatusValue.Anchor = 'Top,Left,Right'
    $statsPanel.Controls.Add($labelStatusValue)
    
    $progressPanel.Controls.Add($statsPanel)
    $mainPanel.Controls.Add($progressPanel)
    $currentY += 180
    #EndRegion
    
    #Region Log Section
    $logPanel = New-Object System.Windows.Forms.GroupBox
    $logPanel.Location = New-Object System.Drawing.Point(0, $currentY)
    $logPanel.Size = New-Object System.Drawing.Size(940, 200)
    $logPanel.Text = '📝 Detailed Activity Log'
    $logPanel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $logPanel.Anchor = 'Top,Left,Right,Bottom'
    
    $textboxStatus = New-Object System.Windows.Forms.TextBox
    $textboxStatus.Location = New-Object System.Drawing.Point(10, 25)
    $textboxStatus.Size = New-Object System.Drawing.Size(920, 165)
    $textboxStatus.Multiline = $true
    $textboxStatus.ScrollBars = 'Vertical'
    $textboxStatus.ReadOnly = $true
    $textboxStatus.Font = New-Object System.Drawing.Font("Consolas", 8)
    $textboxStatus.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $textboxStatus.ForeColor = [System.Drawing.Color]::Lime
    $textboxStatus.Anchor = 'Top,Left,Right,Bottom'
    $logPanel.Controls.Add($textboxStatus)
    
    $mainPanel.Controls.Add($logPanel)
    #EndRegion
    
    # Return form and all controls as hashtable for easy access
    return @{
        Form = $form
        TextboxURL = $textboxURL
        CheckboxPlaylist = $checkboxPlaylist
        RadioVideo = $radioVideo
        RadioAudio = $radioAudio
        RadioVideoMKV = $radioVideoMKV
        RadioAudioOther = $radioAudioOther
        RadioCustom = $radioCustom
        ComboVideoQuality = $comboVideoQuality
        ComboAudioQuality = $comboAudioQuality
        ComboAudioFormat = $comboAudioFormat
        CheckboxSubtitles = $checkboxSubtitles
        CheckboxThumbnail = $checkboxThumbnail
        CheckboxMetadata = $checkboxMetadata
        CheckboxRetry = $checkboxRetry
        CheckboxRateLimit = $checkboxRateLimit
        TextboxRateLimit = $textboxRateLimit
        TextboxCustom = $textboxCustom
        TextboxOutput = $textboxOutput
        ButtonBrowse = $buttonBrowse
        ButtonDownload = $buttonDownload
        ButtonCancel = $buttonCancel
        ButtonOpenFolder = $buttonOpenFolder
        ButtonClear = $buttonClear
        ProgressBar = $progressBar
        LabelPercentage = $labelPercentage
        LabelSpeed = $labelSpeed
        LabelETA = $labelETA
        LabelStatusValue = $labelStatusValue
        LabelCurrentFileValue = $labelCurrentFileValue
        TextboxStatus = $textboxStatus
        MenuCheckDeps = $menuCheckDeps
        MenuUpdateYtDlp = $menuUpdateYtDlp
        MenuShowFormats = $menuShowFormats
        MenuViewHistory = $menuViewHistory
        MenuAboutItem = $menuAboutItem
        LabelCustom = $labelCustom
    }
}
#EndRegion

#Region Event Handlers
function Register-EventHandlers {
    param($UI)
    
    # Radio button changes - auto-disable incompatible options
    $UI.RadioVideo.Add_CheckedChanged({
        $UI.ComboVideoQuality.Enabled = $UI.RadioVideo.Checked
        $UI.ComboAudioQuality.Enabled = -not $UI.RadioVideo.Checked
    })
    
    $UI.RadioAudio.Add_CheckedChanged({
        $UI.ComboVideoQuality.Enabled = -not $UI.RadioAudio.Checked
        $UI.ComboAudioQuality.Enabled = $UI.RadioAudio.Checked
    })
    
    $UI.RadioAudioOther.Add_CheckedChanged({
        $UI.ComboAudioFormat.Enabled = $UI.RadioAudioOther.Checked
        $UI.ComboVideoQuality.Enabled = -not $UI.RadioAudioOther.Checked
        $UI.ComboAudioQuality.Enabled = $UI.RadioAudioOther.Checked
    })
    
    $UI.RadioCustom.Add_CheckedChanged({
        $UI.TextboxCustom.Enabled = $UI.RadioCustom.Checked
        $UI.LabelCustom.Enabled = $UI.RadioCustom.Checked
    })
    
    $UI.CheckboxRateLimit.Add_CheckedChanged({
        $UI.TextboxRateLimit.Enabled = $UI.CheckboxRateLimit.Checked
    })
    
    # Browse button
    $UI.ButtonBrowse.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.SelectedPath = $UI.TextboxOutput.Text
        $folderBrowser.Description = 'Select output folder for downloads'
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $UI.TextboxOutput.Text = $folderBrowser.SelectedPath
            # Save to config
            Save-Configuration -Config @{ OutputPath = $folderBrowser.SelectedPath }
        }
    })
    
    # Open Folder button
    $UI.ButtonOpenFolder.Add_Click({
        if (Test-Path $UI.TextboxOutput.Text) {
            Start-Process explorer.exe -ArgumentList $UI.TextboxOutput.Text
        } else {
            [System.Windows.Forms.MessageBox]::Show("Output folder does not exist.", 'Error', 'OK', 'Error')
        }
    })
    
    # Clear button
    $UI.ButtonClear.Add_Click({
        $UI.TextboxStatus.Clear()
        $UI.ProgressBar.Value = 0
        $UI.ProgressBar.Style = 'Continuous'
        $UI.LabelPercentage.Text = '📈 Progress: 0%'
        $UI.LabelSpeed.Text = '⚡ Speed: 0 B/s'
        $UI.LabelETA.Text = '⏱️ ETA: --:--'
        $UI.LabelStatusValue.Text = 'Idle - Ready to download'
        $UI.LabelStatusValue.ForeColor = [System.Drawing.Color]::DarkSlateGray
        $UI.LabelCurrentFileValue.Text = 'Waiting for download...'
        
        $deps = Test-Dependencies
        $UI.TextboxStatus.Text = "🔍 Dependency Check:`r`n" + ("=" * 80) + "`r`n"
        $UI.TextboxStatus.AppendText(($deps.Issues -join "`r`n") + "`r`n`r`n")
        if (-not $deps.HasYtDlp -or -not $deps.HasFfmpeg) {
            $UI.TextboxStatus.AppendText("⚠️ WARNING: Missing dependencies detected!`r`n")
            $UI.TextboxStatus.AppendText("Go to Tools > Check Dependencies to install.`r`n")
        } else {
            $UI.TextboxStatus.AppendText("✅ All systems ready! You can start downloading.`r`n")
        }
    })
    
    # Menu - Check Dependencies
    $UI.MenuCheckDeps.Add_Click({
        $deps = Test-Dependencies
        $message = ($deps.Issues -join "`n") + "`n`n"
        
        if (-not $deps.HasYtDlp -or -not $deps.HasFfmpeg) {
            if ($deps.HasWinget) {
                $message += "Would you like to install missing packages automatically?"
                $result = [System.Windows.Forms.MessageBox]::Show($message, 'Dependency Check', 'YesNo', 'Question')
                if ($result -eq 'Yes') {
                    Install-Dependencies -StatusTextBox $UI.TextboxStatus -Form $UI.Form
                }
            } else {
                $message += "Please install missing packages manually."
                [System.Windows.Forms.MessageBox]::Show($message, 'Dependency Check', 'OK', 'Warning')
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show($message + "All dependencies are installed!", 'Dependency Check', 'OK', 'Information')
        }
    })
    
    # Menu - Update yt-dlp
    $UI.MenuUpdateYtDlp.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show("Update yt-dlp to the latest version?", 'Update', 'YesNo', 'Question')
        if ($result -eq 'Yes') {
            $UI.TextboxStatus.Text = "Updating yt-dlp...`r`n"
            try {
                $tempOut = Join-Path $env:TEMP 'ytdlp_update.txt'
                $tempErr = Join-Path $env:TEMP 'ytdlp_update_err.txt'
                $process = Start-Process -FilePath 'yt-dlp' -ArgumentList '-U' -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tempOut -RedirectStandardError $tempErr
                
                if (Test-Path $tempOut) {
                    $output = Get-Content $tempOut -Raw
                    $UI.TextboxStatus.AppendText($output)
                }
                if (Test-Path $tempErr) {
                    $errors = Get-Content $tempErr -Raw
                    if ($errors) { $UI.TextboxStatus.AppendText($errors) }
                }
                
                [System.Windows.Forms.MessageBox]::Show("yt-dlp update completed!", 'Success', 'OK', 'Information')
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Error updating yt-dlp: $($_.Exception.Message)", 'Error', 'OK', 'Error')
            }
        }
    })
    
    # Menu - Show Available Formats
    $UI.MenuShowFormats.Add_Click({
        if ([string]::IsNullOrWhiteSpace($UI.TextboxURL.Text)) {
            [System.Windows.Forms.MessageBox]::Show('Please enter a YouTube URL first.', 'Error', 'OK', 'Error')
            return
        }
        
        $formatForm = New-Object System.Windows.Forms.Form
        $formatForm.Text = 'Available Formats'
        $formatForm.Size = New-Object System.Drawing.Size(900, 600)
        $formatForm.StartPosition = 'CenterParent'
        
        $formatTextBox = New-Object System.Windows.Forms.TextBox
        $formatTextBox.Multiline = $true
        $formatTextBox.ScrollBars = 'Vertical'
        $formatTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
        $formatTextBox.Dock = 'Fill'
        $formatTextBox.Text = "Fetching formats...`r`n`r`nPlease wait..."
        $formatForm.Controls.Add($formatTextBox)
        
        $formatForm.Show()
        $formatForm.Refresh()
        
        try {
            $tempOut = Join-Path $env:TEMP 'ytdlp_formats.txt'
            $process = Start-Process -FilePath 'yt-dlp' -ArgumentList '-F', $UI.TextboxURL.Text -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tempOut -RedirectStandardError $tempOut
            
            if (Test-Path $tempOut) {
                $output = Get-Content $tempOut -Raw
                $formatTextBox.Text = $output
            }
        } catch {
            $formatTextBox.Text = "Error: $($_.Exception.Message)"
        }
    })
    
    # Menu - View Download History
    $UI.MenuViewHistory.Add_Click({
        $historyForm = New-Object System.Windows.Forms.Form
        $historyForm.Text = 'Download History'
        $historyForm.Size = New-Object System.Drawing.Size(900, 500)
        $historyForm.StartPosition = 'CenterParent'
        
        $listView = New-Object System.Windows.Forms.ListView
        $listView.Dock = 'Fill'
        $listView.View = 'Details'
        $listView.FullRowSelect = $true
        $listView.GridLines = $true
        $listView.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        
        $listView.Columns.Add('File Name', 400) | Out-Null
        $listView.Columns.Add('Status', 100) | Out-Null
        $listView.Columns.Add('Date/Time', 200) | Out-Null
        $listView.Columns.Add('Path', 200) | Out-Null
        
        foreach ($item in $script:downloadHistory) {
            $lvItem = New-Object System.Windows.Forms.ListViewItem($item.FileName)
            $lvItem.SubItems.Add($item.Status) | Out-Null
            $lvItem.SubItems.Add($item.Date) | Out-Null
            $lvItem.SubItems.Add($item.Path) | Out-Null
            $listView.Items.Add($lvItem) | Out-Null
        }
        
        $historyForm.Controls.Add($listView)
        $historyForm.ShowDialog()
    })
    
    # Menu - About
    $UI.MenuAboutItem.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("YouTube Downloader Pro`nVersion 4.0 - Production Edition`n`nPowered by yt-dlp and ffmpeg`n`nFeatures:`n• Async event-driven processing`n• Thread-safe UI updates`n• Download history tracking`n• Retry & rate limiting`n• Format listing support`n• Drag & drop URLs`n• Configuration persistence`n• Professional architecture", 'About', 'OK', 'Information')
    })
    
    # Cancel button
    $UI.ButtonCancel.Add_Click({
        if ($script:isDownloading) {
            $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to cancel the current download?", 'Cancel Download', 'YesNo', 'Question')
            if ($result -eq 'Yes') {
                if (Stop-Download -StatusTextBox $UI.TextboxStatus -Form $UI.Form) {
                    $UI.Form.Invoke({
                        $UI.LabelStatusValue.Text = "❌ Download cancelled by user"
                        $UI.LabelStatusValue.ForeColor = [System.Drawing.Color]::Red
                        $UI.TextboxStatus.AppendText("`r`n❌ Download cancelled by user`r`n")
                        $UI.ButtonDownload.Enabled = $true
                        $UI.ButtonCancel.Enabled = $false
                        $UI.ProgressBar.Style = 'Continuous'
                    })
                    
                    # Clean up event handlers
                    if ($script:outputEvent) {
                        Unregister-Event -SourceIdentifier $script:outputEvent.Name -ErrorAction SilentlyContinue
                        $script:outputEvent = $null
                    }
                    if ($script:errorEvent) {
                        Unregister-Event -SourceIdentifier $script:errorEvent.Name -ErrorAction SilentlyContinue
                        $script:errorEvent = $null
                    }
                    if ($script:exitEvent) {
                        Unregister-Event -SourceIdentifier $script:exitEvent.Name -ErrorAction SilentlyContinue
                        $script:exitEvent = $null
                    }
                }
            }
        }
    })
    
    # Download button - ASYNC VERSION with proper thread safety
    $UI.ButtonDownload.Add_Click({
        # Validation
        if ([string]::IsNullOrWhiteSpace($UI.TextboxURL.Text)) {
            [System.Windows.Forms.MessageBox]::Show('Please enter a YouTube URL.', 'Error', 'OK', 'Error')
            return
        }

        if (-not (Test-Path $UI.TextboxOutput.Text)) {
            $result = [System.Windows.Forms.MessageBox]::Show("Output folder does not exist. Create it?", 'Create Folder', 'YesNo', 'Question')
            if ($result -eq 'Yes') {
                try {
                    New-Item -ItemType Directory -Path $UI.TextboxOutput.Text -Force | Out-Null
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to create directory: $($_.Exception.Message)", 'Error', 'OK', 'Error')
                    return
                }
            } else {
                return
            }
        }

        # Check dependencies
        $deps = Test-Dependencies
        if (-not $deps.HasYtDlp) {
            $result = [System.Windows.Forms.MessageBox]::Show("yt-dlp is not installed. Would you like to install it now?", 'Missing Dependency', 'YesNo', 'Warning')
            if ($result -eq 'Yes') {
                Install-Dependencies -StatusTextBox $UI.TextboxStatus -Form $UI.Form
                return
            } else {
                return
            }
        }

        if (-not $deps.HasFfmpeg) {
            $result = [System.Windows.Forms.MessageBox]::Show("ffmpeg is not installed. This is required for video/audio processing. Would you like to install it now?", 'Missing Dependency', 'YesNo', 'Warning')
            if ($result -eq 'Yes') {
                Install-Dependencies -StatusTextBox $UI.TextboxStatus -Form $UI.Form
                return
            }
        }

        # Reset UI
        $script:isDownloading = $true
        $UI.ButtonDownload.Enabled = $false
        $UI.ButtonCancel.Enabled = $true
        $UI.ProgressBar.Value = 0
        $UI.ProgressBar.Style = 'Continuous'
        $UI.LabelPercentage.Text = '📈 Progress: 0%'
        $UI.LabelSpeed.Text = '⚡ Speed: 0 B/s'
        $UI.LabelETA.Text = '⏱️ ETA: --:--'
        $UI.LabelStatusValue.Text = 'Preparing download...'
        $UI.LabelStatusValue.ForeColor = [System.Drawing.Color]::DarkOrange
        $UI.LabelCurrentFileValue.Text = 'Initializing...'

        # Build command
        try {
            $ytdlpArgs = Build-YtDlpArguments -RadioVideo $UI.RadioVideo -RadioAudio $UI.RadioAudio `
                -RadioVideoMKV $UI.RadioVideoMKV -RadioAudioOther $UI.RadioAudioOther -RadioCustom $UI.RadioCustom `
                -ComboVideoQuality $UI.ComboVideoQuality -ComboAudioQuality $UI.ComboAudioQuality `
                -ComboAudioFormat $UI.ComboAudioFormat -CheckboxPlaylist $UI.CheckboxPlaylist `
                -CheckboxSubtitles $UI.CheckboxSubtitles -CheckboxThumbnail $UI.CheckboxThumbnail `
                -CheckboxMetadata $UI.CheckboxMetadata -CheckboxRetry $UI.CheckboxRetry `
                -CheckboxRateLimit $UI.CheckboxRateLimit -TextboxRateLimit $UI.TextboxRateLimit `
                -TextboxCustom $UI.TextboxCustom -TextboxOutput $UI.TextboxOutput -URL $UI.TextboxURL.Text
        } catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Error', 'OK', 'Error')
            $UI.ButtonDownload.Enabled = $true
            $UI.ButtonCancel.Enabled = $false
            $script:isDownloading = $false
            return
        }

        # Initialize log file
        $logFile = Join-Path $UI.TextboxOutput.Text "download_log.txt"
        
        $UI.TextboxStatus.Text = "🚀 Starting download...`r`n"
        $UI.TextboxStatus.AppendText("📋 Command: yt-dlp $($ytdlpArgs -join ' ')`r`n")
        $UI.TextboxStatus.AppendText("📄 Log file: $logFile`r`n")
        $UI.TextboxStatus.AppendText(("=" * 80) + "`r`n`r`n")
        $UI.Form.Refresh()

        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'yt-dlp'
            $psi.Arguments = $ytdlpArgs -join ' '
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $script:downloadProcess = New-Object System.Diagnostics.Process
            $script:downloadProcess.StartInfo = $psi
            $script:downloadProcess.EnableRaisingEvents = $true
            
            # CRITICAL: Thread-safe output handler
            $outputHandler = {
                if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
                    $line = $EventArgs.Data
                    
                    # Update progress (thread-safe)
                    Update-Progress -Line $line -Form $UI.Form -ProgressBar $UI.ProgressBar `
                        -LabelPercentage $UI.LabelPercentage -LabelSpeed $UI.LabelSpeed `
                        -LabelETA $UI.LabelETA -LabelStatusValue $UI.LabelStatusValue `
                        -LabelCurrentFileValue $UI.LabelCurrentFileValue
                    
                    # Add to log (thread-safe)
                    $timestamp = Get-Date -Format "HH:mm:ss"
                    $logEntry = "[$timestamp] $line"
                    
                    $UI.Form.Invoke({
                        $UI.TextboxStatus.AppendText("$logEntry`r`n")
                        $UI.TextboxStatus.SelectionStart = $UI.TextboxStatus.TextLength
                        $UI.TextboxStatus.ScrollToCaret()
                    })
                    
                    # Write to log file
                    try {
                        Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
                    } catch {
                        # Silent fail - logging is not critical
                    }
                }
            }
            
            # CRITICAL: Async exit handler - NO BLOCKING
            $exitHandler = {
                $exitCode = $Event.SourceEventArgs.ExitCode
                
                $UI.Form.Invoke({
                    if ($exitCode -eq 0) {
                        $UI.ProgressBar.Value = 100
                        $UI.ProgressBar.Style = 'Continuous'
                        $UI.LabelPercentage.Text = "📈 Progress: 100%"
                        $UI.LabelStatusValue.Text = "✅ Download completed successfully!"
                        $UI.LabelStatusValue.ForeColor = [System.Drawing.Color]::DarkGreen
                        $UI.TextboxStatus.AppendText("`r`n" + ("=" * 80) + "`r`n")
                        $UI.TextboxStatus.AppendText("✅ SUCCESS! Download completed successfully.`r`n")
                        
                        # Add to history
                        Add-ToHistory -FileName $UI.LabelCurrentFileValue.Text -Status "Success" -OutputPath $UI.TextboxOutput.Text
                        
                        [System.Windows.Forms.MessageBox]::Show("Download completed successfully!`n`nSaved to: $($UI.TextboxOutput.Text)", 'Success', 'OK', 'Information')
                    }
                    else {
                        $UI.ProgressBar.Style = 'Continuous'
                        $UI.LabelStatusValue.Text = "❌ Download failed!"
                        $UI.LabelStatusValue.ForeColor = [System.Drawing.Color]::Red
                        $UI.TextboxStatus.AppendText("`r`n" + ("=" * 80) + "`r`n")
                        $UI.TextboxStatus.AppendText("❌ ERROR! Download failed with exit code: $exitCode`r`n")
                        
                        # Add to history
                        Add-ToHistory -FileName $UI.LabelCurrentFileValue.Text -Status "Failed" -OutputPath $UI.TextboxOutput.Text
                        
                        [System.Windows.Forms.MessageBox]::Show("Download failed. Check the detailed log for more information.", 'Error', 'OK', 'Error')
                    }
                    
                    $script:isDownloading = $false
                    $UI.ButtonDownload.Enabled = $true
                    $UI.ButtonCancel.Enabled = $false
                })
                
                # Clean up event handlers
                if ($script:outputEvent) {
                    Unregister-Event -SourceIdentifier $script:outputEvent.Name -ErrorAction SilentlyContinue
                }
                if ($script:errorEvent) {
                    Unregister-Event -SourceIdentifier $script:errorEvent.Name -ErrorAction SilentlyContinue
                }
                if ($script:exitEvent) {
                    Unregister-Event -SourceIdentifier $script:exitEvent.Name -ErrorAction SilentlyContinue
                }
            }
            
            # Register event handlers with proper identifiers
            $script:outputEvent = Register-ObjectEvent -InputObject $script:downloadProcess -EventName OutputDataReceived -Action $outputHandler
            $script:errorEvent = Register-ObjectEvent -InputObject $script:downloadProcess -EventName ErrorDataReceived -Action $outputHandler
            $script:exitEvent = Register-ObjectEvent -InputObject $script:downloadProcess -EventName Exited -Action $exitHandler
            
            # Start process
            $script:downloadProcess.Start() | Out-Null
            $script:downloadProcess.BeginOutputReadLine()
            $script:downloadProcess.BeginErrorReadLine()
            
            # NO BLOCKING LOOP - Process returns immediately!
            
        }
        catch {
            $UI.LabelStatusValue.Text = "❌ Error occurred!"
            $UI.LabelStatusValue.ForeColor = [System.Drawing.Color]::Red
            $UI.TextboxStatus.AppendText("`r`n❌ EXCEPTION: $($_.Exception.Message)`r`n")
            [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", 'Error', 'OK', 'Error')
            
            $script:isDownloading = $false
            $UI.ButtonDownload.Enabled = $true
            $UI.ButtonCancel.Enabled = $false
        }
    })
}
#EndRegion

#Region Main Execution
# Create UI
$UI = New-MainForm

# Register all event handlers
Register-EventHandlers -UI $UI

# Initial dependency check
$deps = Test-Dependencies
$UI.TextboxStatus.Text = "🔍 YouTube Downloader Pro - Production Edition v4.0`r`n" + ("=" * 80) + "`r`n`r`n"
$UI.TextboxStatus.AppendText("Startup Diagnostics:`r`n" + ("-" * 80) + "`r`n")
$UI.TextboxStatus.AppendText(($deps.Issues -join "`r`n") + "`r`n`r`n")

if (-not $deps.HasYtDlp -or -not $deps.HasFfmpeg) {
    $UI.TextboxStatus.AppendText("⚠️ WARNING: Missing dependencies detected!`r`n")
    $UI.TextboxStatus.AppendText("Please go to Tools > Check Dependencies to install missing packages.`r`n`r`n")
    $UI.LabelStatusValue.Text = "⚠️ Missing dependencies - Check Tools menu"
    $UI.LabelStatusValue.ForeColor = [System.Drawing.Color]::Red
} else {
    $UI.TextboxStatus.AppendText("✅ All dependencies installed successfully!`r`n")
    $UI.TextboxStatus.AppendText("✨ New in v4.0: Async processing, Download history, Retry support, Rate limiting`r`n")
    $UI.TextboxStatus.AppendText("Ready to download. Enter a YouTube URL to begin.`r`n")
    $UI.LabelStatusValue.Text = "✅ Ready - All systems operational"
    $UI.LabelStatusValue.ForeColor = [System.Drawing.Color]::DarkGreen
}

# Show form
[void]$UI.Form.ShowDialog()
#EndRegion
