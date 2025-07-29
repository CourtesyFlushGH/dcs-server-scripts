
param (
    # Main folder path (server folder will go in here)
    [string]$MainPath = "C:\DCS World",
    [string]$DCSPath = "$MainPath\DCS World Server",
    [string]$updaterPath = "$DCSPath\bin\DCS_updater.exe",
    [string]$serverPath = "$DCSPath\bin\DCS_Server.exe",
    [string]$LogPath = "C:\Logs\restart-dcs-script.txt"
)

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    if (-not(Test-Path $LogPath)) {
        New-Item $LogPath -ItemType File -Force
    }
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$Timestamp [$Level] - $Message"
    Write-Output $LogMessage
    $LogMessage | Out-File -FilePath $LogPath -Append
}

if (-not $updaterPath -or -not $serverPath) {
    Write-Log "DCS World executables not found, check installation." "ERROR"
    return
}

try {
    $dcs = Get-Process -Name "DCS_server" -ErrorAction SilentlyContinue

    if (-not $dcs) {
        Write-Log "DCS Server not running, starting DCS Server..."

        Start-Process -FilePath $updaterPath -ArgumentList "--quiet" -PassThru -Wait

        Start-Sleep 3

        $dcsStart = Get-Process -Name "DCS_server" -ErrorAction SilentlyContinue

        if (-not $dcsStart) {
            Write-Log "Failed to start DCS Server." -Level "ERROR"
            return
        } else {
            Write-Log "DCS Server started successfully."
        }
    } else {
        Stop-Process -Name "DCS_server" -Force -ErrorAction Stop

        Start-Sleep 5

        Start-Process -FilePath $updaterPath -ArgumentList "--quiet" -PassThru -Wait

        Start-Sleep 3

        $dcsRestart = Get-Process -Name "DCS_server" -ErrorAction SilentlyContinue

        if (-not $dcsRestart) {
            Write-Log "Failed to restart DCS Server." -Level "ERROR"
            return
        } else {
            Write-Log "DCS Server restarted successfully."
        }
    }

} catch {
    Write-Log "Restart error occurred: $_" -Level "ERROR"
}