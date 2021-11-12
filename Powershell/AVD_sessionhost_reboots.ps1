# Automate Reboots of Azure VMs

[CmdletBinding()]
param (
    [String]
    $ResourceGroup
)

# Variables
#[System.Collections.ArrayList]$VMs = @()
[System.Collections.ArrayList]$batch1 = @()
[System.Collections.ArrayList]$batch2 = @()


# Ensure not to inherit an AzContext in runbook
Disable-AzContextAutoSave -Scope Process | Out-Null
# Connect using a managed identity
try{
    $AzureContext = (Connect-AzAccount -Identity).context
} 
catch{
    Write-Output "There is no system-assigned identity. Aborting";
    exit
}

# Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
# Show Context Subscription
Write-Host "Subscription ID: "$AzureContext.Subscription

# Check RG name
try{
    Get-AzResourceGroup `
	-Name $ResourceGroup `
    -ErrorVariable err `
    -ErrorAction Stop
}
catch{
    Write-Output $err;
    exit
}

# Get current state of VMs
$VMs = Get-AzVM -ResourceGroupName $ResourceGroup -Status
Write-Host "VMs Total:"$VMs.Count
#Write-Host $VMs

# Split VMs
for ($i=0; $i -le $VMs.Count-1; $i++){
    #Write-Host "VM Name: "$VMs[$i].Name
    if(($i+1) % 2 -ne 0){
        $batch1.Add($VMs[$i]) | Out-Null
        Write-Host "Add"$VMs[$i].Name"to Batchlist 1"
    }    
    else{
        $batch2.Add($VMs[$i]) | Out-Null
        Write-Host "Add"$VMs[$i].Name"to Batchlist 2"
    }
}"`n"

# Check each VM in batchlist1 and reboot if running
if ($batch1.Count -gt 0){
    Write-Host "Reboot check for Batchlist 1"
    foreach ($vm in $batch1){
        Write-Host "State: "$vm.Name"-"$vm.PowerState
        if ($vm.PowerState -eq 'VM running'){
            Write-Host "Restart VM"$vm.Name"in RG"$vm.ResourceGroupName
            Restart-AzVM `
		    -Name $vm.Name `
		    -ResourceGroupName $vm.ResourceGroupName
        }
    }
}"`n"

# Pause
Write-Host "Pause for 10 seconds"
Start-Sleep -Seconds 10
"`n"

# Check if all VMs in batchlist1 is running before processing batchlist2
Write-Host "Run VM check on batchlist 1"
$timeOut = New-TimeSpan -Seconds 5
$endTime = (Get-Date).Add($timeOut)
Do {Write-Host "checking list"} until (($batchcheck = $batch1 | ? {$_.PowerState -eq 'VM running' -and $_.StatusCode -eq 'OK'}) -or ((Get-Date) -gt $endTime))
"`n"

if (-Not $batchcheck){
    Write-Host "BatchCheck failed"
    exit
}
else{
    # Check each VM in batchlist2 and reboot if running
    if ($batch2.Count -gt 0){
        Write-Host "Reboot check for Batchlist 2"
        foreach ($vm in $batch2){
            Write-Host "State: "$vm.Name"-"$vm.PowerState
            if ($vm.PowerState -eq 'VM running'){
                Write-Host "Restart VM"$vm.Name"in RG"$vm.ResourceGroupName
                Restart-AzVM `
                -Name $vm.Name `
                -ResourceGroupName $vm.ResourceGroupName
            }
        }
    }
}

#Write-Host "Batch1: "$batch1
#Write-Host "Batch2: "$batch2

# foreach ($vm in $VMs) {
#     Write-Host "Name: "$vm" - Index:"($VMs.IndexOf($vm))
#     if($VMs.IndexOf($vm) % 2 -ne 0){
#         $batch1.Add($vm) | Out-Null
#     }    
#     else{
#         $batch2.Add($vm) | Out-Null
#     }
# }
# Write-Host "Batch1: "$batch1
# Write-Host "Batch2: "$batch2

# # For each VM in Batch1
# if($batch1.Count -gt 0){
#     foreach ($VM in $batch1) {
#         Write-Host "VM Name:"$VM.Name"- PowerState:"$VM.PowerState
#     }
# }