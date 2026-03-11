<#
.SYNOPSIS
    Sample MCP tool exposing `get_echo`.

.DESCRIPTION
    This sample MCP server for demonstration and testing purposes defines a simple function `get_echo` that takes an optional string parameter `text` and returns a PSCustomObject containing the input text and a generated GUID. The script sets up an MCP server to expose the `get_echo` function when the script is invoked directly.

#>
[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = [System.Management.Automation.ConfirmImpact]::Low
)]
param()

# Import the MCP module
Import-Module -Name pwsh.mcp -ErrorAction Stop

function get_echo {
    <#
    .SYNOPSIS
        Return the provided text along with a generated identifier.
    .DESCRIPTION
        Returns a PSCustomObject with two properties:
         - `text`: the input string (defaults to "lorem ipsum" when not provided).
         - `id`: a newly generated GUID string to uniquely identify the response.
    .PARAMETER text
        The string to echo back. Optional; defaults to "lorem ipsum".
    .OUTPUTS
        [PSCustomObject]
    #>
    [Annotations(Title = 'Echo', ReadOnlyHint = $true)]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
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

# Info: Prevent server startup when dot-sourced
# Note: When a script is dot-sourced the dot operator sets `$MyInvocation.InvocationName` to '.'.
# This check prevents the MCP server from being started when the file is loaded into
# an interactive/session scope for testing or inspection.

if ($MyInvocation.InvocationName -ne '.') {
    New-MCPServer -functionInfo (Get-Item Function:get_echo -ErrorAction Stop)
}
