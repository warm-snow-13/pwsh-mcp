<#
.SYNOPSIS
 cmdlet: 7976626a-9764-409d-a4c1-4361685db1c4
#>
[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = [System.Management.Automation.ConfirmImpact]::Low
)]
param()

# Import the MCP module
# Import-Module -Name pwsh.mcp -Force -ErrorAction Stop

# Use the relative path to import the module
Import-Module $PSScriptRoot/../src/pwsh.mcp/pwsh.mcp.psd1 -Force -ErrorAction Stop

function get_echo {
    <#
    .SYNOPSIS
        Echoes the provided text.
    .DESCRIPTION
        This function returns a custom object containing the echoed text and a unique identifier.
    #>
    [Annotations(Title = 'Echo', ReadOnlyHint = $true)]
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Text to echo.'
        )]
        [string]
        $text = "lorem ipsum"
    )
    return [PSCustomObject]@{
        text = "$text"
        id   = [Guid]::NewGuid().ToString()
    }
}

# Skip server initialization when the script is dot-sourced.
if ($MyInvocation.InvocationName -ne '.') {
    New-MCPServer -functionInfo (Get-Item Function:get_echo -ErrorAction Stop)
}
