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

function hello_world {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Name to greet.'
        )]
        [string]
        $Name = "World"
    )
    return [PSCustomObject]@{
        text = "Hello, $Name!"
        who  = $MyInvocation.InvocationName
    }
}

# Skip server initialization when the script is dot-sourced.
if ($MyInvocation.InvocationName -ne '.') {
    New-MCPServer -functionInfo (Get-Item Function:hello_world -ErrorAction Stop)
}
