<#
.SYNOPSIS
 cmdlet: 7341f292-8313-4cd1-b3b4-25342ab1768a
.DESCRIPTION
 file: PSCoreUtils.psm1
#>
. $PSScriptRoot/PSCoreUtils.ps1

# Source all .ps1 files in the current directory
Export-ModuleMember -Function * -Alias *

# Set up the OnRemove event handler for the module
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    # Some code
}
