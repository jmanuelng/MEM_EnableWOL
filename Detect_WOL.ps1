
function Get-WOLSettings {
    <#
    .SYNOPSIS
        Function to retrieve the Wake-on-Lan (WOL) settings of a Windows device from the UEFI configuration.

    .DESCRIPTION
        Function checks the manufacturer of the device and attempts to get the WOL state. Supports Dell, HP, and Lenovo devices.
        Updates PS Gallery, PsGet modules, 
        It attempts to install the required module for the manufacturer if it's not already installed.
        If the manufacturer is Dell, it uses DellBIOSProvider to get the WOL state.
        If the manufacturer is HP, it uses HPCMSL to get the WOL state.
        If the manufacturer is Lenovo, it uses WMI to get the WOL state.
        The function also checks the WOL state at OS level for each network interface card (NIC).
        Returns the WOL state at BIOS and OS level.
        
        The work is based on:
        Kelvin Tegelaar's posts on Reddit and Cyberdrain: 
            https://www.reddit.com/r/msp/comments/fp7dhq/monitoring_with_powershell_monitoring_and
            https://www.cyberdrain.com/monitoring-with-powershell-monitor-and-enabling-wol-for-hp-lenovo-dell/
        
        Additional references:
            https://learn.microsoft.com/en-us/archive/blogs/jimriekse/changing-hp-biosuefi-settings-with-biosconfigutility64-exe
            http://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html
            https://powershell.one/code/11.html
            https://www.recastsoftware.com/resources/configmgr-docs/configmgr-topics/manufacturer-tools/hp-management-via-powershell/


         


    .EXAMPLE
        Get-WOLSettings
        # This will check the Wake-on-Lan settings for the local computer based on its manufacturer.
    #>
    [CmdletBinding()]
    param ()

    $result = 0
    $detectSummary = ""

    # Check and install necessary dependencies
    $PPNuGet = Get-PackageProvider -ListAvailable | Where-Object { $_.Name -eq "Nuget" }
    if (!$PPNuget) {
        Write-Host "Installing Nuget provider" -foregroundcolor Green
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        $detectSummary += "Installed Nuget. "
    }

    $PSGallery = Get-PSRepository -Name PsGallery
    if (!$PSGallery) {
        Write-Host "Installing PSGallery" -foregroundcolor Green
        Set-PSRepository -InstallationPolicy Trusted -Name PSGallery
        $detectSummary += "Installed PsGallery. "
    }

    $PsGetVersion = (get-module PowerShellGet).version
    if ($PsGetVersion -lt [version]'2.0') {
        try {
            # Attempt to install the latest version of PowerShellGet
            Write-Host "Installing latest version of PowerShellGet provider" -foregroundcolor Green
            Install-Module -Name PowerShellGet -MinimumVersion 2.2 -Force -AllowClobber -ErrorAction Stop
    
            # Attempt to reload the modules
            Write-Host "Reloading Modules" -foregroundcolor Green
            Remove-Module -Name PowerShellGet -Force -ErrorAction Stop # Removes the currently loaded PowerShellGet module
            Remove-Module -Name PackageManagement -Force -ErrorAction Stop # Removes the currently loaded PackageManagement module
            Import-Module -Global -Name PowerShellGet -MinimumVersion 2.2 -Force -ErrorAction Stop # Imports the newly installed PowerShellGet module
    
            # Attempt to update PowerShellGet
            Write-Host "Updating PowerShellGet" -foregroundcolor Green
            Install-Module -Name PowerShellGet -MinimumVersion 2.2.3 -Force -AllowClobber -ErrorAction Stop
    
            # Inform the user that they need to rerun the script because PowerShellGet was out of date
            Write-Host "You must rerun the script to succesfully get the WOL status. PowerShellGet was found out of date." -ForegroundColor red
            $detectSummary += "Updated PsGet. " # Add a note to the detection summary
            $result = 1 # Set the result to 1, indicating error
        }
        catch {
            # An error occurred while attempting to update PowerShellGet
            Write-Host "An error occurred while updating PowerShellGet: $_" -ForegroundColor Red # Print the error message to the console
            $detectSummary += "Error updating PsGet. " # Add a note to the detection summary
            $result = 1 # Set the result to 1, indicating an error occurred
        }
    }
    

    # Check the manufacturer and get the WOL status
    if ($result -eq 0) {
        Write-Host "Checking Manufacturer" -foregroundcolor Green
        $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
        if ($Manufacturer -like "*Dell*") {
            $detectSummary += "Dell system. "
            Write-Host "Manufacturer is Dell. Installing Module and trying to get WOL state" -foregroundcolor Green
            Write-Host "Installing Dell Bios Provider if needed" -foregroundcolor Green
            $Mod = Get-Module DellBIOSProvider
            if (!$mod) {
                Install-Module -Name DellBIOSProvider -Force
                $detectSummary += "Installed Dell BIOS Provider. "
            }
            Import-Module -Global DellBIOSProvider
            try {
                $WOLMonitor = get-item -Path "DellSmBios:\PowerManagement\WakeOnLan" -ErrorAction SilentlyContinue
                $detectSummary += "Dell WoL value: $($WOLMonitor.currentvalue). "
                if ($WOLMonitor.currentvalue -eq "LanOnly") {
                    $WOLState = "Healthy"  
                }
                else {
                    $detectSummary += "Dell WoL incorrectly configured. " #WOL needs to be enabled in BIOS and OS.
                    $result = 1
                }
                
            }
            catch {
                write-host "an error occured. Could not get WOL setting."
                $detectSummary += "Error getting Dell WoL setting. "
                $result = -1
            }
        }
        elseif ($Manufacturer -like "*HP*" -or $Manufacturer -like "*Hewlett*") {
            $detectSummary += "HP system. "
            Write-Host "Manufacturer is HP. Installing module and trying to get WOL State." -foregroundcolor Green
            Write-Host "Installing HP Provider if needed." -foregroundcolor Green
            $Mod = Get-Module HPCMSL
            if (!$mod) {
                Install-Module -Name HPCMSL -Force -AcceptLicense
                $detectSummary += "Installed HP BIOS provider. "
            }
            Import-Module -Global HPCMSL
            try {
                $WolTypes = get-hpbiossettingslist | Where-Object { $_.Name -like "*Wake On Lan*" }
                $WOLState = ForEach ($WolType in $WolTypes) {
                    write-host "Setting WOL Type: $($WOLType.Name)"
                    get-HPBIOSSettingValue -name $($WolType.name) -ErrorAction Stop
                }
                $detectSummary += "HP WoL value: $($WOLState). "
            }
            catch {
                write-host "an error occured. Could not find WOL state"
                $detectSummary += "Error getting HP WoL setting. "
                $result = ¨-1
            }
        }
        elseif ($Manufacturer -like "*Lenovo*") {
            $detectSummary += "Lenovo system. "
            Write-Host "Manufacturer is Lenovo. Trying to get via WMI" -foregroundcolor Green
            try {
                Write-Host "Getting BIOS." -foregroundcolor Green
                $currentSetting = (Get-WmiObject -ErrorAction Stop -class "Lenovo_BiosSetting" -namespace "root\wmi") | Where-Object { $_.CurrentSetting -ne "" }
                $WOLStatus = $currentSetting.currentsetting | ConvertFrom-Csv -Delimiter "," -Header "Setting", "Status" | Where-Object { $_.setting -eq "Wake on lan" }
                $WOLStatus = $WOLStatus.status -split ";"
                if ($WOLStatus[0] -eq "Primary") { $WOLState = "Healthy" }
                $detectSummary += "Lenovo WoL value: $($WOLState). "
            }
            catch {
                write-host "an error occured. Could not find WOL state"
                $detectSummary += "Error getting Lenovo WoL setting. "
                $result = -1
            }
        }
        else {
            $detectSummary += "$($Manufacturer) not supported by script. "
            $result = -2
        }
    
        # Check if WOL is enabled at the OS level
        $NicsWithWake = Get-CimInstance -ClassName "MSPower_DeviceWakeEnable" -Namespace "root/wmi" | Where-Object { $_.Enable -eq $False }
        if (!$NicsWithWake) {
            $NICWOL = "Healthy - All NICs enabled for WOL within the OS."
            $detectSummary += "NICs with WoL enabled in OS. "
        }
        else {
            $NICWOL = "Unhealthy - NIC does not have WOL enabled in OS."
            $detectSummary += "NIC(s) not WoL enabled in OS. "
            $result = 1
        }
        $detectSummary += "OS WoL value: $($NICWOL) "

    }

        # Return the WOL settings
        return @{
            Result = $result
            NICWOL = $NICWOL
            WOLState = $WOLState
            Summary = $detectSummary
        }

}


#To make it easier to read in AgentExecutor Log.
Write-Host `n`n

$WoLSettings = Get-WOLSettings
$WoLResult = $WoLSettings.Result
$WoLSummary = $WoLSettings.Summary

Write-Host "BIOS WoL status: $($WoLSettings.WOLState)"
Write-Host "OS WoL status: $($WoLSettings.NICWOL)"

#Return result
if ($WoLResult -eq 0) {
    Write-Host "OK $([datetime]::Now) : $($WoLSummary)"
    Exit 0
}
elseif ($WoLResult -eq 1) {
    Write-Host "WARNING $([datetime]::Now) : $($WoLSummary)"
    Exit 1
}
else {
    Write-Host "NOTE $([datetime]::Now) : $($WoLSummary)"
    Exit 0
}




