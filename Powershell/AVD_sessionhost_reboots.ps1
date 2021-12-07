<#
.SYNOPSIS
    Reboots of Azure VMs
.DESCRIPTION
    Set context and use managed identity to present scope.
    Try resource group name
    Get VMs in resource group and split by index - reboot first section, then other.
.EXAMPLE
    powershell avd_sessionhost_reboots.ps1 -rescouregroup example-rg-name
.EXAMPLE
    Another example of how to use this cmdlet
.INPUTS
    Parameter ResourceGroupName
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    Currently configured to run in Azure Automation Account with managed identity (System)
    Write-host does not work with runner, use Write-Output instead
.COMPONENT
    The component this cmdlet belongs to
.ROLE
    The role this cmdlet belongs to
.FUNCTIONALITY
    Restart of Azure VM
#>

[CmdletBinding()]
param (
    [String]
    $ResourceGroup
)

# Variables
# [System.Collections.ArrayList]$VMList = @()
# [System.Collections.ArrayList]$batch1 = @()
# [System.Collections.ArrayList]$batch2 = @()


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
Write-Output "Subscription ID: "$AzureContext.Subscription

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
"`n"

###############
## Functions ##
###############

# Prepare VMs for Reboot
function Set-Reboot {
    param (
        [int]$batchValue,
        [System.Object]$VMs
    )
    # Create index list
    $vmIndex = Get-VMList -VMs $VMs
    foreach ($vm in $VMs){
        # Get Details of VM
        $vmDetails = Get-AzVM -ResourceGroupName $ResourceGroup -Name $vm.Name -Status
        # Check index
        if (($vmIndex.IndexOf($vm.Name)+$batchValue) % 2 -eq 0){
            # Check State and Status
            if ($vmDetails.Statuses[1].DisplayStatus -eq 'VM Running'){
                Restart-AzVM -ResourceGroupName $ResourceGroup -Name $vm.Name | Out-Null
                $output = "Rebooting: "+$vm.Name
                Write-Output $output
            }
            else {
                $output = $vm.Name+" did not reboot due to: "+$vmDetails.Statuses[1].DisplayStatus
                Write-Output $output
            }
        }
        else {
            Write-Output "VM belongs to other batch"
        }
            
    }
        
}

# Get VM Status
function Get-VMStatus {
    param (
        [System.Object]$VMs
    )
    Write-Output "State of VMs:"
    foreach ($vm in $VMs){
        # Get Details of VM
        $vmDetails = Get-AzVM -ResourceGroupName $ResourceGroup -Name $vm.Name -Status
        # Show current State
        $vmStatus = "Name: "+$vm.Name+", PowerState: "+$vmDetails.Statuses[1].DisplayStatus
        Write-Output $vmStatus
    }
    
}

# Add VM info to array
function Get-VMList {
    param (
        [System.Object]$VMs
    )
    [System.Collections.ArrayList]$VMList = @()
    foreach ($vm in $VMs) {
        $VMList.Add($vm.Name) | Out-Null
    }
    return $VMList
}

# Main 
function Main {
    # Get all VMs in RG
    $VMs = Get-AzVM -ResourceGroupName $ResourceGroup
    $totalvms = "VMs Total: "+$VMs.Count
    Write-Output $totalvms

    # Show Status
    Get-VMStatus -VMs $VMs
    "`n"

    # Start reboot cycle
    if ($VMs.Count -eq 0){
        Write-Output "No VMs to reboot!"
    }
    elseif ($VMs.Count -eq 1) {
        Set-Reboot -batchValue 2 -VMs $VMs
        "`n"
    }
    else {
        Set-Reboot -batchValue 1 -VMs $VMs
        "`n"
        # Pause
        Write-Output "Pause for 5 seconds"
        Start-Sleep -Seconds 5
        "`n"
        Set-Reboot -batchValue 2 -VMs $VMs
    }
}

# Run Main function
Write-Output "Run Main"
Main