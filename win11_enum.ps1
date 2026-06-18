# =========================
# Windows 11 System Enum Tool
# Modular + Interactive
# =========================

$choices = @(
    "All",
    "Network Info",
    "Storage Info",
    "Installed Apps",
    "Security Check",
    "Processes",
    "Services"
)

$selected = $choices | Out-GridView -Title "Select Modules to Run" -PassThru

if (-not $selected) {
    Write-Host "No selection made. Exiting..." -ForegroundColor Yellow
    return
}

# Handle "All"
if ($selected -contains "All") {
    $selected = $choices | Where-Object { $_ -ne "All" }
}

$Report = [ordered]@{}

# =========================
# OS + Device (always included)
# =========================
$OS = Get-CimInstance Win32_OperatingSystem
$CS = Get-CimInstance Win32_ComputerSystem

$Report.System = [ordered]@{
    OS_Name    = $OS.Caption
    Version    = $OS.Version
    Build      = $OS.BuildNumber
    Uptime     = (Get-Date) - $OS.LastBootUpTime
    DeviceName = $CS.Name
    Manufacturer = $CS.Manufacturer
    Model      = $CS.Model
    RAM_GB     = [math]::Round($CS.TotalPhysicalMemory / 1GB, 2)
}

# =========================
# NETWORK
# =========================
if ($selected -contains "Network Info") {

    $Report.Network = Get-CimInstance Win32_NetworkAdapterConfiguration |
        Where-Object { $_.IPEnabled } |
        Select-Object @{
            Name = "Description"; Expression = {$_.Description}
        }, IPAddress, MACAddress, DHCPEnabled
}

# =========================
# STORAGE
# =========================
if ($selected -contains "Storage Info") {

    $Report.Storage = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        ForEach-Object {
            [ordered]@{
                Drive    = $_.DeviceID
                Size_GB  = [math]::Round($_.Size / 1GB, 2)
                Free_GB  = [math]::Round($_.FreeSpace / 1GB, 2)
                Free_Pct = if ($_.Size) {
                    [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
                } else { 0 }
            }
        }
}

# =========================
# APPS
# =========================
if ($selected -contains "Installed Apps") {

    $Report.Appx = Get-AppxPackage |
        Select-Object Name, Version, Publisher |
        Sort-Object Name

    $Report.LegacyApps = Get-ItemProperty `
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" ,
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object DisplayName |
        Select-Object DisplayName, DisplayVersion, Publisher |
        Sort-Object DisplayName
}

# =========================
# SECURITY
# =========================
if ($selected -contains "Security Check") {

    $Report.Security = [ordered]@{
        Defender = Get-MpComputerStatus |
            Select-Object AMServiceEnabled, RealTimeProtectionEnabled, AntivirusEnabled

        LocalAdmins = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue |
            Select-Object Name, ObjectClass
    }
}

# =========================
# PROCESSES
# =========================
if ($selected -contains "Processes") {

    $Report.TopProcesses = Get-Process |
        Sort-Object CPU -Descending |
        Select-Object -First 10 Name, Id, CPU, WorkingSet
}

# =========================
# SERVICES
# =========================
if ($selected -contains "Services") {

    $Report.Services = Get-Service |
        Where-Object Status -eq "Running" |
        Select-Object Name, DisplayName
}

# =========================
# OUTPUT
# =========================
$Report | ConvertTo-Json -Depth 6
