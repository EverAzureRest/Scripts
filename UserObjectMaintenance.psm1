#requires -version 4
<#
.SYNOPSIS
  Module to enable User Object Maintenance and Reporting of User Objects in the Corp Domain.
 
.DESCRIPTION
  Get-UserObjectData will get every user object in the domain and execute maintenance on those objects if certain parameters are met.
  It will then report on the objects to SQL so that reports regarding maintenance and overall computer object historical data can be reported
  on via SSRS. 
 
.PARAMETER <Parameter_Name>
    -ConnectTo Specify the Domain Controller to connect to for the Domain Operations.
 
.INPUTS
  No Inputs
 
.OUTPUTS
  Ouputs a custom object to the Save-Reportdata Module which writes the object as a row in a data table in SQL. 
 
.NOTES
  Version:        2.5
  Author:         Jordan Smith
  Creation Date:  12.4.2014
  Purpose/Change: Initial script development
                  Added Maintenance functionality
                  Added maintenance for users set to never expire the password
  
.EXAMPLE
  Get-UserObjectData -connectto <AD Server Name>
#>


Function Set-Prerequisites {
    [CmdletBinding()]
    param (
    [System.String[]]$ConnectTo
    )
    
    BEGIN {
    $snapin = Get-PSSnapin Quest.ActiveRoles.ADManagement -ea 0
    Import-Module SQLReporting -Global
    }
    
    PROCESS {
    if (-not $snapin) {
        Add-PSSnapin quest.activeroles.admanagement 
        }
    set-variable -Name date -value (Get-Date) -Scope Global
    Set-Variable -Name sqlconnstring -Value "Server=server\instance;database=databasename;Trusted_Connection=True;" -Scope Global
    Set-Variable -Name searchbases -Value "ou=people,dc=corp,dc=go2uti,dc=com","ou=terminated users,dc=corp,dc=go2uti,dc=com" -Scope Global
    set-variable -name globaltimestamp -value (Get-date -uformat %y-%m-%d-%H.%M) -Scope Global
    Set-Variable -Name errorlog -Value "C:\Temp\UserObjMaintenance-$($globaltimestamp).txt" -Scope Global
    New-Item $errorlog -ItemType File
    if ($ConnectTo) {
        connect-qadservice -service $ConnectTo
        }
    }

    END {
    }
    
}


Function process-object {
    [CmdletBinding()]
    param (
        [Quest.ActiveRoles.ArsPowerShellSnapIn.UI.SecurityPrincipalObject[]]$user,
        [Object[]]$manager
        ) 

    Begin {
        $splat = @{
            'Name' = $user.DisplayName;
            'SamAccountName' = $user.SamAccountName;
            'Disabled' = $user.AccountIsDisabled;
            'ParentContainer' = $user.ParentContainer;
            'LastLogon' = $user.LastLogonTimestamp;
            'UserPrincipalName' = $user.UserPrincipalName;
            'PasswordExpires' = $user.passwordexpires;
            'EmployeeID' = $user.EmployeeID;
            'Manager' = $manager.DisplayName;
            'Email' = $user.Email;
            'Business Line' = $user.Department;
            'Business Title' = $user.Title;
            'Region' = $user.Organization;
            'Branch' = $user.DepartmentNumber;
            'Company' = $user.Company;
            'City' = $user.City;
            'Country' = $user.co;
            'Location' = $user.Office;
            'State' = $user.st;
            'Cost Center' = $user.division;
            'Location Workday ID' = $user.businessCategory;
            'Employee Type' = $user.employeetype;
            'Created Date' = $user.CreationDate;
            'Leave Status' = $user.Comment;
            'Timestamp' = (get-date)
        }
   
        
    }

    PROCESS {
            $outputobj = New-Object PSObject -Property $splat
            $outputobj.psobject.typenames.insert(0,"Report.UserReportingTable") 
            }
        
       
    END {
    Write-Output $outputobj
    }
}

