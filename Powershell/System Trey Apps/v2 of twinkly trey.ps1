Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName WindowsFormsIntegration

# ============================================================
# C# INTEROP - DDC/CI Monitor Control + WMI Bridge
# ============================================================
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Management;

public class MonitorInterop {
    // ---- DDC/CI via dxva2.dll ----
    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, ref uint pdwNumberOfPhysicalMonitors);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint dwPhysicalMonitorArraySize, [Out] PHYSICAL_MONITOR[] pPhysicalMonitorArray);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetMonitorBrightness(IntPtr hMonitor, ref uint pdwMinimumBrightness, ref uint pdwCurrentBrightness, ref uint pdwMaximumBrightness);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool SetMonitorBrightness(IntPtr hMonitor, uint dwNewBrightness);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetMonitorContrast(IntPtr hMonitor, ref uint pdwMinimumContrast, ref uint pdwCurrentContrast, ref uint pdwMaximumContrast);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool SetMonitorContrast(IntPtr hMonitor, uint dwNewContrast);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetMonitorCapabilities(IntPtr hMonitor, ref uint pdwMonitorCapabilities, ref uint pdwSupportedColorTemperatures);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetVCPFeatureAndVCPFeatureReply(IntPtr hMonitor, byte bVCPCode, IntPtr pvct, ref uint pdwCurrentValue, ref uint pdwMaximumValue);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool SetVCPFeature(IntPtr hMonitor, byte bVCPCode, uint dwNewValue);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool DestroyPhysicalMonitor(IntPtr hMonitor);

    [DllImport("user32.dll")]
    public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumProc lpfnEnum, IntPtr dwData);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFOEX lpmi);

    public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT lprcMonitor, IntPtr dwData);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct PHYSICAL_MONITOR {
        public IntPtr hPhysicalMonitor;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szPhysicalMonitorDescription;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left, Top, Right, Bottom;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct MONITORINFOEX {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string szDevice;
    }

    // ---- Monitor Info ----
    public class MonitorInfo {
        public int Index;
        public IntPtr hPhysicalMonitor;
        public IntPtr hLogicalMonitor;
        public string Description;
        public string DeviceName;
        public int Left, Top, Right, Bottom;
        public uint MinBrightness, MaxBrightness, CurrentBrightness;
        public uint MinContrast, MaxContrast, CurrentContrast;
        public bool SupportsBrightness;
        public bool SupportsContrast;
        public bool IsInternal;
        public string MonitorID;
    }

    private static List<MonitorInfo> _allMonitors = new List<MonitorInfo>();

    private static bool EnumCallback(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT lprcMonitor, IntPtr dwData) {
        // Get monitor info
        MONITORINFOEX mInfo = new MONITORINFOEX();
        mInfo.cbSize = Marshal.SizeOf(typeof(MONITORINFOEX));
        GetMonitorInfo(hMonitor, ref mInfo);

        uint numPhysical = 0;
        GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, ref numPhysical);

        if (numPhysical > 0) {
            PHYSICAL_MONITOR[] physMons = new PHYSICAL_MONITOR[numPhysical];
            GetPhysicalMonitorsFromHMONITOR(hMonitor, numPhysical, physMons);

            foreach (var pm in physMons) {
                MonitorInfo info = new MonitorInfo();
                info.Index = _allMonitors.Count + 1;
                info.hPhysicalMonitor = pm.hPhysicalMonitor;
                info.hLogicalMonitor = hMonitor;
                info.Description = pm.szPhysicalMonitorDescription ?? "Unknown Monitor";
                info.DeviceName = mInfo.szDevice ?? "";
                info.Left = mInfo.rcMonitor.Left;
                info.Top = mInfo.rcMonitor.Top;
                info.Right = mInfo.rcMonitor.Right;
                info.Bottom = mInfo.rcMonitor.Bottom;
                info.MonitorID = "MONITOR_" + info.Index + "_" + info.DeviceName;

                // Try brightness
                uint minB = 0, curB = 0, maxB = 0;
                info.SupportsBrightness = GetMonitorBrightness(pm.hPhysicalMonitor, ref minB, ref curB, ref maxB);
                if (info.SupportsBrightness) {
                    info.MinBrightness = minB;
                    info.CurrentBrightness = curB;
                    info.MaxBrightness = maxB;
                }

                // Try contrast
                uint minC = 0, curC = 0, maxC = 0;
                info.SupportsContrast = GetMonitorContrast(pm.hPhysicalMonitor, ref minC, ref curC, ref maxC);
                if (info.SupportsContrast) {
                    info.MinContrast = minC;
                    info.CurrentContrast = curC;
                    info.MaxContrast = maxC;
                }

                _allMonitors.Add(info);
            }
        }
        return true;
    }

    public static MonitorInfo[] GetAllMonitors() {
        _allMonitors.Clear();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, EnumCallback, IntPtr.Zero);
        return _allMonitors.ToArray();
    }

    public static bool SetBrightness(IntPtr hPhysicalMonitor, uint brightness) {
        return SetMonitorBrightness(hPhysicalMonitor, brightness);
    }

    public static bool SetContrastValue(IntPtr hPhysicalMonitor, uint contrast) {
        return SetMonitorContrast(hPhysicalMonitor, contrast);
    }

    public static uint[] GetBrightness(IntPtr hPhysicalMonitor) {
        uint min = 0, cur = 0, max = 0;
        bool ok = GetMonitorBrightness(hPhysicalMonitor, ref min, ref cur, ref max);
        return new uint[] { min, cur, max, ok ? 1u : 0u };
    }

    public static uint[] GetContrast(IntPtr hPhysicalMonitor) {
        uint min = 0, cur = 0, max = 0;
        bool ok = GetMonitorContrast(hPhysicalMonitor, ref min, ref cur, ref max);
        return new uint[] { min, cur, max, ok ? 1u : 0u };
    }

    public static bool SendVCP(IntPtr hPhysicalMonitor, byte vcpCode, uint value) {
        return SetVCPFeature(hPhysicalMonitor, vcpCode, value);
    }

    public static uint[] GetVCP(IntPtr hPhysicalMonitor, byte vcpCode) {
        uint cur = 0, max = 0;
        bool ok = GetVCPFeatureAndVCPFeatureReply(hPhysicalMonitor, vcpCode, IntPtr.Zero, ref cur, ref max);
        return new uint[] { cur, max, ok ? 1u : 0u };
    }

    public static void DestroyAll(MonitorInfo[] monitors) {
        foreach (var m in monitors) {
            DestroyPhysicalMonitor(m.hPhysicalMonitor);
        }
    }

    // ---- WMI brightness for internal/laptop displays ----
    public static int GetWmiBrightness() {
        try {
            using (var searcher = new ManagementObjectSearcher("root\\WMI", "SELECT CurrentBrightness FROM WmiMonitorBrightness")) {
                foreach (ManagementObject obj in searcher.Get()) {
                    return Convert.ToInt32(obj["CurrentBrightness"]);
                }
            }
        } catch { }
        return -1;
    }

    public static bool SetWmiBrightness(int brightness) {
        try {
            using (var searcher = new ManagementObjectSearcher("root\\WMI", "SELECT * FROM WmiMonitorBrightnessMethods")) {
                foreach (ManagementObject obj in searcher.Get()) {
                    obj.InvokeMethod("WmiSetBrightness", new object[] { (uint)1, (byte)brightness });
                    return true;
                }
            }
        } catch { }
        return false;
    }
}
"@ -ReferencedAssemblies @("System.Management")

