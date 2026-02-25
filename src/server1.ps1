<#
.SYNOPSIS
    Minimal PowerShell MCP Server implementation with demo functions.

.DESCRIPTION
    Initializes and starts a PowerShell-based MCP server that communicates via stdio.
    Defines demo functions invocable through the MCP protocol.

.NOTES

References:

- [MCP developer guide](https://code.visualstudio.com/api/extension-guides/ai/mcp)
- [MCP specification: Tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
- [Security considerations](https://modelcontextprotocol.io/legacy/concepts/tools#security-considerations)
- [Annotations](https://modelcontextprotocol.io/legacy/concepts/tools#available-tool-annotations)

#>
[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = [System.Management.Automation.ConfirmImpact]::Low
)]
param()

Import-Module -FullyQualifiedName "$PSScriptRoot/pwsh.mcp/pwsh.mcp.psd1" -Force -ea Stop

function abc {
    <#
    .SYNOPSIS
        Return a concise formatted status object as JSON.

    .DESCRIPTION
        Demo tool that accepts a short string and an integer, validates input,
        and returns a small JSON payload describing the result. Useful for
        exercising parameter validation and JSON output in MCP servers.

    .PARAMETER text
        Optional string (max 10 characters). Default: 'hello'.

    .PARAMETER number
        Optional integer (1-100). Default: 42.

    .OUTPUTS
        System.String (JSON)

    .ROLE
        Administrator, User

    .FUNCTIONALITY
        Monitoring, Reporting
    #>
    [Annotations(Title = "ABC Tool", ReadOnlyHint = $true)]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            HelpMessage = "String parameter (max 10 characters)."
        )]
        [ValidateLength(1, 10)]
        [string]
        $text = 'hello',
        [Parameter(
            Mandatory = $false,
            HelpMessage = "Integer parameter (1-100)."
        )]
        [ValidateRange(1, 100)]
        [int]
        $number = 42
    )

    if ($text -eq 'qqq') {
        throw "Demo exception: value '$text' is not allowed."
    }

    $payload = [PSCustomObject][ordered]@{
        function = $MyInvocation.MyCommand.Name
        input    = [ordered]@{ text = $text; number = $number }
        output   = [string]::Join([string]::Empty, ($text.ToCharArray() | Sort-Object { Get-Random }))
        result   = $true
    }

    return $payload | ConvertTo-Json -Depth 3
}

function cde {
    <#
    .SYNOPSIS
        Process input text and optional color selection.

    .DESCRIPTION
        Example tool that demonstrates required parameters, validation sets,
        and returning a JSON object with metadata and timestamp.

    .PARAMETER text
        Required string (1-10 chars).

    .PARAMETER color
        Optional color selection. Allowed values: Red, Green, Blue.
    #>
    [Annotations(Title = "Process Demo Data", ReadOnlyHint = $true)]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Required string (1-10 chars).")]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 10)]
        [string]
        $text,

        [Parameter(Mandatory = $false, HelpMessage = "Color parameter (Red, Green, Blue).")]
        [ValidateSet('Red', 'Green', 'Blue')]
        [string]
        $color
    )

    $result = [PSCustomObject]@{
        tool          = $MyInvocation.MyCommand.Name
        inputText     = $text
        selectedColor = $color
        status        = 'Success'
        timestamp     = [DateTime]::UtcNow.ToString('o')
    }

    return $result | ConvertTo-Json -Depth 3
}

# Skip server initialization when the script is dot-sourced (e.g. from tests).
if ($MyInvocation.InvocationName -ne '.') {
    New-MCPServer -functionInfo (Get-Item Function:abc, Function:cde -ErrorAction Stop)
}
