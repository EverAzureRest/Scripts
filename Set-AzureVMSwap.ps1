#requires -version 4
<#
.SYNOPSIS
  Script to reassign inital Azure VM temp drive on a Windows VM, and data drive letters and move the page file
 
.DESCRIPTION
  Set-AzureVMSwap.ps1 will re-assign the drive letter assigned to the temporary volume when the VM is initially provisioned. It will also initialize and format any other drives attached during the provisioning process.
 
.PARAMETER NewDriveLetter
  Specify the requested drive letter for the Temp Drive volume. If none is specified, Z will be used.
 
.INPUTS
  No Inputs
 
.OUTPUTS
  No Outputs
 
.NOTES
  Version:        0.2
  Author:         Jordan Smith
  Company:        Microsoft Corporation
  Creation Date:  05.22.2017
  Purpose/Change: Initial script development
                  
  
.EXAMPLE
  Set-AzureVMSwap -NewDriveLetter G
#>
param(
$NewDriveLetter
)

if(!($NewDriveLetter))
    {
    $NewDriveLetter = "Z"
    }



function Move-SwapDrive {
param($swapvolume,$NewDriveLetter)

$pf = gwmi -Class Win32_PageFileSetting

if (!($pf) -or ($pf.Name.ToLower().Contains('d:')))
    {

    Get-Partition -driveletter $swapvolume.driveletter | Set-partition -newdriveletter $NewDriveLetter

    Set-WMIInstance -class Win32_PageFileSetting -Arguments @{name="$($NewDriveLetter):\pagefile.sys"}

    Restart-Computer -Force

    }
elseif ($pf.Name.ToLower().Contains('d:'))
    {
    $pf.Delete()

    Restart-Computer -Force
    }


}


$swapvolume = Get-Volume -FileSystemLabel "Temporary Storage"

if ($swapvolume.DriveLetter -eq "D")
    {
    Move-SwapDrive $swapvolume $NewDriveLetter
    }
else {
exit 
}

