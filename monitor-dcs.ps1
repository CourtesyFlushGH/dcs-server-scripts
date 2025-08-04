###################################
#       Monitor DCS Script        #
#       by CourtesyFlushGH        #
#          Version: 1.0           #
###################################

##############################################
# Edit the parameters below to suit your needs
##############################################

param(
    # Paths to DCS Server and its components
    [string]$DCSPath = "C:\DCS World\DCS World Server", # Change this to your DCS Server main folder path
    [string]$UpdaterPath = "$DCSPath\bin\DCS_updater.exe", # You probably don't need to change this
    [string]$LogPath = "C:\DCS World\Logs\monitor-dcs.log", # Change this to your desired log file path

    # How often to check the server
    [int]$CheckInterval = 60, # Seconds
    [bool]$RealtimeUpdate = $false, # If true, gives a countdown for server checks in the console

    # Restart options
    [bool]$restartDCS = $true, # If true, will restart DCS Server if the restart conditions are met
    [bool]$restartDaily = $true, # Only $restartDaily or $restartWeekly can be true, not both
    [bool]$restartWeekly = $false,
    [string]$restartDay = "Monday", # Only applicable if $restartWeekly is true
    [string]$restartTime = "02:00", # HH:mm format, local(machine) time

    # Dynamic campaign support
    [bool]$DynamicCampaign = $true, # If true, will edit the MissionScripting.lua to enable dynamic campaigns

    # Update options, will immediately update DCS if an update is detected
    [bool]$Update = $true,

    # SRS options
    [bool]$CheckSRS = $true, # If true, will check if SRS is running and restart it if not
    [string]$SRSPath = "C:\DCS World\DCS-SimpleRadio-Standalone\Server\SRS-Server.exe", # Change this to your SRS Server executable path
    [string]$SRSProcess = "SRS-Server", # Process name for SRS Server, you probably don't need to change this

    # Schrodinger's variables, if you look at them ED might change them
    # Generally recommended to leave these alone
    [string]$ServerProcess = "DCS_server",
    [string]$UpdaterProcess = "DCS_updater"
)

# MissionScripting.lua content for dynamic campaigns
# Works as is for dynamic campaigns, but edit for your specific needs if necessary
$MissionScriptDynamic = @"
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

###############################################################
# Do not edit below this line unless you know what you're doing
###############################################################

# Default MissionScripting.lua for reference
# $MissionScriptVanilla = @"
# --Initialization script for the Mission lua Environment (SSE)

# dofile('Scripts/ScriptingSystem.lua')

# --Sanitize Mission Scripting environment
# --This makes unavailable some unsecure functions. 
# --Mission downloaded from server to client may contain potentialy harmful lua code that may use these functions.
# --You can remove the code below and make availble these functions at your own risk.

# local function sanitizeModule(name)
# 	_G[name] = nil
# 	package.loaded[name] = nil
# end

# do
# 	sanitizeModule('os')
# 	sanitizeModule('io')
# 	sanitizeModule('lfs')
# 	_G['require'] = nil
# 	_G['loadlib'] = nil
# 	_G['package'] = nil
# end
# "@

# Log function
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

# Check if DCS is running
function Get-DCSProcess {
    $processes = Get-Process -ErrorAction SilentlyContinue
    $process = $processes | Where-Object { $_.ProcessName -eq $ServerProcess -or $_.ProcessName -eq $UpdaterProcess }
    if ($process.ProcessName -eq $ServerProcess -or $process.ProcessName -eq $UpdaterProcess) {
        return $true
    } else {
        return $false
    }
}

# Stop DCS Server process
function Stop-DCS {
    $dcs = Get-DCSProcess
    if ($dcs) {
        Write-Log "Stopping DCS Server..."
        Stop-Process -Name $ServerProcess -Force -ErrorAction SilentlyContinue
        Write-Log "DCS Server stopped."
    } else {
        Write-Log "DCS Server is not running."
    }
}

# Start DCS Server process
function Start-DCS {
    $dcs = Get-DCSProcess
    if (-not $dcs) {
        Write-Log "Starting DCS Server..."
        Start-Process -FilePath $UpdaterPath -ArgumentList "--quiet" -PassThru
    } else {
        Write-Log "DCS Server is already running."
    }
}

# Set the MissionScripting.lua for dynamic campaigns
function Set-MissionScript {
    $updater = Get-Process -Name $UpdaterProcess -ErrorAction SilentlyContinue
    $server = Get-Process -Name $ServerProcess -ErrorAction SilentlyContinue
    if ($updater) {
        while ($updater) {
            Start-Sleep -Seconds 3
            $updater = Get-Process -Name $UpdaterProcess -ErrorAction SilentlyContinue
        }
        Stop-DCS
        Start-Sleep -Seconds 5
    } elseif ($server) {
        Stop-DCS
        Start-Sleep -Seconds 5
    }
    Set-Content -Path "$DCSPath\Scripts\MissionScripting.lua" -Value $MissionScriptDynamic -Force
    Write-Log "MissionScripting.lua updated."
    Start-DCS
}

# Function to test if the current time is within the restart window
function Test-Time {
    try {
        $time = [datetime]::ParseExact($restartTime,"HH:mm",$null)
        $now = Get-Date
        $minutes = ($CheckInterval / 60) * 2
        $restartLow = $time.AddMinutes(-$minutes)
        # If the current time is within the restart window, wait until the restart time
        if ($now -gt $restartLow -and $now -lt $time) {
            $secondsLeft = [math]::Round(($time - $now).TotalSeconds)
            $seconds = $secondsLeft
            while ($seconds -gt 0) {
                Clear-Host
                Write-Host "######################################################"
                Write-Host "           Restarting Server in $seconds seconds"
                Write-Host "######################################################"
                Start-Sleep -Seconds 1
                $seconds--
            }
            return $true
        }
    } catch {
        Write-Log "Invalid time format: $restartTime" -Level "ERROR"
        return $false
    }
}