# ============================================================
# GLOBAL STATE
# ============================================================
$script:monitors = @()
$script:settings = @{
    Theme = "auto"           # auto, light, dark
    WindowsVersion = "auto"  # auto, win10, win11
    StartWithWindows = $false
    StartMinimized = $true
    IdleDim = $false
    IdleDimBrightness = 20
    IdleDimMinutes = 10
    TimeBased = $false
    DayBrightness = 100
    NightBrightness = 40
    DayStartHour = 7
    NightStartHour = 20
    NormalizeBrightness = $false
    ShowOverlay = $true
    HotkeyAllUp = ""
    HotkeyAllDown = ""
    LinkedBrightness = $false
    StartupGracePeriod = 5
}
$script:isExiting = $false
$script:overlayTimer = $null
$script:idleTimer = $null
$script:timeCheckTimer = $null
$script:startupTime = Get-Date

# ============================================================
# DETECT WINDOWS VERSION & THEME
# ============================================================
function Get-WindowsVersion {
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -ge 22000) { return "win11" }
    return "win10"
}

function Get-SystemTheme {
    try {
        $reg = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
        if ($reg.AppsUseLightTheme -eq 0) { return "dark" }
        return "light"
    } catch {
        return "dark"
    }
}

function Get-TaskbarColor {
    try {
        $reg = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
        if ($reg.SystemUsesLightTheme -eq 0) { return "dark" }
        return "light"
    } catch {
        return "dark"
    }
}

function Get-AccentColor {
    try {
        $reg = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\DWM" -ErrorAction SilentlyContinue
        $abgr = $reg.AccentColor
        $r = ($abgr -band 0xFF)
        $g = (($abgr -shr 8) -band 0xFF)
        $b = (($abgr -shr 16) -band 0xFF)
        return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
    } catch {
        return [System.Drawing.Color]::FromArgb(255, 59, 130, 246)
    }
}

$script:winVersion = Get-WindowsVersion
$script:systemTheme = Get-SystemTheme
$script:taskbarTheme = Get-TaskbarColor
$script:accentColor = Get-AccentColor
$script:isDark = ($script:systemTheme -eq "dark")

# Theme colors
function Get-ThemeColors {
    if ($script:isDark) {
        return @{
            Background = "#2b2b2b"
            BackgroundAlt = "#1e1e1e"
            Surface = "#353535"
            SurfaceHover = "#404040"
            Text = "#e4e4e7"
            TextSecondary = "#a1a1aa"
            TextMuted = "#71717a"
            Border = "#3f3f46"
            Accent = "#3b82f6"
            AccentHover = "#2563eb"
            Danger = "#dc2626"
            SliderTrack = "#3f3f46"
            SliderFill = "#3b82f6"
            CardBg = "#2d2d30"
            InputBg = "#252526"
        }
    } else {
        return @{
            Background = "#f3f3f3"
            BackgroundAlt = "#ffffff"
            Surface = "#e5e5e5"
            SurfaceHover = "#d4d4d8"
            Text = "#18181b"
            TextSecondary = "#52525b"
            TextMuted = "#a1a1aa"
            Border = "#d4d4d8"
            Accent = "#2563eb"
            AccentHover = "#1d4ed8"
            Danger = "#dc2626"
            SliderTrack = "#d4d4d8"
            SliderFill = "#2563eb"
            CardBg = "#ffffff"
            InputBg = "#f4f4f5"
        }
    }
}

$script:colors = Get-ThemeColors

# ============================================================
# REFRESH MONITORS
# ============================================================
function Refresh-Monitors {
    # Destroy old handles
    if ($script:monitors.Count -gt 0) {
        foreach ($m in $script:monitors) {
            if ($m.hPhysicalMonitor -ne [IntPtr]::Zero) {
                [MonitorInterop]::DestroyPhysicalMonitor($m.hPhysicalMonitor) | Out-Null
            }
        }
    }

    $ddcMonitors = [MonitorInterop]::GetAllMonitors()
    $script:monitors = @()

    # Check for WMI (internal/laptop) display
    $wmiBrightness = [MonitorInterop]::GetWmiBrightness()
    if ($wmiBrightness -ge 0) {
        $internalMon = New-Object PSObject -Property @{
            Index = 0
            Name = "Built-in Display"
            DeviceName = "Internal"
            MonitorID = "WMI_INTERNAL"
            IsInternal = $true
            MinBrightness = 0
            MaxBrightness = 100
            CurrentBrightness = $wmiBrightness
            SupportsBrightness = $true
            SupportsContrast = $false
            CurrentContrast = 0
            MinContrast = 0
            MaxContrast = 0
            hPhysicalMonitor = [IntPtr]::Zero
        }
        $script:monitors += $internalMon
    }

    # Add DDC/CI monitors
    $idx = $script:monitors.Count + 1
    foreach ($m in $ddcMonitors) {
        $mon = New-Object PSObject -Property @{
            Index = $idx
            Name = if ($m.Description) { $m.Description } else { "Display $idx" }
            DeviceName = $m.DeviceName
            MonitorID = $m.MonitorID
            IsInternal = $false
            MinBrightness = [int]$m.MinBrightness
            MaxBrightness = [int]$m.MaxBrightness
            CurrentBrightness = [int]$m.CurrentBrightness
            SupportsBrightness = $m.SupportsBrightness
            SupportsContrast = $m.SupportsContrast
            CurrentContrast = [int]$m.CurrentContrast
            MinContrast = [int]$m.MinContrast
            MaxContrast = [int]$m.MaxContrast
            hPhysicalMonitor = $m.hPhysicalMonitor
        }
        $script:monitors += $mon
        $idx++
    }
}

Refresh-Monitors

# ============================================================
# BRIGHTNESS FUNCTIONS
# ============================================================
function Set-MonitorBrightness {
    param(
        [int]$MonitorIndex = -1,
        [int]$Brightness,
        [switch]$All
    )

    $brightness = [Math]::Max(0, [Math]::Min(100, $Brightness))

    if ($All) {
        foreach ($m in $script:monitors) {
            Set-SingleMonitorBrightness -Monitor $m -Brightness $brightness
        }
    } elseif ($MonitorIndex -ge 0 -and $MonitorIndex -lt $script:monitors.Count) {
        Set-SingleMonitorBrightness -Monitor $script:monitors[$MonitorIndex] -Brightness $brightness
    }
}

function Set-SingleMonitorBrightness {
    param($Monitor, [int]$Brightness)

    if (-not $Monitor.SupportsBrightness) { return }

    # Normalize if needed
    $targetBrightness = $Brightness
    if ($Monitor.MaxBrightness -gt 0 -and $Monitor.MaxBrightness -ne 100) {
        $targetBrightness = [Math]::Round(($Brightness / 100.0) * $Monitor.MaxBrightness)
    }

    if ($Monitor.IsInternal) {
        [MonitorInterop]::SetWmiBrightness($Brightness) | Out-Null
    } else {
        [MonitorInterop]::SetBrightness($Monitor.hPhysicalMonitor, [uint32]$targetBrightness) | Out-Null
    }

    $Monitor.CurrentBrightness = $Brightness
}

function Set-MonitorContrast {
    param($MonitorIndex, [int]$Contrast)
    if ($MonitorIndex -ge 0 -and $MonitorIndex -lt $script:monitors.Count) {
        $m = $script:monitors[$MonitorIndex]
        if ($m.SupportsContrast -and -not $m.IsInternal) {
            [MonitorInterop]::SetContrastValue($m.hPhysicalMonitor, [uint32]$Contrast) | Out-Null
            $m.CurrentContrast = $Contrast
        }
    }
}

