
param (
    # Main folder path (server folder will go in here)
    [string]$MainPath = "C:\DCS World"   
)

# Write-Log
$LogPath = "C:\Logs\dcs-install-script.txt"

# Get-DCSInstaller
$InstallerPath = "$MainPath\server_installer.exe"
$DCSuri = "https://www.digitalcombatsimulator.com/en/downloads/world/server/"
$DCSsite = "https://www.digitalcombatsimulator.com"
$DCSinstaller = ".*/DCS_World_Server_modular.exe"

# Install-DotNET
$dotnetInstallURL = "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/8.0.17/windowsdesktop-runtime-8.0.17-win-x64.exe"

# Install-DCSServer
$ServerFolder = "$MainPath\DCS World Server"
$UpdaterPath = "$ServerFolder\bin\DCS_updater.exe"
$ServerPath = "$ServerFolder\bin\DCS_server.exe"

# MissionScipt.lua Modifiers
$MissionScriptPath = "$ServerFolder\Scripts\MissionScripting.lua"

# User prompts
Write-Host "Add exclusion to Windows Defender for '$MainPath'?" -ForegroundColor Yellow
Write-Host "(Defender sometimes sees DCS_updater as a threat)" -ForegroundColor Yellow
$exclusion = Read-Host "[Y/N]"

Write-Host "Add Windows Firewall rules for '$ServerPath'?" -ForegroundColor Yellow
$firewall = Read-Host "[Y/N]"

Write-Host "Modify MissionScripting.lua to be compatible with dynamic campaigns?" -ForegroundColor Yellow
$dynamic = Read-Host "[Y/N]"

$MissionScriptContent = @"
--Initialization script for the Mission lua Environment (SSE)

dofile('Scripts/ScriptingSystem.lua')

--Sanitize Mission Scripting environment
--This makes unavailable some unsecure functions. 
--Mission downloaded from server to client may contain potentialy harmful lua code that may use these functions.
--You can remove the code below and make availble these functions at your own risk.

local function sanitizeModule(name)
    _G[name] = nil
    package.loaded[name] = nil
end

do
    sanitizeModule('os')
    --sanitizeModule('io')
    --sanitizeModule('lfs')
    _G['require'] = nil
    _G['loadlib'] = nil
    _G['package'] = nil
end
"@


# Functions

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


# Install DotNET

$dotnet = Test-Path "C:\Program Files\dotnet\dotnet.exe"
if ($dotnet) {
    Write-Log ".NET already installed."
}
else {
    Write-Log "Installing .NET dependency..."
    $TempPath = "$env:TEMP\dotnet-install.exe"
    Invoke-WebRequest -Uri $dotnetInstallURL -OutFile $TempPath -ErrorAction Stop
    Start-Process -FilePath $TempPath -ArgumentList "-c" -Wait -NoNewWindow -ErrorAction Stop
    Remove-Item -Path $TempPath -Force
    
    Write-Log ".NET installation complete."
}


# Test main folder path

if (Test-Path $MainPath) {
    Write-Log "Found main folder."
}
else {
    Write-Log "Creating main folder."
    New-Item -Path $MainPath -ItemType Directory -Force
}


# Set exclusion in Windows Defender

if ($exclusion -eq "Y" -or $exclusion -eq "y") {

    $excluded = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath | Where-Object { $_ -eq $MainPath }
    if (-not $excluded) {
        Write-Log "Adding $MainPath to Windows Defender exclusions."
        Add-MpPreference -ExclusionPath $MainPath -ErrorAction Stop
    } else {
        Write-Log "$MainPath is already in Windows Defender exclusions."
    }

}


# Download DCS Server installer

if (Test-Path $InstallerPath) {
    Write-Log "DCS Server installer found at $InstallerPath."
}
elseif (Test-Path $UpdaterPath) {
    Write-Log "DCS_updater found at $UpdaterPath."
}
else {
    $scrape = (Invoke-WebRequest -Uri $DCSuri -UseBasicParsing -ErrorAction Stop).Links.Href | Get-Unique
    $allmatches = ($scrape | Select-String $DCSinstaller -AllMatches).Matches
    
    foreach ($link in $allmatches) {
        if ($link.Value -match $DCSinstaller) {
            $downloader = $link.Value
        }
    }
    Invoke-WebRequest -Uri $DCSsite$downloader -OutFile $InstallerPath -UseBasicParsing -ErrorAction Stop
    if (Test-Path $InstallerPath) {
        Write-Log "DCS Server installer successfully downloaded."
    }
    else {
        Write-Log "DCS Server installer download failed."
        exit
    }
}


# Install DCS server

if ((Test-Path $UpdaterPath) -and (Test-Path $ServerPath)) {
    Write-Log "Server already installed."
}
elseif ((Test-Path $UpdaterPath) -and (-not(Test-Path $ServerPath))) {
    Write-Log "Launching DCS_updater..."
    Start-Process $UpdaterPath -Wait -ErrorAction Stop
}
else {
    Set-ClipboardWithRetry "$ServerFolder"

    Write-Host "COPIED INSTALLATION PATH TO CLIPBOARD" -ForegroundColor Yellow
    Write-Host "PASTE IT INTO THE INSTALLER WHEN NEEDED" -ForegroundColor Yellow
    Write-Host "Copied '$ServerFolder'" -ForegroundColor White
    Start-Sleep -Seconds 1

    Write-Log "Starting DCS Server installer."
    Start-Process $InstallerPath -Wait -ErrorAction Stop
    Start-Sleep -Seconds 3

    $dcs = Get-Process -Name "DCS_updater"
    if (-not($dcs)) {
        $dcs = Start-Process $UpdaterPath -Wait -ErrorAction Stop
    } else {
        Write-Log "DCS_updater is running."
        Write-Log "Waiting for updater to finish..."
        while ($dcs) {Start-Sleep -Milliseconds 500}
    }

    Start-Sleep -Seconds 3
    Write-Log "Killing DCS process."
    Stop-Process -Name "DCS_server" -Force

    if ((Test-Path $ServerPath) -and (Test-Path $UpdaterPath) -and (Test-Path $MissionScriptPath)) {
        Write-Log "DCS Server installed successfully."
    } else {
        Write-Log "DCS not installed, terminating script." -Level "ERROR"
        return
    }

    if ($firewall -eq "Y" -or $firewall -eq "y") {
        try {
            $name = "DCS_server"
            $inName = "$name Inbound"; $outName = "$name Outbound"
            if (-not (Get-NetFirewallRule -DisplayName $inName -ErrorAction SilentlyContinue)) {
                New-NetFirewallRule -DisplayName $inName -Direction Inbound -Program $ServerPath -Action Allow
                Write-Log "Added $inName firewall rule."
            }
            if (-not (Get-NetFirewallRule -DisplayName $outName -ErrorAction SilentlyContinue)) {
                New-NetFirewallRule -DisplayName $outName -Direction Outbound -Program $ServerPath -Action Allow
                Write-Log "Added $outName firewall rule."
            }
        } catch {
            Write-ErrorAndHalt "Unable to add $name to Firewall: $_"
        }
    }

    if ($dynamic -eq "Y" -or $dynamic -eq "y") {
        Set-Content -Path $MissionScriptPath -Value $MissionScriptContent
        Write-Log "MissionScripting.lua modified."
    }
}