# Function to test if today is the restart day
function Test-Day {
    return ((Get-Date).DayOfWeek.ToString() -eq $restartDay)
}

# Function to get next restart time
function Get-NextRestartTime {
    try {
        $time = [datetime]::ParseExact($restartTime,"HH:mm",$null)
        $today = Get-Date -Hour $time.Hour -Minute $time.Minute -Second 0 -Millisecond 0
        
        if ($restartWeekly) {
            $targetDay = [System.DayOfWeek]::$restartDay
            $daysUntilTarget = ($targetDay - (Get-Date).DayOfWeek + 7) % 7
            if ($daysUntilTarget -eq 0 -and (Get-Date) -gt $today) {
                $daysUntilTarget = 7
            }
            return ($today.AddDays($daysUntilTarget)).ToString("yyyy-MM-dd HH:mm:ss")
        } elseif ($restartDaily) {
            if ((Get-Date) -gt $today) {
                return ($today.AddDays(1)).ToString("yyyy-MM-dd HH:mm:ss")
            } else {
                return $today.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    } catch {
        return "Invalid time format"
    }
}

# Restart loop so I don't have to write it multiple times cause I'm lazy
function Restart-DCS {
    Stop-DCS
    Start-Sleep -Seconds 5
    Start-DCS
    if ($DynamicCampaign) {
        Set-MissionScript
    }
}

# Initialize variables
$lastRestart = "Never"

# Main loop
$loop = $true
while ($loop) {
    try {
        # Instantiate restarts variable to avoid issues with multiple restarts in the same loop
        $restarts = 0

        # Check if we need to restart DCS
        if ($restartDCS) {
            if ($restartWeekly) {
                $day = Test-Day
                $time = Test-Time
                if ($day -and $time) {
                    Restart-DCS
                    $lastRestart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $restarts++
                }
            } elseif ($restartDaily) {
                if (Test-Time) {
                    Restart-DCS
                    $lastRestart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $restarts++
                }
            }
        }

        # Pull current DCS version from autoupdate.cfg
        $version = @(Get-Content -Path "$DCSPath\autoupdate.cfg" | Select-String -Pattern '(\d+\.\d+\.\d+\.\d+)' -AllMatches).Matches[0].Groups[1].Value
        
        # Check for updates
        if ($Update -and $restarts -eq 0) {
            $webversion = @((Invoke-WebRequest -Uri "https://updates.digitalcombatsimulator.com/" -UseBasicParsing).Links.Href | Select-String -Pattern '(\d+\.\d+\.\d+\.\d+)' -AllMatches).Matches[0].Groups[1].Value
            if (-not ($webversion -eq $version)) {
                Write-Log "DCS Version is outdated. Current: $version, Web: $webversion" -Level "WARNING"
                Restart-DCS
            }
        }

        # Main DCS process check
        $dcs = Get-DCSProcess
        if (-not $dcs) {
            Write-Log "DCS Server is not running."
            Start-DCS
            if ($DynamicCampaign) {
                Set-MissionScript
            }
        }

        # If CheckSRS is true, check if SRS is running
        if ($CheckSRS) {
            $srs = Get-Process -Name $SRSProcess -ErrorAction SilentlyContinue
            if (-not $srs) {
                Write-Log "SRS is not running, starting SRS Server."
                Start-Process -FilePath $SRSPath
            }
        }

        # Terminal output stuff
        if ($restartDCS) {
            $nextRestart = Get-NextRestartTime
        }
        if ($RealtimeUpdate) {
            $seconds = $CheckInterval
            while ($seconds -gt 0) {
                Clear-Host
                Write-Host "#####################################################"
                Write-Host ""
                Write-Host "        DCS Server Monitor by CourtesyFlushGH"
                Write-Host ""
                Write-Host "              DCS Version: $version"
                Write-Host ""
                if ($restartDCS) {
                    Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # #"
                    Write-Host ""
                    Write-Host "          Next restart: $nextRestart"
                    Write-Host "          Last restart: $lastRestart"
                    Write-Host ""
                }
                Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # #"
                Write-Host ""
                Write-Host "                Auto update DCS: $Update"
                if ($CheckSRS) {
                    Write-Host "                   Check SRS: $CheckSRS"
                }
                Write-Host ""
                Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # #"
                Write-Host ""
                Write-Host "              Next check in $seconds seconds"
                Write-Host ""
                Write-Host "#####################################################"
                Start-Sleep -Seconds 1
                $seconds--
            }
        } else {
            Clear-Host
            Write-Host "#####################################################"
            Write-Host ""
            Write-Host "        DCS Server Monitor by CourtesyFlushGH"
            Write-Host ""
            Write-Host "              DCS Version: $version"
            Write-Host ""
            if ($restartDCS) {
                Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # #"
                Write-Host ""
                Write-Host "          Next restart: $nextRestart"
                Write-Host "          Last restart: $lastRestart"
                Write-Host ""
            }
            Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # #"
            Write-Host ""
            Write-Host "                Auto update DCS: $Update"
            if ($CheckSRS) {
                Write-Host "                   Check SRS: $CheckSRS"
            }
            Write-Host ""
            Write-Host "#####################################################"

            Start-Sleep -Seconds $CheckInterval
        }
    } catch {
        Write-Log "An error occurred: $_" -Level "ERROR"
    }
}
