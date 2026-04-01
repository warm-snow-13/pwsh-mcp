#Requires -Version 7.4

using namespace System.Management.Automation

# Load AnnotationsAttribute class if not already loaded
$types = @(
    Get-Item -Path $PSScriptRoot/classes/AnnotationsAttribute.cs
    Get-Item -Path $PSScriptRoot/classes/McpToolAttribute.cs
)
Add-Type -Path $types -ErrorAction ([System.Management.Automation.ActionPreference]::SilentlyContinue)

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
    [OutputType([object])]
    [CmdletBinding()]
    param()
    $MyInvocation.MyCommand.Module.PrivateData
}
