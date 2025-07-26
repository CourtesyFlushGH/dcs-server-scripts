
param (
    # Main folder path (server folder will go in here)
    [string]$MainPath = "C:\DCS World"   
)

# Write-Log
$LogPath = "C:\Logs\srs-install-script.txt"

# SRS Path
$pathSRS = "$MainPath\DCS-SimpleRadio-Standalone\Server\SRS-Server.exe"

# Firewall rules
Write-Host "Add Windows Firewall rules for '$pathSRS'?" -ForegroundColor Yellow
$firewall = Read-Host "[Y/N]"

# Autoconnect
Write-Host "Set up SRS autoconnect script?" -ForegroundColor Yellow
$autoconnect = Read-Host "[Y/N]"

if ($autoconnect -eq "Y" -or $autoconnect -eq "y") {
    Write-Host "Enter custom IP address for SRS autoconnect?" -ForegroundColor Yellow
    $customIP = Read-Host "[Y/N]"
    if ($customIP -eq "Y" -or $customIP -eq "y") {
        $ip = Read-Host "[IP Address or Domain]"
    }
}

$winUtil = @"
{
    "WPFTweaks":  [

                  ],
    "Install":  [
                    {
                        "winget":  "Microsoft.DotNet.DesktopRuntime.8",
                        "choco":  "dotnet-8.0-runtime"
                    },
                    {
                        "winget":  "Microsoft.DotNet.DesktopRuntime.9",
                        "choco":  "dotnet-9.0-runtime"
                    }
                ],
    "WPFInstall":  [
                       "WPFInstalldotnet8",
                       "WPFInstalldotnet9"
                   ],
    "WPFFeature":  [

                   ]
}
"@

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

function Set-ClipboardWithRetry {
    param (
        [string]$Value
    )
    $Attempts = 0
    $MaxAttempts = 2
    while ($Attempts -lt $MaxAttempts) {
        try {
            Set-Clipboard -Value $Value
            Write-Log "Copied $Value to clipboard (attempt $($Attempts+1))."
            return
        }
        catch {
            $Attempts++
            Write-Log "Clipboard operation failed on attempt $($Attempts): $_" -Level "WARNING"
            Start-Sleep -Milliseconds 500
        }
    }
    Write-Log "All attempts to copy '$Value' to clipboard failed." -Level "ERROR"
    return
}

if (Test-Path $pathSRS) {
    Write-Log "SRS already installed."
    return
}


try {
    New-Item -Path $MainPath\WinUtil.json -ItemType File -Force -Value $winUtil -ErrorAction Stop
    Invoke-Expression "& { $(Invoke-RestMethod https://christitus.com/win) } -Config '$MainPath\WinUtil.json'"

    Write-Log "Starting SRS installation..."

    $releases = "https://api.github.com/repos/ciribob/DCS-SimpleRadioStandalone/releases/latest"
    $releaseObj = Invoke-RestMethod $releases
    $tag = $releaseObj.tag_name
    $download = "https://github.com/ciribob/DCS-SimpleRadioStandalone/releases/download/$tag/SRS-AutoUpdater.exe"
    $srsInstaller = "$MainFolder\SRS-AutoUpdater.exe"

    Invoke-WebRequest $download -OutFile $srsInstaller -ErrorAction Stop

    Set-ClipboardWithRetry "$MainFolder\DCS-SimpleRadio-Standalone"
    Write-Host "SRS installation path copied to clipboard." -ForegroundColor Yellow
    Start-Process -FilePath $srsInstaller -Wait -ErrorAction Stop

    if ($autoconnect -eq "Y" -or $autoconnect -eq "y") {
        try {
            Write-Log "Setting up SRS autoconnect script..."
            if (-not $customIP) {
                $ip = (Invoke-WebRequest ifconfig.me/ip).Content.Trim()
            }
            $filePath = "$MainFolder\DCS-SimpleRadio-Standalone\Scripts\DCS-SRS-AutoConnectGameGUI.lua"
            if (Test-Path $filePath) {
                (Get-Content $filePath) -replace 'SRSAuto.SERVER_SRS_HOST = ".*"', "SRSAuto.SERVER_SRS_HOST = `"$ip`"" | Set-Content $filePath
                $dest = "$env:USERPROFILE\Saved Games\DCS.server_release\Scripts\Hooks"
                Test-Directory $dest
                Copy-Item $filePath -Destination $dest -Force
                Write-Log "SRS autoconnect script configured."
            } else {
                Write-Log "SRS autoconnect source script not found: $filePath" -Level "ERROR"
            }
        } catch {
            Write-Log "SRS autoconnect script setup failed: $_" -Level "ERROR"
        }
    }

    # Add firewall rules
    if ($firewall -eq "Y" -or $firewall -eq "y") {
        Write-Log "Adding firewall rules for SRS..."
        $inName = "SRS Server Inbound"
        $outName = "SRS Server Outbound"
        if (-not (Get-NetFirewallRule -DisplayName $inName -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $inName -Direction Inbound -Program $pathSRS -Action Allow -ErrorAction Stop
            Write-Log "Added $inName firewall rule."
        } else {
            Write-Log "$inName firewall rule already exists."
        }
        if (-not (Get-NetFirewallRule -DisplayName $outName -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $outName -Direction Outbound -Program $pathSRS -Action Allow -ErrorAction Stop
            Write-Log "Added $outName firewall rule."
        } else {
            Write-Log "$outName firewall rule already exists."
        }
    }

    # Clean up
    Write-Log "Cleaning up..."
    Remove-Item -Path $srsInstaller -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$MainPath\WinUtil.json" -Force -ErrorAction SilentlyContinue

    Write-Log "SRS installation completed."
} catch {
    Write-Log "Error during SRS installation: $_"
}