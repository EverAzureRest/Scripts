workflow New-ProvisionRequest
{
param(
[Parameter(Mandatory=$True)]
[bool]$production

)
#Define the following variables as global variables, define them here, or convert them to parameters
$AutomationServiceAccountName = <Azure Automation Service Execution Account> 
$AutomationAccountName = <The Name of the Azure Automation Account>
$AutomationAccountSubscriptionName = <Name of the subscription that holds the Automation Account>

#Define a similar set of variables for an else clause
if ($production -eq $true)
    {
    $location = Get-AutomationVariable -Name "ProdLocation"
    $domain = Get-AutomationVariable -Name "ProdDomain"
    $WebServerOSVersion = Get-AutomationVariable -Name "ProdWSOSVer"
    $AppTierOSVersion = Get-AutomationVariable -Name "ProdATOSVer"
    [int]$webinstances = 2
    [int]$appinstances = 2
    $vnetname = Get-AutomationVariable -Name "ProdVNETName"
    $subnetname = Get-AutomationVariable -Name "ProdSubnetName"
    $vnetrg = Get-AutomationVariable -Name "ProdVnetRG"
    $webserverStorageAccount = Get-AutomationVariable -Name "ProdStandardSA"
    $appserverStorageAccount = Get-AutomationVariable -Name "ProdStandardSA"
    $subscription = Get-AutomationVariable -Name "ProdSubscription"
    }



[string]$deploymentName = ("Deployment" + (Get-Date -Format Hmmss))
$webserverparams = @{
                     'DeploymentName'=$deploymentName;
                     'ResourceGroupName'="WebTier";
                     'VMNamePrefix'="WebServerDemo0";
                     'DSCNodeConfigurationName'="WebTier.Webserver";
                     'DomaintojoinFQDN'=$domain;
                     'OSVersion'=$WebServerOSVersion;
                     'NumberOfVMInstances'=$webinstances;
                     'VirtualNetworkName'=$vnetname;
                     'SubnetName'=$subnetname;
                     'VnetResourceGroupName'=$vnetrg;
                     'StorageAccountName'=$webserverStorageAccount;
                     'SubscriptionName'=$subscription
                     'DeploymentLocation'=$location
                     } 

#Build Web Servers. Ensure the child runbook is present in the Automation Account.
$cred = Get-AutomationPSCredential -Name $AutomationServiceAccountName

Login-AzureRmAccount -Credential $cred -SubscriptionName $AutomationAccountSubscriptionName


Start-AzureRmAutomationRunbook -AutomationAccountName $AutomationAccountName -Name Deploy-AzureFullVM -Parameters $webserverparams -ResourceGroupName Services

[string]$deploymentName = ("Deployment" + (Get-Date -Format Hmmss))
$appserverparams = @{
                    'DeploymentName'=$deploymentName;
                    'ResourceGroupName'="AppTier";
                    'VMNamePrefix'="AppServerDemo0";
                    'DSCNodeConfigurationName'="AppTier.AppServer";
                    'DomaintojoinFQDN'=$domain;
                    'OSVersion'=$AppTierOSVersion;
                    'NumberOfVMInstances'=$appinstances;
                    'VirtualNetworkName'=$vnetname;
                    'SubnetName'=$subnetname;
                    'VnetResourceGroupName'=$vnetrg;
                    'StorageAccountName'=$appserverStorageAccount;
                    'SubscriptionName'=$subscription;
                    'DeploymentLocation'=$location
                    }

#Build App Servers.  Ensure the child runbook is present in the Automation Account.
Start-AzureRmAutomationRunbook -AutomationAccountName $AutomationAccountName -Name Deploy-AzureFullVM -Parameters $appserverparams -ResourceGroupName Services

}