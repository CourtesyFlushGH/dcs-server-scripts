# DCS Server Scripts

PowerShell scripts I use for my DCS World server.

## Monitor DCS script V1.0

Download and either start with Task Scheduler or right-click and Run With Powershell (might need to be run with Admin).

Before running, edit the script parameters to your preference and system.

Script does the following:
- process check to ensure server is running
- (optional) server restarting according to specific time and/or day of the week
- (optional) automatic updating when a new version is released
- (optional) MissionScripting.lua modification for dynamic campaign support
- (optional) SRS server process check


## Install DCS script (WIP)

Use to pull the latest DCS server installer from the eagle dynamics website and run it. Optionally opens [WinUtil](https://github.com/ChrisTitusTech/winutil) to install 7-zip, notepad++, and dotnet.

Open PowerShell as Administrator and run the following:

```iwr https://raw.githubusercontent.com/CourtesyFlushGH/dcs-server-scripts/main/install-dcs.ps1 | iex```

Or download the script and run with powershell admin.

Go through the install GUIs.

In WinUtil the proper packages should be selected, press `Install/Upgrade Applications`. Exit the WinUtil GUI when the installs are finished to continue the script.

Default install location is `C:\DCS World\DCS World Server`, which you will need to paste into the installer.

## Install SRS script (WIP)

Use to pull the latest SRS installer from GitHub and run it. It will also open [WinUtil](https://github.com/ChrisTitusTech/winutil) to install dotnet dependencies.

Open PowerShell as Administrator and run the following:

```iwr https://raw.githubusercontent.com/CourtesyFlushGH/dcs-server-scripts/main/install-srs.ps1 | iex```

Or download the script and run with powershell admin.

Go through the install GUIs.

In WinUtil the proper packages should be selected, press `Install/Upgrade Applications`. Exit the WinUtil GUI when the installs are finished to continue the script.


