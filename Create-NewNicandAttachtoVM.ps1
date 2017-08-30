$vmName = ""
$targetSubnetName = ""
$targetVNETResourceGroupName = ""
$VMresourceGroupName = ""
$newNicName = ""
$targetVnetName = ""
$subscriptionName = ""


Login-AzureRmAccount

Set-AzureRmContext -SubscriptionName $subscriptionName

$vnet = Get-AzureRmVirtualNetwork -Name $targetVnetName -ResourceGroupName $targetVNETresourceGroupName
$subnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $targetSubnetName
$vm = get-azurermvm -Name $vmName -ResourceGroupName $VMResourceGroupName 
$oldnicID = ($vm.NetworkProfile.NetworkInterfaces).id

$newnic = New-AzureRmNetworkInterface -Name $newNicName -ResourceGroupName $VMResourceGroupName -Subnet $subnet -Location (Get-AzureRmResourceGroup -Name $VMresourceGroupName).location

$vm | Remove-AzureRmVMNetworkInterface -NetworkInterfaceIDs $oldnicID | Add-AzureRmVMNetworkInterface -id $newnic.Id | Update-AzureRmVm
