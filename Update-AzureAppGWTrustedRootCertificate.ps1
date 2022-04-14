<#
.SYNOPSIS
  Updates the Trusted Root Certificate on an Azure Application Gateway v2

.DESCRIPTION
  Reference the exported CER from the backend trusted root certificate.  Documentation: https://docs.microsoft.com/en-us/azure/application-gateway/certificates-for-backend-authentication#export-trusted-root-certificate-for-v2-sku

.PARAMETER AppGw
  Specify the name of the App Gateway

.PARAMETER CertPath
  Path to the exported CER file

.PARAMETER SubscriptionName
  Name of the Azure Subscription

.PARAMETER resourceGroupName
  Name of the Azure Resource Group of the App Gateway
  
.INPUTS
  No Inputs
 
.OUTPUTS
  No Outputs
#>

param(
    $AppGw,
    $CertPath,
    $subscriptionName, 
    $resourceGroupName
)

$context = get-azcontext -ea 0

if (!($context)){
    login-azaccount
    set-azcontext -subscriptionName $subscriptionName
}
elseif ($context.Subscription.Name -ne $subscriptionName){
    set-azcontext -SubscriptionName $subscriptionName
}
else {
    write-output $context
}

$AppGw = Get-AzApplicationGateway -Name $AppGw -ResourceGroupName $resourceGroupName

Set-AzApplicationGatewayTrustedRootCertificate -ApplicationGateway $AppGw -CertificateFile $CertPath

Set-AzApplicationGateway -ApplicationGateway $AppGw
