# MEM_EnableWOL

## Overview

PowerShell scripts I used to manage (specifically to enable) Wake-on-LAN (WoL) functionality using Microsoft Intune Proactive Remediations, now "Remediations". They were particularly when renovating fleet of new devices.

## Scripts

This repository contains the following scripts:

1. `Detect_WOL.ps1`: Retrieves the Wake-on-Lan (WOL) settings of a Windows device from the UEFI configuration. It checks the manufacturer of the device and attempts to get the WOL state. The script supports Dell, HP, and Lenovo devices. Attempts to install the required module for the manufacturer if it's not already installed. The function also checks the WOL state at OS level for each network interface card (NIC) and returns the WOL state at BIOS and OS level. It reports back findings and actions to the Intune Console, you do need to remember to enable view of the "output" columns in the Remediations devices report.

2. `Fix_WOL.ps1`: This script updates the Wake-on-Lan (WOL) settings of a Windows device from the UEFI configuration. It checks the manufacturer of the device and attempts to set the WOL state. The script supports Dell, HP, and Lenovo devices. It attempts to install the required module for the manufacturer if it's not already installed.

## Usage

To use these scripts, clone the repository to your local machine or download the individual .ps1 files. Run each script in a PowerShell environment with appropriate administrative privileges.

For usage via Microsoft Intune's Remediations feature, follow these steps:

1. Clone or download the scripts from this repository.
2. In the Microsoft Endpoint Manager admin center, select "Devices" and then "Remediations".
3. Click on "+ New remediation" to create a new remediation.
4. In the new remediation, provide a name and description, and upload the PowerShell scripts from this repository. The `Detect_WOL.ps1` script will be used for detection, and the `Fix_WOL.ps1` script will be used for remediation.
5. Assign the remediation to a group of devices in the "Assignments" section of the remediation.
6. Monitor the progress and success of the remediation in the "Overview" section.

## References and Inspiration

The scripts in this repository are based on and inspired by the following resources:

- Kelvin Tegelaar's posts on Reddit and Cyberdrain: 
  - [Reddit Post](https://www.reddit.com/r/msp/comments/fp7dhq/monitoring_with_powershell_monitoring_and)
  - [Cyberdrain Article](https://www.cyberdrain.com/monitoring-with-powershell-monitor-and-enabling-wol-for-hp-lenovo-dell/)
- Additional references:
  - [Changing HP BIOS/UEFI settings with BIOSConfigUtility64.exe](https://learn.microsoft.com/en-us/archive/blogs/jimriekse/changing-hp-biosuefi-settings-with-biosconfigutility64-exe)
  - [HP BCU](http://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html)
  - [PowerShell One](https://powershell.one/code/11.html)
  - [HP Management via PowerShell](https://www.recastsoftware.com/resources/configmgr-docs/configmgr-topics/manufacturer-tools/hp-management-via-powershell/)

## Contributing

Contributions to the MEM_EnableWOL repository are welcome. Please ensure that any pull requests for script additions or changes are thoroughly tested in a MEM environment before submission.

## License

This project is licensed under the MIT License.

