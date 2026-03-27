#Requires -Version 7.4

$PublicPath = Join-Path -Path $PSScriptRoot -ChildPath ''
if (Test-Path -Path $PublicPath -PathType Container) {
    $PublicFiles = Get-ChildItem -Path $PublicPath -Filter *.ps1 -File
    foreach ($File in $PublicFiles) {
        try {
            . $File.FullName
        }
        catch {
            Write-Error "Failed to source file: $($File.FullName). Error: $($_.Exception.Message)"
        }
    }
}

# Set up the OnRemove event handler for the module
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
}

function Get-ModulePrivateData {
    [CmdletBinding()]
    param()
    $MyInvocation.MyCommand.Module.PrivateData
}
