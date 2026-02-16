Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class Monitor {
    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, ref uint pdwNumberOfPhysicalMonitors);
    
    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint dwPhysicalMonitorArraySize, [Out] PHYSICAL_MONITOR[] pPhysicalMonitorArray);
    
    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetMonitorBrightness(IntPtr hMonitor, ref uint pdwMinimumBrightness, ref uint pdwCurrentBrightness, ref uint pdwMaximumBrightness);
    
    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool SetMonitorBrightness(IntPtr hMonitor, uint dwNewBrightness);
    
    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool DestroyPhysicalMonitor(IntPtr hMonitor);
    
    [DllImport("user32.dll")]
    public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumProc lpfnEnum, IntPtr dwData);
    
    public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT lprcMonitor, IntPtr dwData);
    
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct PHYSICAL_MONITOR {
        public IntPtr hPhysicalMonitor;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szPhysicalMonitorDescription;
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    // Collect monitors from C# to avoid PowerShell delegate issues
    private static List<PHYSICAL_MONITOR> _monitors = new List<PHYSICAL_MONITOR>();

    private static bool EnumCallback(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT lprcMonitor, IntPtr dwData) {
        uint numMonitors = 0;
        GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, ref numMonitors);
        if (numMonitors > 0) {
            PHYSICAL_MONITOR[] monitors = new PHYSICAL_MONITOR[numMonitors];
            GetPhysicalMonitorsFromHMONITOR(hMonitor, numMonitors, monitors);
            _monitors.AddRange(monitors);
        }
        return true;
    }

    public static PHYSICAL_MONITOR[] GetAllPhysicalMonitors() {
        _monitors.Clear();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, EnumCallback, IntPtr.Zero);
        return _monitors.ToArray();
    }
}
"@

# Get all physical monitors using the C# helper (avoids delegate issues)
$script:physicalMonitors = [Monitor]::GetAllPhysicalMonitors()

# Function to set brightness
function Set-MonitorBrightness {
    param([int]$Brightness)
    foreach ($monitor in $script:physicalMonitors) {
        [Monitor]::SetMonitorBrightness($monitor.hPhysicalMonitor, [uint32]$Brightness)
    }
}

# Function to get current brightness
function Get-MonitorBrightness {
    if ($script:physicalMonitors.Count -gt 0) {
        [uint32]$min = 0
        [uint32]$current = 0
        [uint32]$max = 0
        $result = [Monitor]::GetMonitorBrightness($script:physicalMonitors[0].hPhysicalMonitor, [ref]$min, [ref]$current, [ref]$max)
        if ($result) { return $current }
    }
    return 50
}

# Create system tray icon
$script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:notifyIcon.Text = "Brightness Control"
$script:notifyIcon.Visible = $true

# Create icon bitmap
$iconBitmap = New-Object System.Drawing.Bitmap(32, 32)
$graphics = [System.Drawing.Graphics]::FromImage($iconBitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)

$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 200, 0))
$graphics.FillEllipse($brush, 8, 8, 16, 16)
$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 255, 200, 0), 2)
$graphics.DrawLine($pen, 16, 2, 16, 6)
$graphics.DrawLine($pen, 16, 26, 16, 30)
$graphics.DrawLine($pen, 2, 16, 6, 16)
$graphics.DrawLine($pen, 26, 16, 30, 16)
$graphics.DrawLine($pen, 6, 6, 9, 9)
$graphics.DrawLine($pen, 23, 23, 26, 26)
$graphics.DrawLine($pen, 6, 26, 9, 23)
$graphics.DrawLine($pen, 23, 9, 26, 6)

$iconHandle = $iconBitmap.GetHicon()
$script:notifyIcon.Icon = [System.Drawing.Icon]::FromHandle($iconHandle)

$graphics.Dispose()
$brush.Dispose()
$pen.Dispose()