function Send-VCPCode {
    param($MonitorIndex, [byte]$VCPCode, [uint32]$Value)
    if ($MonitorIndex -ge 0 -and $MonitorIndex -lt $script:monitors.Count) {
        $m = $script:monitors[$MonitorIndex]
        if (-not $m.IsInternal) {
            [MonitorInterop]::SendVCP($m.hPhysicalMonitor, $VCPCode, $Value) | Out-Null
        }
    }
}

function Offset-MonitorBrightness {
    param(
        [int]$MonitorIndex = -1,
        [int]$Offset,
        [switch]$All
    )

    if ($All) {
        foreach ($m in $script:monitors) {
            $idx = [array]::IndexOf($script:monitors, $m)
            $newVal = [Math]::Max(0, [Math]::Min(100, $m.CurrentBrightness + $Offset))
            Set-SingleMonitorBrightness -Monitor $m -Brightness $newVal
        }
    } elseif ($MonitorIndex -ge 0 -and $MonitorIndex -lt $script:monitors.Count) {
        $m = $script:monitors[$MonitorIndex]
        $newVal = [Math]::Max(0, [Math]::Min(100, $m.CurrentBrightness + $Offset))
        Set-SingleMonitorBrightness -Monitor $m -Brightness $newVal
    }
}

# ============================================================
# CREATE SYSTEM TRAY ICON
# ============================================================
function New-BrightnessIcon {
    param([int]$Brightness = 50)

    $bmp = New-Object System.Drawing.Bitmap(32, 32)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::Transparent)

    # Sun body - size varies with brightness
    $sunSize = [Math]::Max(8, [int](8 + ($Brightness / 100.0) * 10))
    $sunOffset = (32 - $sunSize) / 2

    $sunColor = [System.Drawing.Color]::FromArgb(255,
        [Math]::Min(255, 150 + [int]($Brightness * 1.05)),
        [Math]::Min(255, 120 + [int]($Brightness * 0.8)),
        [Math]::Max(0, [int]($Brightness * 0.3)))

    $brush = New-Object System.Drawing.SolidBrush($sunColor)
    $g.FillEllipse($brush, $sunOffset, $sunOffset, $sunSize, $sunSize)

    # Rays - only if brightness > 15
    if ($Brightness -gt 15) {
        $rayLen = [Math]::Max(2, [int](($Brightness / 100.0) * 5))
        $pen = New-Object System.Drawing.Pen($sunColor, 1.5)
        $center = 16
        $outerStart = ($sunSize / 2) + 2 + $sunOffset - $center

        # 8 rays
        for ($angle = 0; $angle -lt 360; $angle += 45) {
            $rad = $angle * [Math]::PI / 180
            $x1 = $center + [int](($outerStart + 1) * [Math]::Cos($rad))
            $y1 = $center + [int](($outerStart + 1) * [Math]::Sin($rad))
            $x2 = $center + [int](($outerStart + 1 + $rayLen) * [Math]::Cos($rad))
            $y2 = $center + [int](($outerStart + 1 + $rayLen) * [Math]::Sin($rad))
            $g.DrawLine($pen, $x1, $y1, $x2, $y2)
        }
        $pen.Dispose()
    }

    $brush.Dispose()
    $g.Dispose()

    $hIcon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon)
    return $icon
}

$script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:notifyIcon.Text = "Brightness Control"
$script:notifyIcon.Visible = $true
$script:notifyIcon.Icon = New-BrightnessIcon -Brightness 50

function Update-TrayIcon {
    $avgBrightness = 50
    if ($script:monitors.Count -gt 0) {
        $sum = 0
        $count = 0
        foreach ($m in $script:monitors) {
            if ($m.SupportsBrightness) {
                $sum += $m.CurrentBrightness
                $count++
            }
        }
        if ($count -gt 0) { $avgBrightness = [int]($sum / $count) }
    }

    $script:notifyIcon.Icon = New-BrightnessIcon -Brightness $avgBrightness

    $tooltipLines = "Brightness Control`n"
    foreach ($m in $script:monitors) {
        if ($m.SupportsBrightness) {
            $tooltipLines += "$($m.Name): $($m.CurrentBrightness)%`n"
        }
    }
    # NotifyIcon.Text has 63-char limit
    $script:notifyIcon.Text = $tooltipLines.Substring(0, [Math]::Min(63, $tooltipLines.Length))
}

# ============================================================
# OVERLAY WINDOW (Win10/11 style brightness popup)
# ============================================================
function Show-BrightnessOverlay {
    param([string]$MonitorName = "All Displays", [int]$Brightness = 50)

    if (-not $script:settings.ShowOverlay) { return }

    if ($null -ne $script:overlayWindow -and $script:overlayWindow.IsLoaded) {
        # Update existing overlay
        $script:overlayLabel.Text = "$MonitorName"
        $script:overlayValue.Text = "$Brightness%"
        $script:overlayBar.Width = [Math]::Max(0, ($Brightness / 100.0) * 280)
        $script:overlayWindow.Show()
        $script:overlayWindow.Activate()
    }

    # Reset auto-hide timer
    if ($null -ne $script:overlayTimer) {
        $script:overlayTimer.Stop()
    }
    $script:overlayTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:overlayTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:overlayTimer.Add_Tick({
        $script:overlayTimer.Stop()
        if ($null -ne $script:overlayWindow) {
            $script:overlayWindow.Hide()
        }
    })
    $script:overlayTimer.Start()
}

