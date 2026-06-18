# =========================
# Windows 11 System Enum
# =========================

$Report = [ordered]@{}

# --- OS + Build ---
$OS = Get-CimInstance Win32_OperatingSystem

$Report.OS = [ordered]@{
    Name        = $OS.Caption
    Version     = $OS.Version
    Build       = $OS.BuildNumber
    InstallDate = $OS.InstallDate
    Uptime      = (Get-Date) - $OS.LastBootUpTime
}

# --- Device Info ---
$Computer = Get-CimInstance Win32_ComputerSystem

$Report.Device = [ordered]@{
    Name   = $Computer.Name
    Model  = $Computer.Model
    Vendor = $Computer.Manufacturer
    RAM_GB = [math]::Round($Computer.TotalPhysicalMemory / 1GB, 2)
}

# --- CPU ---
$CPU = Get-CimInstance Win32_Processor

$Report.CPU = [ordered]@{
    Name     = $CPU.Name
    Cores    = $CPU.NumberOfCores
    Threads  = $CPU.NumberOfLogicalProcessors
    MaxClock = $CPU.MaxClockSpeed
}

# --- Storage (fixed drives only) ---
$Drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

$Report.Storage = $Drives | ForEach-Object {
    [ordered]@{
        Drive   = $_.DeviceID
        SizeGB  = [math]::Round($_.Size / 1GB, 2)
        FreeGB  = [math]::Round($_.FreeSpace / 1GB, 2)
        FreePct = if ($_.Size) {
            [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
        } else { 0 }
    }
}

# --- Network ---
$Adapters = Get-CimInstance Win32_NetworkAdapterConfiguration |
    Where-Object { $_.IPEnabled }

$Report.Network = $Adapters | ForEach-Object {
    [ordered]@{
        Name        = $_.Description
        IP          = $_.IPAddress
        MAC         = $_.MACAddress
        DHCP        = $_.DHCPEnabled
    }
}

# --- Installed Apps (Windows 11 style) ---
$Report.Apps = Get-AppxPackage |
    Select-Object Name, Version, Publisher |
    Sort-Object Name

# --- Optional: classic installed programs (registry uninstall list) ---
$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$Report.LegacyApps = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue |
    Where-Object DisplayName |
    Select-Object DisplayName, DisplayVersion, Publisher |
    Sort-Object DisplayName

# --- Running Processes (top CPU) ---
$Report.TopProcesses = Get-Process |
    Sort-Object CPU -Descending |
    Select-Object -First 10 Name, Id, CPU, WorkingSet

# --- Services ---
$Report.Services = Get-Service |
    Where-Object Status -eq "Running" |
    Select-Object Name, DisplayName

# --- Startup (registry-based) ---
$StartupKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
)

$Report.Startup = foreach ($key in $StartupKeys) {
    if (Test-Path $key) {
        Get-ItemProperty $key |
        ForEach-Object {
            $_.PSObject.Properties |
            Where-Object { $_.Name -notlike "PS*" } |
            ForEach-Object {
                [PSCustomObject]@{
                    Location = $key
                    Name     = $_.Name
                    Value    = $_.Value
                }
            }
        }
    }
}

# --- Output ---
$Report | ConvertTo-Json -Depth 5