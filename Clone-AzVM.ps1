[cmdletbinding()]
param(
    [Parameter(Mandatory = $true)]$TargetVMName,
    [Parameter(Mandatory = $true)]$ResourceGroupName,
    [int]$startingNumber,
    [Parameter(Mandatory = $true)][int]$numberOfClones,
    $SubscriptionName,
    $TenantID,
    $TargetResourceGroupName,
    $CloneVMNamePrefix
)

if ($null -eq $startingNumber){
    $startingNumber = 0
}

if ($TenantID -and $SubscriptionName){
    Connect-AzAccount -Tenant $TenantID
    Set-AzContext -SubscriptionName $subscriptionName
}
elseif ($subscriptionName){
    Set-AzContext -SubscriptionName $subscriptionName
}

if ($null -eq $TargetResourceGroupName){
    $TargetResourceGroupName = $ResourceGroupName
}

if ($null -eq $CloneVMNamePrefix){
    $CloneVMNamePrefix = $TargetVMName
}

$cloneRange = $startingNumber..($numberOfClones+$startingNumber)

$existingVMObj = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $TargetVMName

$append = get-date -Format "yyddMMhhmm"
$snapConfig = New-AzSnapshotConfig -SourceResourceId $existingVMObj.StorageProfile.OsDisk.ManagedDisk.Id -Location $existingVMObj.Location -CreateOption copy
$snapShot = New-AzSnapshot -ResourceGroupName $ResourceGroupName -SnapshotName ($TargetVMName + '-snapshot' + $append) -Snapshot $snapConfig
$nic = Get-AzNetworkInterface -ResourceId $existingVMObj.NetworkProfile.NetworkInterfaces.id
if ($nic.IpConfigurations.PublicIpAddress.Id){
    $ip = Get-AzResource -ResourceId $nic.IpConfigurations.PublicIpAddress.Id
    $pubIpObj = Get-AzPublicIpAddress -Name $ip.Name -ResourceGroupName $ip.ResourceGroupName
}

foreach ($i in $cloneRange){
    $vmName = ($CloneVMNamePrefix + $i)
    $diskConfig = New-AzDiskConfig -SourceResourceId $snapShot.Id -SkuName $snapShot.Sku.Name -OsType $snapShot.OsType -Location $existingVMObj.Location -CreateOption copy
    $disk = New-AzDisk -ResourceGroupName $TargetResourceGroupName -Disk $diskConfig -DiskName ($vmName + '-osdisk')
    if ($pubIpObj){
        $publicIP = New-AzPublicIpAddress -Name ($vmName + '-publicIp') -ResourceGroupName $TargetResourceGroupName -Location $existingVMObj.Location -DomainNameLabel ($pubIpObj.DnsSettings.DomainNameLabel + $i) -AllocationMethod $pubIpObj.PublicIpAllocationMethod -Sku $pubIpObj.Sku.Name
        $vmNic = New-AzNetworkInterface -Name ($vmName.ToLower()+'-nic') -ResourceGroupName $TargetResourceGroupName -Location $existingVMObj.Location -SubnetId $nic.IpConfigurations[0].Subnet.Id -PublicIpAddressId $publicIP.Id
    }
    else {
        $vmNic = New-AzNetworkInterface -Name ($vmName.ToLower()+'-nic') -ResourceGroupName $TargetResourceGroupName -Location $existingVMObj.Location -SubnetId $nic.IpConfigurations[0].Subnet.Id
    }
    
    $vm = New-AzVMConfig -VMName $vmName -VMSize $existingVMObj.HardwareProfile.VmSize -Tags $existingVMObj.Tags
    $vm = Set-AzVMOSDisk -VM $vm -ManagedDiskId $disk.Id -CreateOption Attach -($existingVMObj.StorageProfile.OsDisk.OsType)
    $vm = Add-AzVMNetworkInterface -VM $vm -Id $vmNic.Id
    New-AzVM -VM $vm -ResourceGroupName $TargetResourceGroupName -Location $existingVMObj.Location
    Write-Output "Creating VM $vm..."
}


