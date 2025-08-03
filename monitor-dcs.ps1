# PowerShell script to monitor and manage a DCS World Server by CourtesyFlushGH
param(
    # Paths to DCS Server and its components
    [string]$MainPath = "C:\DCS World",
    [string]$DCSPath = "$MainPath\DCS World Server",
    [string]$UpdaterPath = "$DCSPath\bin\DCS_updater.exe",
    [string]$LogPath = "$MainPath\Logs\monitor-dcs.log",

    # How often to check the server
    [int]$CheckInterval = 60, # Seconds
    [bool]$RealtimeUpdate = $false, # If true, gives a countdown for server checks in the console

    # Restart options
    [bool]$restartDCS = $true,
    [bool]$restartDaily = $true, # Only $restartDaily or $restartWeekly can be true, not both
    [bool]$restartWeekly = $false,
    [string]$restartDay = "Monday", # Only applicable if $restartWeekly is true
    [string]$restartTime = "02:00", # HH:mm format

    # Update options, will immediately update DCS if an update is detected
    [bool]$Update = $true,

    # Process names, in case Eagle Dynamics changes them
    [string]$ServerProcess = "DCS_server",
    [string]$UpdaterProcess = "DCS_updater"
)

###############################################################
# Do not edit below this line unless you know what you're doing
###############################################################

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

function Start-DCS {
    $dcs = Get-DCSProcess
    if (-not $dcs) {
        Write-Log "Starting DCS Server..."
        Start-Process -FilePath $UpdaterPath -ArgumentList "--quiet" -PassThru
    } else {
        Write-Log "DCS Server is already running."
    }
}

function Test-DCS {
    $dcs = Get-DCSProcess
    if (-not $dcs) {
        Write-Log "DCS Server is not running."
        Start-DCS
    }
}

$webversion = $null
function Get-Version {
    $DCSVersion = 'https://www.digitalcombatsimulator.com/en/news/changelog/release/.*'
    

    $scrape = (Invoke-WebRequest -Uri "https://updates.digitalcombatsimulator.com/" -UseBasicParsing).Links.Href | Get-Unique

    $allmatches = ($scrape | Select-String $DCSVersion -AllMatches).Matches
    ForEach-Object -InputObject $allmatches {
        $webversion = ($_.Value | Select-String -Pattern '(\d+\.\d+\.\d+\.\d+)').Matches.Groups[1].Value
    }
    if (-not (Test-Path -Path "$MainPath\scripts\version.txt" -ErrorAction SilentlyContinue)) {
        New-Item -Path "$MainPath\scripts\version.txt" -ItemType File -Force
        Set-Content -Path "$MainPath\scripts\version.txt" -Value $webversion -Force
    }
    $current = Get-Content -Path "$MainPath\scripts\version.txt" -ErrorAction SilentlyContinue
    if ($webversion -eq $current) {
        return
    } else {
        Write-Log "DCS Version is outdated. Current: $current, Web: $webversion" -Level "WARNING"
        Stop-DCS
        Start-Sleep -Seconds 5
        Start-DCS
        Set-Content -Path "$MainPath\scripts\version.txt" -Value $webversion -Force
        return
    }
}

function Test-Time {
    try {
        $time = [datetime]::ParseExact($restartTime,"HH:mm",$null)
        $now = Get-Date
        $minutes = ($CheckInterval / 60) * 2
        $restartLow = $time.AddMinutes(-$minutes)
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
            return $today.AddDays($daysUntilTarget)
        } elseif ($restartDaily) {
            if ((Get-Date) -gt $today) {
                return $today.AddDays(1)
            } else {
                return $today
            }
        }
    } catch {
        return "Invalid time format"
    }
}

$lastRestart = "Never"
$loop = $true
while ($loop) {
    $restarts = 0
    if ($restartDCS) {
        if ($restartWeekly) {
            $day = Test-Day
            $time = Test-Time
            if ($day -and $time) {
                Stop-DCS
                Start-Sleep -Seconds 5
                Start-DCS
                $lastRestart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $restarts++
            }
        } elseif ($restartDaily) {
            if (Test-Time) {
                Stop-DCS
                Start-Sleep -Seconds 5
                Start-DCS
                $lastRestart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $restarts++
            }
        }
    }

    if ($Update -and $restarts -eq 0) {
        Get-Version
    }

    Test-DCS

    $nextRestart = if ($restartDCS) { Get-NextRestartTime } else { "Disabled" }
    $version = Get-Content -Path "$MainPath\scripts\version.txt" -ErrorAction SilentlyContinue
    if ($RealtimeUpdate) {
        $seconds = $CheckInterval
        while ($seconds -gt 0) {
            Clear-Host
            Write-Host "#####################################################"
            Write-Host ""
            Write-Host "        DCS Server Monitor by CourtesyFlushGH"
            Write-Host ""
            Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # #"
            Write-Host ""
            Write-Host "              DCS Version: $version"
            Write-Host "                  Update set to $Update"
            Write-Host ""
            Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # #"
            Write-Host ""
            Write-Host "          Next restart: $nextRestart"
            Write-Host "          Last restart: $lastRestart"
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
        Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # #"
        Write-Host ""
        Write-Host "              DCS Version: $version"
        Write-Host "                  Update set to $Update"
        Write-Host ""
        Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # #"
        Write-Host ""
        Write-Host "          Next restart: $nextRestart"
        Write-Host "          Last restart: $lastRestart"
        Write-Host ""
        Write-Host "#####################################################"

        Start-Sleep -Seconds $CheckInterval
    }
    
}