# ============================================================
# MAIN WPF WINDOW - TWINKLE TRAY STYLE PANEL
# ============================================================
function Build-MainWindow {
    $colors = Get-ThemeColors
    $cornerRadius = if ($script:winVersion -eq "win11") { "8" } else { "0" }
    $borderThickness = if ($script:winVersion -eq "win11") { "1" } else { "1" }

    # Build monitor sliders XAML dynamically
    $monitorSlidersXaml = ""
    $monitorIndex = 0
    foreach ($m in $script:monitors) {
        if ($m.SupportsBrightness) {
            $monitorSlidersXaml += @"
                <!-- Monitor $monitorIndex -->
                <Border Background="$($colors.CardBg)" CornerRadius="6" Padding="14,10" Margin="0,0,0,8">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="8"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid Grid.Row="0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="$([System.Security.SecurityElement]::Escape($m.Name))" 
                                       FontSize="13" Foreground="$($colors.Text)" FontWeight="SemiBold"
                                       VerticalAlignment="Center"/>
                            <TextBlock Grid.Column="2" Name="MonLabel_$monitorIndex" 
                                       Text="$($m.CurrentBrightness)%" 
                                       FontSize="13" Foreground="$($colors.TextSecondary)"
                                       VerticalAlignment="Center" FontWeight="SemiBold"/>
                        </Grid>
                        <Grid Grid.Row="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="&#x1F315;" FontSize="12" 
                                       VerticalAlignment="Center" Margin="0,0,8,0"
                                       Foreground="$($colors.TextMuted)"/>
                            <Slider Grid.Column="1" Name="MonSlider_$monitorIndex"
                                    Minimum="0" Maximum="100" Value="$($m.CurrentBrightness)"
                                    TickFrequency="1" IsSnapToTickEnabled="True"
                                    VerticalAlignment="Center"/>
                            <TextBlock Grid.Column="2" Text="&#x2600;" FontSize="14"
                                       VerticalAlignment="Center" Margin="8,0,0,0"
                                       Foreground="$($colors.TextMuted)"/>
                        </Grid>
                    </Grid>
                </Border>
"@

            # Add contrast slider if supported
            if ($m.SupportsContrast) {
                $monitorSlidersXaml += @"
                <Border Background="$($colors.CardBg)" CornerRadius="6" Padding="14,10" Margin="0,0,0,8">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="8"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid Grid.Row="0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="Contrast" 
                                       FontSize="12" Foreground="$($colors.TextSecondary)"
                                       VerticalAlignment="Center"/>
                            <TextBlock Grid.Column="1" Name="ContrastLabel_$monitorIndex" 
                                       Text="$($m.CurrentContrast)%" 
                                       FontSize="12" Foreground="$($colors.TextSecondary)"
                                       VerticalAlignment="Center"/>
                        </Grid>
                        <Slider Grid.Row="2" Name="ContrastSlider_$monitorIndex"
                                Minimum="$($m.MinContrast)" Maximum="$($m.MaxContrast)" 
                                Value="$($m.CurrentContrast)"
                                TickFrequency="1" IsSnapToTickEnabled="True"
                                VerticalAlignment="Center"/>
                    </Grid>
                </Border>
"@
            }
            $monitorIndex++
        }
    }

    if ($monitorSlidersXaml -eq "") {
        $monitorSlidersXaml = @"
                <Border Background="$($colors.CardBg)" CornerRadius="6" Padding="20" Margin="0,0,0,8">
                    <StackPanel HorizontalAlignment="Center">
                        <TextBlock Text="No compatible displays found" 
                                   FontSize="14" Foreground="$($colors.TextSecondary)"
                                   HorizontalAlignment="Center" Margin="0,0,0,8"/>
                        <TextBlock Text="Make sure DDC/CI is enabled on your monitor(s)" 
                                   FontSize="11" Foreground="$($colors.TextMuted)"
                                   HorizontalAlignment="Center" TextWrapping="Wrap"
                                   TextAlignment="Center"/>
                        <Button Name="RefreshBtn" Content="Refresh Displays" 
                                Margin="0,12,0,0" Height="30"
                                Background="$($colors.Accent)" Foreground="White"
                                BorderThickness="0" Cursor="Hand" Padding="16,0"/>
                    </StackPanel>
                </Border>
"@
    }

    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Brightness Control" 
        SizeToContent="Height" Width="360"
        WindowStartupLocation="Manual"
        ResizeMode="NoResize"
        Background="Transparent"
        WindowStyle="None"
        AllowsTransparency="True"
        Topmost="True"
        ShowInTaskbar="False">
    <Border CornerRadius="$cornerRadius" 
            Background="$($colors.Background)" 
            BorderBrush="$($colors.Border)" 
            BorderThickness="$borderThickness">
        <Border.Effect>
            <DropShadowEffect Color="Black" Direction="0" ShadowDepth="0" 
                              Opacity="0.4" BlurRadius="15"/>
        </Border.Effect>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Header -->
            <Border Grid.Row="0" Padding="16,12" Name="TitleBar">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0" Text="Brightness" 
                               FontSize="15" FontWeight="SemiBold" 
                               Foreground="$($colors.Text)" 
                               VerticalAlignment="Center"/>
                    <Button Grid.Column="1" Name="RefreshButton" Content="&#x21BB;" 
                            Width="28" Height="28"
                            Background="Transparent" Foreground="$($colors.TextSecondary)"
                            BorderThickness="0" FontSize="16" Cursor="Hand"
                            ToolTip="Refresh displays" Margin="0,0,4,0"/>
                    <Button Grid.Column="2" Name="SettingsButton" Content="&#x2699;" 
                            Width="28" Height="28"
                            Background="Transparent" Foreground="$($colors.TextSecondary)"
                            BorderThickness="0" FontSize="16" Cursor="Hand"
                            ToolTip="Settings" Margin="0,0,4,0"/>
                    <Button Grid.Column="3" Name="CloseButton" Content="&#x2715;" 
                            Width="28" Height="28"
                            Background="Transparent" Foreground="$($colors.TextSecondary)"
                            BorderThickness="0" FontSize="14" Cursor="Hand"
                            ToolTip="Close"/>
                </Grid>
            </Border>

            <!-- Monitor Sliders -->
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" 
                          MaxHeight="400" Padding="12,0,12,0">
                <StackPanel Name="MonitorPanel">
                    $monitorSlidersXaml

                    <!-- Link All toggle -->
                    <Border Background="$($colors.CardBg)" CornerRadius="6" 
                            Padding="14,8" Margin="0,0,0,8"
                            Visibility="$(if ($script:monitors.Count -gt 1) { 'Visible' } else { 'Collapsed' })">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="Link all displays" 
                                       FontSize="12" Foreground="$($colors.TextSecondary)"
                                       VerticalAlignment="Center"/>
                            <CheckBox Grid.Column="1" Name="LinkToggle" 
                                      IsChecked="$($script:settings.LinkedBrightness)"
                                      VerticalAlignment="Center"/>
                        </Grid>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- Quick Presets -->
            <Border Grid.Row="2" Padding="12,4,12,12">
                <UniformGrid Columns="5" Rows="1">
                    <Button Name="Preset0" Content="0%" Margin="0,0,3,0" Height="28"
                            Background="$($colors.Surface)" Foreground="$($colors.TextSecondary)"
                            BorderThickness="0" FontSize="11" Cursor="Hand"/>
                    <Button Name="Preset25" Content="25%" Margin="2,0,2,0" Height="28"
                            Background="$($colors.Surface)" Foreground="$($colors.TextSecondary)"
                            BorderThickness="0" FontSize="11" Cursor="Hand"/>
                    <Button Name="Preset50" Content="50%" Margin="2,0,2,0" Height="28"
                            Background="$($colors.Surface)" Foreground="$($colors.TextSecondary)"
                            BorderThickness="0" FontSize="11" Cursor="Hand"/>
                    <Button Name="Preset75" Content="75%" Margin="2,0,2,0" Height="28"
                            Background="$($colors.Surface)" Foreground="$($colors.TextSecondary)"
                            BorderThickness="0" FontSize="11" Cursor="Hand"/>
                    <Button Name="Preset100" Content="100%" Margin="3,0,0,0" Height="28"
                            Background="$($colors.Surface)" Foreground="$($colors.TextSecondary)"
                            BorderThickness="0" FontSize="11" Cursor="Hand"/>
                </UniformGrid>
            </Border>
        </Grid>
    </Border>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $script:window = [Windows.Markup.XamlReader]::Load($reader)

    if ($null -eq $script:window) {
        Write-Error "Failed to create main window!"
        return
    }

    # Get controls
    $titleBar = $script:window.FindName("TitleBar")
    $closeButton = $script:window.FindName("CloseButton")
    $refreshButton = $script:window.FindName("RefreshButton")
    $settingsButton = $script:window.FindName("SettingsButton")
    $linkToggle = $script:window.FindName("LinkToggle")
    $preset0 = $script:window.FindName("Preset0")
    $preset25 = $script:window.FindName("Preset25")
    $preset50 = $script:window.FindName("Preset50")
    $preset75 = $script:window.FindName("Preset75")
    $preset100 = $script:window.FindName("Preset100")

    # Drag window
    $titleBar.Add_MouseLeftButtonDown({ $script:window.DragMove() })

    # Close button hides to tray
    $closeButton.Add_Click({ $script:window.Hide() })

    # Refresh button
    $refreshButton.Add_Click({
        Refresh-Monitors
        Update-TrayIcon
        # Rebuild window
        $script:window.Hide()
        $wasVisible = $true
        Build-MainWindow
        if ($wasVisible) {
            Position-WindowAtTray
            $script:window.Show()
            $script:window.Activate()
        }
    })

    # Settings button
    $settingsButton.Add_Click({
        Show-SettingsWindow
    })

    # Link toggle
    if ($null -ne $linkToggle) {
        $linkToggle.Add_Checked({ $script:settings.LinkedBrightness = $true })
        $linkToggle.Add_Unchecked({ $script:settings.LinkedBrightness = $false })
    }

    # Wire up monitor sliders
    $compatibleIndex = 0
    foreach ($m in $script:monitors) {
        if ($m.SupportsBrightness) {
            $slider = $script:window.FindName("MonSlider_$compatibleIndex")
            $label = $script:window.FindName("MonLabel_$compatibleIndex")
            $ci = $compatibleIndex  # capture for closure

            if ($null -ne $slider) {
                $slider.Add_ValueChanged({
                    param($sender, $e)
                    $val = [int]$sender.Value
                    $lbl = $script:window.FindName("MonLabel_$ci")
                    if ($null -ne $lbl) { $lbl.Text = "$val%" }

                    # Find actual monitor index
                    $actualIdx = 0
                    $bIdx = 0
                    foreach ($mon in $script:monitors) {
                        if ($mon.SupportsBrightness) {
                            if ($bIdx -eq $ci) { break }
                            $bIdx++
                        }
                        $actualIdx++
                    }

                    Set-SingleMonitorBrightness -Monitor $script:monitors[$actualIdx] -Brightness $val

                    # If linked, set all
                    if ($script:settings.LinkedBrightness) {
                        $otherIdx = 0
                        foreach ($otherMon in $script:monitors) {
                            if ($otherMon.SupportsBrightness) {
                                if ($otherIdx -ne $ci) {
                                    Set-SingleMonitorBrightness -Monitor $otherMon -Brightness $val
                                    $otherSlider = $script:window.FindName("MonSlider_$otherIdx")
                                    $otherLabel = $script:window.FindName("MonLabel_$otherIdx")
                                    if ($null -ne $otherSlider) {
                                        $otherSlider.Value = $val
                                    }
                                    if ($null -ne $otherLabel) {
                                        $otherLabel.Text = "$val%"
                                    }
                                }
                                $otherIdx++
                            }
                        }
                    }

                    Update-TrayIcon
                }.GetNewClosure())
            }

            # Contrast slider
            $contrastSlider = $script:window.FindName("ContrastSlider_$compatibleIndex")
            $contrastLabel = $script:window.FindName("ContrastLabel_$compatibleIndex")
            if ($null -ne $contrastSlider) {
                $contrastSlider.Add_ValueChanged({
                    param($sender, $e)
                    $val = [int]$sender.Value
                    $lbl = $script:window.FindName("ContrastLabel_$ci")
                    if ($null -ne $lbl) { $lbl.Text = "$val%" }

                    $actualIdx = 0
                    $bIdx = 0
                    foreach ($mon in $script:monitors) {
                        if ($mon.SupportsBrightness) {
                            if ($bIdx -eq $ci) { break }
                            $bIdx++
                        }
                        $actualIdx++
                    }
                    Set-MonitorContrast -MonitorIndex $actualIdx -Contrast $val
                }.GetNewClosure())
            }

            $compatibleIndex++
        }
    }

    # Refresh button (for no-monitors case)
    $refreshBtn = $script:window.FindName("RefreshBtn")
    if ($null -ne $refreshBtn) {
        $refreshBtn.Add_Click({
            Refresh-Monitors
            $script:window.Hide()
            Build-MainWindow
            Position-WindowAtTray
            $script:window.Show()
        })
    }

    # Preset buttons
    $presetAction = {
        param($value)
        Set-MonitorBrightness -Brightness $value -All
        # Update all sliders
        $idx = 0
        foreach ($m in $script:monitors) {
            if ($m.SupportsBrightness) {
                $s = $script:window.FindName("MonSlider_$idx")
                $l = $script:window.FindName("MonLabel_$idx")
                if ($null -ne $s) { $s.Value = $value }
                if ($null -ne $l) { $l.Text = "$value%" }
                $idx++
            }
        }
        Update-TrayIcon
    }

    if ($null -ne $preset0)   { $preset0.Add_Click({ & $presetAction 0 }.GetNewClosure()) }
    if ($null -ne $preset25)  { $preset25.Add_Click({ & $presetAction 25 }.GetNewClosure()) }
    if ($null -ne $preset50)  { $preset50.Add_Click({ & $presetAction 50 }.GetNewClosure()) }
    if ($null -ne $preset75)  { $preset75.Add_Click({ & $presetAction 75 }.GetNewClosure()) }
    if ($null -ne $preset100) { $preset100.Add_Click({ & $presetAction 100 }.GetNewClosure()) }

    # Deactivated = hide (click away to dismiss, like Twinkle Tray)
    $script:window.Add_Deactivated({
        $script:window.Hide()
    })

    # Closing handler
    $script:window.Add_Closing({
        param($s, $e)
        if (-not $script:isExiting) {
            $e.Cancel = $true
            $script:window.Hide()
        }
    })

    $script:window.Add_Closed({
        foreach ($m in $script:monitors) {
            if ($m.hPhysicalMonitor -ne [IntPtr]::Zero) {
                [MonitorInterop]::DestroyPhysicalMonitor($m.hPhysicalMonitor) | Out-Null
            }
        }
        $script:notifyIcon.Visible = $false
        $script:notifyIcon.Dispose()
    })
}