# Create WPF Window - FIXED: removed duplicate PART_Track name and fixed slider template
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Brightness Control" Height="280" Width="380"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        Background="#1e1e1e"
        WindowStyle="None"
        AllowsTransparency="True"
        Topmost="True"
        ShowInTaskbar="False">
    <Window.Effect>
        <DropShadowEffect Color="Black" Direction="0" ShadowDepth="0" Opacity="0.5" BlurRadius="20"/>
    </Window.Effect>
    <Border CornerRadius="12" Background="#1e1e1e" BorderBrush="#3f3f46" BorderThickness="1">
        <Grid Margin="25">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="15"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="25"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="25"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <!-- Title Bar -->
            <Grid Grid.Row="0" Name="TitleBar">
                <TextBlock Text="Brightness Control" 
                           FontSize="18" FontWeight="SemiBold" 
                           Foreground="#e4e4e7" 
                           VerticalAlignment="Center"/>
                <Button Name="CloseButton" Content="X" 
                        HorizontalAlignment="Right"
                        Width="30" Height="30"
                        Background="Transparent"
                        Foreground="#a1a1aa"
                        BorderThickness="0"
                        FontSize="16"
                        Cursor="Hand"/>
            </Grid>
            
            <!-- Big brightness value -->
            <Viewbox Grid.Row="2" Height="80">
                <TextBlock Name="ValueLabel" 
                           Text="50%" 
                           FontWeight="Bold"
                           Foreground="#3b82f6">
                    <TextBlock.Effect>
                        <DropShadowEffect Color="#3b82f6" Direction="0" ShadowDepth="0" Opacity="0.6" BlurRadius="20"/>
                    </TextBlock.Effect>
                </TextBlock>
            </Viewbox>
            
            <!-- Slider -->
            <Grid Grid.Row="4">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                
                <TextBlock Grid.Column="0" Text="Dark" FontSize="14" 
                           Foreground="#a1a1aa"
                           VerticalAlignment="Center" Margin="0,0,12,0" Opacity="0.7"/>
                
                <Slider Grid.Column="1" Name="BrightnessSlider" 
                        Minimum="0" Maximum="100" 
                        TickFrequency="1" 
                        IsSnapToTickEnabled="True"
                        VerticalAlignment="Center"/>
                
                <TextBlock Grid.Column="2" Text="Bright" FontSize="14" 
                           Foreground="#a1a1aa"
                           VerticalAlignment="Center" Margin="12,0,0,0" Opacity="0.7"/>
            </Grid>
            
            <!-- Quick preset buttons -->
            <UniformGrid Grid.Row="6" Columns="4" Rows="1">
                <Button Name="Btn25" Content="25%" Margin="0,0,4,0" 
                        Background="#27272a" Foreground="#a1a1aa" 
                        BorderThickness="0" Height="36" 
                        FontSize="13" Cursor="Hand"/>
                <Button Name="Btn50" Content="50%" Margin="2,0,2,0" 
                        Background="#27272a" Foreground="#a1a1aa" 
                        BorderThickness="0" Height="36" 
                        FontSize="13" Cursor="Hand"/>
                <Button Name="Btn75" Content="75%" Margin="2,0,2,0" 
                        Background="#27272a" Foreground="#a1a1aa" 
                        BorderThickness="0" Height="36" 
                        FontSize="13" Cursor="Hand"/>
                <Button Name="Btn100" Content="100%" Margin="4,0,0,0" 
                        Background="#27272a" Foreground="#a1a1aa" 
                        BorderThickness="0" Height="36" 
                        FontSize="13" Cursor="Hand"/>
            </UniformGrid>
            
            <!-- Exit button -->
            <Button Grid.Row="8" Name="ExitButton" Content="Exit App" 
                    Background="#dc2626" Foreground="White" 
                    BorderThickness="0" Height="38" 
                    FontSize="13" FontWeight="SemiBold"
                    Cursor="Hand" Margin="0,10,0,0"/>
        </Grid>
    </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$script:window = [Windows.Markup.XamlReader]::Load($reader)

if ($null -eq $script:window) {
    Write-Error "Failed to create window from XAML!"
    $script:notifyIcon.Dispose()
    return
}

$slider = $script:window.FindName("BrightnessSlider")
$valueLabel = $script:window.FindName("ValueLabel")
$closeButton = $script:window.FindName("CloseButton")
$exitButton = $script:window.FindName("ExitButton")
$btn25 = $script:window.FindName("Btn25")
$btn50 = $script:window.FindName("Btn50")
$btn75 = $script:window.FindName("Btn75")
$btn100 = $script:window.FindName("Btn100")
$titleBar = $script:window.FindName("TitleBar")

# Allow dragging the window by the title bar
$titleBar.Add_MouseLeftButtonDown({
    $script:window.DragMove()
})

# Set initial value
$currentBrightness = Get-MonitorBrightness
$slider.Value = $currentBrightness
$valueLabel.Text = "$currentBrightness%"
$script:notifyIcon.Text = "Brightness: $currentBrightness%"

# Handle slider changes
$slider.Add_ValueChanged({
    $value = [int]$slider.Value
    $valueLabel.Text = "$value%"
    $script:notifyIcon.Text = "Brightness: $value%"
    Set-MonitorBrightness -Brightness $value
})

# Preset buttons
$btn25.Add_Click({ $slider.Value = 25 })
$btn50.Add_Click({ $slider.Value = 50 })
$btn75.Add_Click({ $slider.Value = 75 })
$btn100.Add_Click({ $slider.Value = 100 })

# Close button - minimize to tray (don't close)
$closeButton.Add_Click({
    $script:window.Hide()
})

# Track whether we're actually exiting
$script:isExiting = $false

# Exit button - actually exit
$exitButton.Add_Click({
    $script:isExiting = $true
    $script:window.Close()
})

# Prevent window from actually closing when X is clicked; only hide it
$script:window.Add_Closing({
    param($s, $e)
    if (-not $script:isExiting) {
        $e.Cancel = $true
        $script:window.Hide()
    }
})

# Tray icon click - show/hide window (use MouseClick to avoid firing on context menu)
$script:notifyIcon.Add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        if ($script:window.IsVisible) {
            $script:window.Hide()
        } else {
            $script:window.Show()
            $script:window.Activate()
        }
    }
})

# Context menu for tray
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$menuItemShow = New-Object System.Windows.Forms.ToolStripMenuItem("Show Brightness Control")
$menuItemExit = New-Object System.Windows.Forms.ToolStripMenuItem("Exit")

$menuItemShow.Add_Click({
    $script:window.Show()
    $script:window.Activate()
})

$menuItemExit.Add_Click({
    $script:isExiting = $true
    $script:window.Close()
})

$contextMenu.Items.Add($menuItemShow) | Out-Null
$contextMenu.Items.Add($menuItemExit) | Out-Null
$script:notifyIcon.ContextMenuStrip = $contextMenu

# Cleanup on closed
$script:window.Add_Closed({
    foreach ($monitor in $script:physicalMonitors) {
        [Monitor]::DestroyPhysicalMonitor($monitor.hPhysicalMonitor)
    }
    $script:notifyIcon.Visible = $false
    $script:notifyIcon.Dispose()
})

# Show the window initially (change to .Hide() if you want it to start in tray)
$script:window.Show()

# Run the application
$app = New-Object System.Windows.Application
$app.ShutdownMode = [System.Windows.ShutdownMode]::OnMainWindowClose
$app.Run($script:window) | Out-Null
