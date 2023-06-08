
function Set-WOLSettings {
    <#
    .SYNOPSIS
        Function to update the Wake-on-Lan (WOL) settings of a Windows device from the UEFI configuration.

    .DESCRIPTION
        Function checks the manufacturer of the device and attempts to set the WOL state. Supports Dell, HP, and Lenovo devices.
        It attempts to install the required module for the manufacturer if it's not already installed.
        If the manufacturer is Dell, it uses DellBIOSProvider to set the WOL state.
        If the manufacturer is HP, it uses HPCMSL to set the WOL state.
        If the manufacturer is Lenovo, it uses WMI to set the WOL state.

        Disclaimer: This function was also developed with the assistance of OpenAI's ChatGPT.

    .EXAMPLE
        Set-WOLSettings
        # This will update the Wake-on-Lan settings for the local computer based on its manufacturer.

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
            Write-Host "Manufacturer is Dell. Installing Module and trying to enable WOL state" -foregroundcolor Green
            Write-Host "Installing Dell Bios Provider if needed" -foregroundcolor Green
            $Mod = Get-Module DellBIOSProvider
            if (!$mod) {
                Install-Module -Name DellBIOSProvider -Force
                $detectSummary += "Installed Dell BIOS Provider. "
            }
            Import-Module -Global DellBIOSProvider
            try {
                # Setting the WOL state
                Set-Item -Path "DellSmBios:\PowerManagement\WakeOnLan" -value "LANOnly" -ErrorAction Stop
                $detectSummary += "Dell WoL updated. "
            }
            catch {
                Write-Host "Error occured. Could not update Dell WOL setting."
                $detectSummary += "Error updating Dell WoL setting. "
                $result = -1
            }
        }
        elseif ($Manufacturer -like "*HP*" -or $Manufacturer -like "*Hewlett*") {
            $detectSummary += "HP system. "
            Write-Host "Manufacturer is HP. Installing module and trying to enable WOL State." -foregroundcolor Green
            Write-Host "Installing HP Provider if needed." -foregroundcolor Green
            $Mod = Get-Module HPCMSL
            if (!$mod) {
                Install-Module -Name HPCMSL -Force -AcceptLicense
                $detectSummary += "Installed HP BIOS provider. "
            }
            Import-Module -Global HPCMSL
            try {
                $WolTypes = get-hpbiossettingslist | Where-Object { $_.Name -like "*Wake On Lan*" }
                ForEach ($WolType in $WolTypes) {
                    Write-Host "Setting WOL Type: $($WOLType.Name)"
                    Set-HPBIOSSettingValue -name $($WolType.name) -Value "Boot to Hard Drive" -ErrorAction Stop
                }
                $detectSummary += "HP WoL updated. "
            }
            catch {
                write-host "Error occured. Could not update HP WOL state"
                $detectSummary += "Error updating HP WoL setting. "
                $result = -1
            }
        }
        elseif ($Manufacturer -like "*Lenovo*") {
            $detectSummary += "Lenovo system. "
            Write-Host "Manufacturer is Lenovo. Trying to set WOL via WMI" -foregroundcolor Green
            try {
                Write-Host "Setting BIOS." -foregroundcolor Green
                (Get-WmiObject -ErrorAction Stop -class "Lenovo_SetBiosSetting" -namespace "root\wmi").SetBiosSetting('WakeOnLAN,Primary') | Out-Null
                Write-Host "Saving BIOS." -foregroundcolor Green
                (Get-WmiObject -ErrorAction Stop -class "Lenovo_SaveBiosSettings" -namespace "root\wmi").SaveBiosSettings() | Out-Null
                $detectSummary += "Lenovo WoL updated. "
            }
            catch {
                write-host "Error occured. Could not update Lenovo WOL state"
                $detectSummary += "Error updating Lenovo WoL setting. "
                $result = -1
            }
        }
        else {
            $detectSummary += "$($Manufacturer) not supported by script. "
            $result = -2
        }

        Write-Host "Setting NIC to enable WOL" -ForegroundColor Green
        # Get all network adapters with Wake-on-Lan capability
        $NicsWithWake = Get-CimInstance -ClassName "MSPower_DeviceWakeEnable" -Namespace "root/wmi"

        # Check if any NICs are found
        if ($NicsWithWake) {
            # Loop through each NIC
            foreach ($Nic in $NicsWithWake) {
                Write-Host "Attempting to enable WOL for NIC in OS" -ForegroundColor green
                # Try block for error handling
                try {
                    # Set the Enable property to true to enable Wake-on-Lan
                    Set-CimInstance -InputObject $NIC -Property @{Enable = $true } -ErrorAction Stop
                    Write-Host "Successfully enabled WOL for NIC $($Nic.InstanceName)" -ForegroundColor Green
                    $detectSummary += "$($Nic.InstanceName) WOL Enabled. "
                }
                catch {
                    # Catch and display any errors that occur during the execution
                    Write-Host "Failed to enable WOL for NIC $($Nic.InstanceName). Error: $_" -ForegroundColor Red
                    $detectSummary += "$($Nic.InstanceName) WOL set error. "
                }
            }
        } else {
            Write-Host "No NICs with Wake-on-Lan capability found." -ForegroundColor Yellow
            $detectSummary += "No WOL NICs found. "
        }

    }

    # Return the result
    return @{
        Result = $result
        Summary = $detectSummary
    }
}


#To make it easier to read in AgentExecutor Log.
Write-Host `n`n

$WoLSettings = Set-WOLSettings
$WoLResult = $WoLSettings.Result
$WoLSummary = $WoLSettings.Summary

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