# ============================================================
# POSITION WINDOW NEAR SYSTEM TRAY (like Twinkle Tray flyout)
# ============================================================
function Position-WindowAtTray {
    if ($null -eq $script:window) { return }

    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $workArea = $screen.WorkingArea
    $taskbarOnTop = ($workArea.Top -gt 0)
    $taskbarOnLeft = ($workArea.Left -gt 0)
    $taskbarOnRight = ($workArea.Right -lt $screen.Bounds.Right)
    $taskbarOnBottom = ($workArea.Bottom -lt $screen.Bounds.Bottom)

    # Ensure window is measured
    $script:window.UpdateLayout()

    $winWidth = $script:window.ActualWidth
    $winHeight = $script:window.ActualHeight
    if ($winWidth -eq 0) { $winWidth = 360 }
    if ($winHeight -eq 0) { $winHeight = 400 }

    $margin = 12

    if ($taskbarOnBottom -or (-not $taskbarOnTop -and -not $taskbarOnLeft -and -not $taskbarOnRight)) {
        # Taskbar at bottom (most common)
        $script:window.Left = $workArea.Right - $winWidth - $margin
        $script:window.Top = $workArea.Bottom - $winHeight - $margin
    } elseif ($taskbarOnTop) {
        $script:window.Left = $workArea.Right - $winWidth - $margin
        $script:window.Top = $workArea.Top + $margin
    } elseif ($taskbarOnRight) {
        $script:window.Left = $workArea.Right - $winWidth - $margin
        $script:window.Top = $workArea.Bottom - $winHeight - $margin
    } elseif ($taskbarOnLeft) {
        $script:window.Left = $workArea.Left + $margin
        $script:window.Top = $workArea.Bottom - $winHeight - $margin
    }
}

