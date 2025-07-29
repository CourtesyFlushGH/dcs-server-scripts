# DCS Server Scripts

WIP

PowerShell scripts I use for my DCS World server.

## Install DCS script

Open PowerShell as Administrator and run the following:

```iwr https://raw.githubusercontent.com/CourtesyFlushGH/dcs-server-scripts/main/install-dcs.ps1 | iex```

Or download the script and run with powershell admin.

Go through the install GUIs.

In WinUtil the proper packages should be selected, press `Install/Upgrade Applications`. Exit the WinUtil GUI when the installs are finished to continue the script.

Default install location is `C:\DCS World\DCS World Server`, which you will need to paste into the installer.

## Install SRS script

Open PowerShell as Administrator and run the following:

```iwr https://raw.githubusercontent.com/CourtesyFlushGH/dcs-server-scripts/main/install-srs.ps1 | iex```

Or download the script and run with powershell admin.

Go through the install GUIs.

In WinUtil the proper packages should be selected, press `Install/Upgrade Applications`. Exit the WinUtil GUI when the installs are finished to continue the script.

## Test DCS script

Download and use with Windows Task Scheduler:

[Guide for setting up Task Scheduler PowerShell scripts](https://o365reports.com/2019/08/02/schedule-powershell-script-task-scheduler/)

![Test-DCS-Task-General](/images/test-dcs-task-general.png)

![Test-DCS-Task-Trigger](/images/test-dcs-task-trigger.png)

![Test-DCS-Task-Action](/images/test-dcs-task-action.png)

For `Add arguments (optional):` add `-File "C:\DCS World\test-dcs.ps1"` or the path to wherever you put the script.