Function Perform-Maintenance {
    [CmdletBinding()]
    param (
        [Quest.ActiveRoles.ArsPowerShellSnapIn.UI.SecurityPrincipalObject[]]$user,
        [System.Management.Automation.SwitchParameter[]]$disable,
        [System.Management.Automation.SwitchParameter[]]$remove,
        [System.Management.Automation.SwitchParameter[]]$setpwexpiration
    )

    BEGIN {
    #$aduser = get-aduser $user.samaccountname -Properties info
    write-verbose "Performing Maintenance on $(($user).samaccountname)"
    $append = "Disabled by Automated Maintenance on $($date)"
    #write-verbose "Appending $($aduser.samaccountname) with $($append)"
    }

    PROCESS {
        if ($disable) {
            Try {
                Disable-Qaduser $user.DN -Confirm:$false
                write-verbose "Disabled $($user)"
                #$aduser.info = $append
                write-verbose "$(($user).samaccountname) $($append)"
                Set-QADUser -Identity $user.DN -info $append -Confirm:$false
                }
            Catch {
                  Write-Error "Error $($_.exception.message)" | out-file $errorlog -Append
                  Continue
                  }
                }
        elseif ($remove) {
            Try {
                set-adobject $user.DN -protectedfromaccidentaldeletion:$false
                Remove-QADObject $user.DN -Confirm:$false -deletetree -force
                write-verbose "Deleted $($user.samaccountname)"
                }
            Catch {
                  #Write-host "$($_.exception.message)"
                  Write-Error "Error $($_.exception.message)" | out-file $errorlog -Append
                  Continue
                  }
            }
        elseif ($setpwexpiration) {
            Try {
                set-qaduser $user.DN -passwordneverexpires $false -confirm:$false
                Write-Verbose "Set $($user.samaccountname) to expire the password"
                }
            Catch {
                Write-Error "Error $($_.exception.message)" | out-file $errorlog -Append
                Continue
                }
            }
        
    }

    END { 
    }

}



Function get-UserObjectData {
    [CmdletBinding()]
    param (
    [System.String[]]$ConnectTo
    )
    
    BEGIN {
    set-prerequisites $ConnectTo
    $properties = @{
        IncludedProperties = "DisplayName,SamAccountName,UserPrincipalName,ParentContainer,AccountIsDisabled,EmployeeID,Manager,Email,Department,Title,Organization,DepartmentNumber,Company,City,co,EmployeeType,St,Division,Office,BusinessCategory,PasswordExpires,LastLogonTimestamp,Comment,CreationDate,PasswordNeverExpires"
        }
    $users = get-qaduser -SearchRoot $searchbases -IncludedProperties $properties.includedproperties.split(',') -SizeLimit 0 -SecurityMask Owner
    }
    
    PROCESS {
        
        foreach ($user in $users) {
            $manager = @()
            if ($user.Manager -ne $null) {
            $manager = get-qaduser $user.Manager -ea 0}
            if ($user.AccountisDisabled -eq $False -and $user.Comment -ne "On Leave" -and $user.LastlogonTimestamp -lt $date.adddays(-44) -and $user.creationdate -lt $date.adddays(-7))
                {
                write-verbose "Going to disable $($user.Name)"
                process-object $user $manager | Save-ReportData -ConnectionString $sqlconnstring
                Perform-Maintenance $user -disable $true -verbose
                }
            elseif ($user.AccountisDisabled -eq $true -and $user.Lastlogontimestamp -lt $date.adddays(-104))
                {
                Write-verbose "Going to delete $($user.Name)"
                process-object $user $manager | Save-ReportData -ConnectionString $sqlconnstring
                Perform-Maintenance $user -remove $true -verbose
                }
            elseif ($user.passwordneverexpires -eq $true)
                {
                write-verbose "User $($user.Name) has password set to not expire"
                process-object $user $manager | Save-ReportData -ConnectionString $sqlconnstring
                Perform-Maintenance $user -setpwexpiration $true -verbose
                }
            else {
                Write-verbose "Only reporting on $($user.Name)"
                process-object $user $manager | Save-ReportData -ConnectionString $sqlconnstring
            }
            }
        }
 
    END {
    }
    
    }        





Export-ModuleMember -function get-UserObjectData