# ============================================================
# SETTINGS WINDOW
# ============================================================
function Show-SettingsWindow {
    $colors = Get-ThemeColors

    [xml]$settingsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Brightness Control - Settings" 
        Height="520" Width="450"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        Background="$($colors.Background)"
        Topmost="True"
        ShowInTaskbar="True">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="15"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="15"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <TextBlock Grid.Row="0" Text="Settings" FontSize="20" FontWeight="Bold" 
                   Foreground="$($colors.Text)"/>

        <!-- Settings scroll -->
        <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <!-- General -->
                <TextBlock Text="GENERAL" FontSize="11" FontWeight="Bold" 
                           Foreground="$($colors.TextMuted)" Margin="0,0,0,8"/>

                <Border Background="$($colors.CardBg)" CornerRadius="6" Padding="14,10" Margin="0,0,0,6">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="Start with Windows" Foreground="$($colors.Text)" 
                                   FontSize="13" VerticalAlignment="Center"/>
                        <CheckBox Grid.Column="1" Name="StartWithWindowsCheck" 
                                  IsChecked="$($script:settings.StartWithWindows)"
                                  VerticalAlignment="Center"/>
                    </Grid>
                </Border>

                <Border Background="$($colors.CardBg)" CornerRadius="6" Padding="14,10" Margin="0,0,0,6">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="Show brightness overlay" Foreground="$($colors.Text)" 
                                   FontSize="13" VerticalAlignment="Center"/>
                        <CheckBox Grid.Column="1" Name="ShowOverlayCheck" 
                                  IsChecked="$($script:settings.ShowOverlay)"
                                  VerticalAlignment="Center"/>
                    </Grid>
                </Border>

                <Border Background="$($colors.CardBg)" CornerRadius="6" Padding="14,10" Margin="0,0,0,6">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="Normalize brightness across displays" 
                                   Foreground="$($colors.Text)" FontSize="13" 
                                   VerticalAlignment="Center"/>
                        <CheckBox Grid.Column="1" Name="NormalizeCheck" 
                                  IsChecked="$($script:settings.NormalizeBrightness)"
                                  VerticalAlignment="Center"/>
                    </Grid>
                </Border>

                <!-- Time-Based -->
                <TextBlock Text="TIME-BASED BRIGHTNESS" FontSize="11" FontWeight="Bold" 
                           Foreground="$($colors.TextMuted)" Margin="0,16,0,8"/>

                <Border Background="$($colors.CardBg)" CornerRadius="6" Padding="14,10" Margin="0,0,0,6">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="Adjust brightness by time of day" 
                                   Foreground="$($colors.Text)" FontSize="13"
                                   VerticalAlignment="Center"/>
                        <CheckBox Grid.Column="1" Name="TimeBasedCheck" 
                                  IsChecked="$($script:settings.TimeBased)"
                                  VerticalAlignment="Center"/>
                    </Grid>
                </Border>

                <Border Background="$($colors.CardBg)" CornerRadius="6" Padding="14,10" Margin="0,0,0,6">
                    <StackPanel>
                        <Grid Margin="0,0,0,6">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="60"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Day brightness" Foreground="$($colors.TextSecondary)" 
                                       FontSize="12" VerticalAlignment="Center"/>
                            <TextBox Grid.Column="1" Name="DayBrightnessBox" 
                                     Text="$($script:settings.DayBrightness)"
                                     Background="$($colors.InputBg)" Foreground="$($colors.Text)"
                                     BorderThickness="1" BorderBrush="$($colors.Border)"
                                     Padding="4,2" HorizontalContentAlignment="Center"/>
                        </Grid>
                        <Grid Margin="0,0,0,6">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="60"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Night brightness" Foreground="$($colors.TextSecondary)" 
                                       FontSize="12" VerticalAlignment="Center"/>
                            <TextBox Grid.Column="1" Name="NightBrightnessBox" 
                                     Text="$($script:settings.NightBrightness)"
                                     Background="$($colors.InputBg)" Foreground="$($colors.Text)"
                                     BorderThickness="1" BorderBrush="$($colors.Border)"
                                     Padding="4,2" HorizontalContentAlignment="Center"/>
                        </Grid>
                        <Grid Margin="0,0,0,6">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="60"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Day starts at (hour)" Foreground="$($colors.TextSecondary)" 
                                       FontSize="12" VerticalAlignment="Center"/>
                            <TextBox Grid.Column="1" Name="DayStartBox" 
                                     Text="$($script:settings.DayStartHour)"
                                     Background="$($colors.InputBg)" Foreground="$($colors.Text)"
                                     BorderThickness="1" BorderBrush="$($colors.Border)"
                                     Padding="4,2" HorizontalContentAlignment="Center"/>
                        </Grid>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="60"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Night starts at (hour)" Foreground="$($colors.TextSecondary)" 
                                       FontSize="12" VerticalAlignment="Center"/>
                            <TextBox Grid.Column="1" Name="NightStartBox" 
                                     Text="$($script:settings.NightStartHour)"
                                     Background="$($colors.InputBg)" Foreground="$($colors.Text)"
                                     BorderThickness="1" BorderBrush="$($colors.Border)"
                                     Padding="4,2" HorizontalContentAlignment="Center"/>
                        </Grid>
                    </StackPanel>
                </Border>

                <!-- Idle Dim -->
                <TextBlock Text="IDLE DIMMING" FontSize="11" FontWeight="Bold" 
                           Foreground="$($colors.TextMuted)" Margin="0,16,0,8"/>

                <Border Background="$($colors.CardBg)" CornerRadius="6" Padding="14,10" Margin="0,0,0,6">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="Dim when idle" Foreground="$($colors.Text)" 
                                   FontSize="13" VerticalAlignment="Center"/>
                        <CheckBox Grid.Column="1" Name="IdleDimCheck" 
                                  IsChecked="$($script:settings.IdleDim)"
                                  VerticalAlignment="Center"/>
                    </Grid>
                </Border>

                <Border Background="$($colors.CardBg)" CornerRadius="6" Padding="14,10" Margin="0,0,0,6">
                    <StackPanel>
                        <Grid Margin="0,0,0,6">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="60"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Idle brightness" Foreground="$($colors.TextSecondary)" 
                                       FontSize="12" VerticalAlignment="Center"/>
                            <TextBox Grid.Column="1" Name="IdleBrightnessBox" 
                                     Text="$($script:settings.IdleDimBrightness)"
                                     Background="$($colors.InputBg)" Foreground="$($colors.Text)"
                                     BorderThickness="1" BorderBrush="$($colors.Border)"
                                     Padding="4,2" HorizontalContentAlignment="Center"/>
                        </Grid>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="60"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Idle minutes" Foreground="$($colors.TextSecondary)" 
                                       FontSize="12" VerticalAlignment="Center"/>
                            <TextBox Grid.Column="1" Name="IdleMinutesBox" 
                                     Text="$($script:settings.IdleDimMinutes)"
                                     Background="$($colors.InputBg)" Foreground="$($colors.Text)"
                                     BorderThickness="1" BorderBrush="$($colors.Border)"
                                     Padding="4,2" HorizontalContentAlignment="Center"/>
                        </Grid>
                    </StackPanel>
                </Border>

                <!-- About -->
                <TextBlock Text="ABOUT" FontSize="11" FontWeight="Bold" 
                           Foreground="$($colors.TextMuted)" Margin="0,16,0,8"/>
                <Border Background="$($colors.CardBg)" CornerRadius="6" Padding="14,10" Margin="0,0,0,6">
                    <StackPanel>
                        <TextBlock Foreground="$($colors.Text)" FontSize="13">
                            <Run Text="Brightness Control" FontWeight="SemiBold"/>
                            <Run Text=" (PowerShell Edition)"/>
                        </TextBlock>
                        <TextBlock Foreground="$($colors.TextMuted)" FontSize="11" Margin="0,4,0,0"
                                   Text="Inspired by Twinkle Tray by Xander Frangos"
                                   TextWrapping="Wrap"/>
                        <TextBlock Foreground="$($colors.TextMuted)" FontSize="11" Margin="0,2,0,0"
                                   Text="Uses DDC/CI and WMI for monitor communication"/>
                        <TextBlock Foreground="$($colors.TextMuted)" FontSize="11" Margin="0,2,0,0"
                                   Text="License: MIT"/>
                    </StackPanel>
                </Border>
            </StackPanel>
        </ScrollViewer>

        <!-- Bottom buttons -->
        <Grid Grid.Row="4">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Button Grid.Column="0" Name="ExitAppButton" Content="Exit Application" 
                    Background="$($colors.Danger)" Foreground="White"
                    BorderThickness="0" Height="34" Padding="16,0"
                    FontSize="12" Cursor="Hand" HorizontalAlignment="Left"/>
            <Button Grid.Column="1" Name="CancelButton" Content="Cancel" 
                    Background="$($colors.Surface)" Foreground="$($colors.Text)"
                    BorderThickness="0" Height="34" Width="80"
                    FontSize="12" Cursor="Hand"/>
            <Button Grid.Column="3" Name="SaveButton" Content="Save" 
                    Background="$($colors.Accent)" Foreground="White"
                    BorderThickness="0" Height="34" Width="80"
                    FontSize="12" Cursor="Hand"/>
        </Grid>
    </Grid>
</Window>
"@

    $settingsReader = New-Object System.Xml.XmlNodeReader $settingsXaml
    $settingsWindow = [Windows.Markup.XamlReader]::Load($settingsReader)

    if ($null -eq $settingsWindow) {
        Write-Error "Failed to create settings window!"
        return
    }

    # Get settings controls
    $startCheck = $settingsWindow.FindName("StartWithWindowsCheck")
    $overlayCheck = $settingsWindow.FindName("ShowOverlayCheck")
    $normalizeCheck = $settingsWindow.FindName("NormalizeCheck")
    $timeBasedCheck = $settingsWindow.FindName("TimeBasedCheck")
    $dayBrightnessBox = $settingsWindow.FindName("DayBrightnessBox")
    $nightBrightnessBox = $settingsWindow.FindName("NightBrightnessBox")
    $dayStartBox = $settingsWindow.FindName("DayStartBox")
    $nightStartBox = $settingsWindow.FindName("NightStartBox")
    $idleDimCheck = $settingsWindow.FindName("IdleDimCheck")
    $idleBrightnessBox = $settingsWindow.FindName("IdleBrightnessBox")
    $idleMinutesBox = $settingsWindow.FindName("IdleMinutesBox")
    $exitAppButton = $settingsWindow.FindName("ExitAppButton")
    $cancelButton = $settingsWindow.FindName("CancelButton")
    $saveButton = $settingsWindow.FindName("SaveButton")

    $cancelButton.Add_Click({ $settingsWindow.Close() })

    $saveButton.Add_Click({
        # Save settings
        $script:settings.StartWithWindows = $startCheck.IsChecked
        $script:settings.ShowOverlay = $overlayCheck.IsChecked
        $script:settings.NormalizeBrightness = $normalizeCheck.IsChecked
        $script:settings.TimeBased = $timeBasedCheck.IsChecked
        $script:settings.IdleDim = $idleDimCheck.IsChecked

        try { $script:settings.DayBrightness = [int]$dayBrightnessBox.Text } catch {}
        try { $script:settings.NightBrightness = [int]$nightBrightnessBox.Text } catch {}
        try { $script:settings.DayStartHour = [int]$dayStartBox.Text } catch {}
        try { $script:settings.NightStartHour = [int]$nightStartBox.Text } catch {}
        try { $script:settings.IdleDimBrightness = [int]$idleBrightnessBox.Text } catch {}
        try { $script:settings.IdleDimMinutes = [int]$idleMinutesBox.Text } catch {}

        # Handle startup registry
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        $appName = "BrightnessControl"
        if ($script:settings.StartWithWindows) {
            $scriptPath = $MyInvocation.ScriptName
            if ($scriptPath) {
                Set-ItemProperty -Path $regPath -Name $appName -Value "powershell.exe -WindowStyle Hidden -File `"$scriptPath`"" -ErrorAction SilentlyContinue
            }
        } else {
            Remove-ItemProperty -Path $regPath -Name $appName -ErrorAction SilentlyContinue
        }

        # Apply time-based if enabled
        if ($script:settings.TimeBased) { Apply-TimeBasedBrightness }

        $settingsWindow.Close()
    })

    $exitAppButton.Add_Click({
        $settingsWindow.Close()
        $script:isExiting = $true
        $script:window.Close()
    })

    $settingsWindow.ShowDialog() | Out-Null
}

# ============================================================
# TIME-BASED BRIGHTNESS
# ============================================================
function Apply-TimeBasedBrightness {
    if (-not $script:settings.TimeBased) { return }

    # Grace period - don't auto-change brightness right after startup
    $elapsed = ((Get-Date) - $script:startupTime).TotalSeconds
    if ($elapsed -lt $script:settings.StartupGracePeriod) { return }

    $hour = (Get-Date).Hour
    if ($hour -ge $script:settings.DayStartHour -and $hour -lt $script:settings.NightStartHour) {
        Set-MonitorBrightness -Brightness $script:settings.DayBrightness -All
    } else {
        Set-MonitorBrightness -Brightness $script:settings.NightBrightness -All
    }

    # Update sliders if window exists
    if ($null -ne $script:window -and $script:window.IsLoaded) {
        $idx = 0
        foreach ($m in $script:monitors) {
            if ($m.SupportsBrightness) {
                $s = $script:window.FindName("MonSlider_$idx")
                $l = $script:window.FindName("MonLabel_$idx")
                if ($null -ne $s) { $s.Value = $m.CurrentBrightness }
                if ($null -ne $l) { $l.Text = "$($m.CurrentBrightness)%" }
                $idx++
            }
        }
    }
    Update-TrayIcon
}

# ============================================================
# IDLE DETECTION (using GetLastInputInfo)
# ============================================================
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class IdleDetector {
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    public static uint GetIdleTimeMs() {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (GetLastInputInfo(ref lii)) {
            return (uint)Environment.TickCount - lii.dwTime;
        }
        return 0;
    }
}
"@

$script:wasIdle = $false
$script:preDimBrightness = @{}

function Check-IdleState {
    if (-not $script:settings.IdleDim) { return }

    $idleMs = [IdleDetector]::GetIdleTimeMs()
    $idleMinutes = $idleMs / 60000.0

    if ($idleMinutes -ge $script:settings.IdleDimMinutes -and -not $script:wasIdle) {
        # Save current brightness and dim
        $script:wasIdle = $true
        $script:preDimBrightness = @{}
        $idx = 0
        foreach ($m in $script:monitors) {
            if ($m.SupportsBrightness) {
                $script:preDimBrightness[$idx] = $m.CurrentBrightness
                $idx++
            }
        }
        Set-MonitorBrightness -Brightness $script:settings.IdleDimBrightness -All
        Update-TrayIcon
    } elseif ($idleMinutes -lt $script:settings.IdleDimMinutes -and $script:wasIdle) {
        # Restore brightness
        $script:wasIdle = $false
        $idx = 0
        foreach ($m in $script:monitors) {
            if ($m.SupportsBrightness) {
                $restoreVal = if ($script:preDimBrightness.ContainsKey($idx)) { 
                    $script:preDimBrightness[$idx] 
                } else { 50 }
                Set-SingleMonitorBrightness -Monitor $m -Brightness $restoreVal
                $idx++
            }
        }
        Update-TrayIcon
    }
}

# ============================================================
# COMMAND LINE ARGUMENT HANDLING
# ============================================================
function Process-CommandLineArgs {
    $args = [Environment]::GetCommandLineArgs()

    $monitorNum = -1
    $monitorID = ""
    $selectAll = $false
    $setBrightness = -1
    $offsetBrightness = $null
    $vcpCode = -1
    $vcpValue = -1
    $showOverlay = $false
    $showPanel = $false
    $listMonitors = $false

    foreach ($arg in $args) {
        if ($arg -match "^--List$") { $listMonitors = $true }
        if ($arg -match "^--MonitorNum=(\d+)$") { $monitorNum = [int]$Matches[1] - 1 }
        if ($arg -match "^--MonitorID=`"?(.+?)`"?$") { $monitorID = $Matches[1] }
        if ($arg -match "^--All$") { $selectAll = $true }
        if ($arg -match "^--Set=(\d+)$") { $setBrightness = [int]$Matches[1] }
        if ($arg -match "^--Offset=(-?\d+)$") { $offsetBrightness = [int]$Matches[1] }
        if ($arg -match "^--Overlay$") { $showOverlay = $true }
        if ($arg -match "^--Panel$") { $showPanel = $true }
        if ($arg -match "^--VCP=`"?(0?x?[0-9a-fA-F]+):(\d+)`"?$") {
            $codeStr = $Matches[1]
            if ($codeStr -match "^0x") {
                $vcpCode = [Convert]::ToInt32($codeStr, 16)
            } else {
                $vcpCode = [int]$codeStr
            }
            $vcpValue = [int]$Matches[2]
        }
    }

    if ($listMonitors) {
        Write-Host "`nDetected Displays:"
        Write-Host "==================" 
        $idx = 1
        foreach ($m in $script:monitors) {
            $status = if ($m.SupportsBrightness) { "OK" } else { "No DDC/CI" }
            Write-Host "  $idx. $($m.Name) [$($m.MonitorID)] - Brightness: $($m.CurrentBrightness)% ($status)"
            $idx++
        }
        Write-Host ""
        return $true  # handled
    }

    # Find target by ID
    if ($monitorID -ne "") {
        for ($i = 0; $i -lt $script:monitors.Count; $i++) {
            if ($script:monitors[$i].MonitorID -like "*$monitorID*") {
                $monitorNum = $i
                break
            }
        }
    }

    # Apply brightness
    if ($setBrightness -ge 0) {
        if ($selectAll) {
            Set-MonitorBrightness -Brightness $setBrightness -All
        } elseif ($monitorNum -ge 0) {
            Set-MonitorBrightness -MonitorIndex $monitorNum -Brightness $setBrightness
        }
    }

    if ($null -ne $offsetBrightness) {
        if ($selectAll) {
            Offset-MonitorBrightness -Offset $offsetBrightness -All
        } elseif ($monitorNum -ge 0) {
            Offset-MonitorBrightness -MonitorIndex $monitorNum -Offset $offsetBrightness
        }
    }

    # VCP
    if ($vcpCode -ge 0 -and $vcpValue -ge 0 -and $monitorNum -ge 0) {
        Send-VCPCode -MonitorIndex $monitorNum -VCPCode ([byte]$vcpCode) -Value ([uint32]$vcpValue)
    }

    return $false
}

# Process command line
$cmdHandled = Process-CommandLineArgs

# ============================================================
# BUILD AND RUN
# ============================================================
Build-MainWindow
Update-TrayIcon

# System tray click handler
$script:notifyIcon.Add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        if ($null -ne $script:window) {
            if ($script:window.IsVisible) {
                $script:window.Hide()
            } else {
                Position-WindowAtTray
                $script:window.Show()
                $script:window.Activate()
            }
        }
    }
})

# Context menu for tray icon
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$menuShow = New-Object System.Windows.Forms.ToolStripMenuItem("Adjust Brightness")
$menuShow.Add_Click({
    if ($null -ne $script:window) {
        Position-WindowAtTray
        $script:window.Show()
        $script:window.Activate()
    }
})

$menuRefresh = New-Object System.Windows.Forms.ToolStripMenuItem("Refresh Displays")
$menuRefresh.Add_Click({
    Refresh-Monitors
    Update-TrayIcon
    $script:window.Hide()
    Build-MainWindow
})

$menuSettings = New-Object System.Windows.Forms.ToolStripMenuItem("Settings")
$menuSettings.Add_Click({ Show-SettingsWindow })

$menuSep = New-Object System.Windows.Forms.ToolStripSeparator

# Quick brightness submenu
$menuQuick = New-Object System.Windows.Forms.ToolStripMenuItem("Quick Set All")
@(0, 25, 50, 75, 100) | ForEach-Object {
    $val = $_
    $item = New-Object System.Windows.Forms.ToolStripMenuItem("$val%")
    $item.Add_Click({
        Set-MonitorBrightness -Brightness $val -All
        Update-TrayIcon
    }.GetNewClosure())
    $menuQuick.DropDownItems.Add($item) | Out-Null
}

$menuSep2 = New-Object System.Windows.Forms.ToolStripSeparator

$menuExit = New-Object System.Windows.Forms.ToolStripMenuItem("Quit")
$menuExit.Add_Click({
    $script:isExiting = $true
    if ($null -ne $script:window) { $script:window.Close() }
})

$contextMenu.Items.Add($menuShow) | Out-Null
$contextMenu.Items.Add($menuRefresh) | Out-Null
$contextMenu.Items.Add($menuSettings) | Out-Null
$contextMenu.Items.Add($menuSep) | Out-Null
$contextMenu.Items.Add($menuQuick) | Out-Null
$contextMenu.Items.Add($menuSep2) | Out-Null
$contextMenu.Items.Add($menuExit) | Out-Null

$script:notifyIcon.ContextMenuStrip = $contextMenu

# ============================================================
# TIMERS - Time-based brightness & idle detection
# ============================================================
$script:timeCheckTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:timeCheckTimer.Interval = [TimeSpan]::FromMinutes(1)
$script:timeCheckTimer.Add_Tick({
    Apply-TimeBasedBrightness
    Check-IdleState
})
$script:timeCheckTimer.Start()

# Initial time-based application (after grace period)
if ($script:settings.TimeBased) {
    $graceTimer = New-Object System.Windows.Threading.DispatcherTimer
    $graceTimer.Interval = [TimeSpan]::FromSeconds($script:settings.StartupGracePeriod + 1)
    $graceTimer.Add_Tick({
        $graceTimer.Stop()
        Apply-TimeBasedBrightness
    })
    $graceTimer.Start()
}

# ============================================================
# RUN APPLICATION
# ============================================================
$app = New-Object System.Windows.Application
$app.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown

# Show window on first run (or hide if started minimized)
if ($script:settings.StartMinimized -or $cmdHandled) {
    $script:window.Hide()
} else {
    Position-WindowAtTray
    $script:window.Show()
}

$script:window.Add_Closed({
    $script:timeCheckTimer.Stop()
    $app.Shutdown()
})

$app.Run() | Out-Null
