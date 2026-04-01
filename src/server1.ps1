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


Select the functions to include in the server by adding them to the $functionInfo array.
You can also use dynamic discovery to automatically include all functions decorated with the McpToolAttribute.

$functionInfo += Get-Command -CommandType Function
| Where-Object { $_.ScriptBlock.Attributes | Where-Object { $_ -is [McpToolAttribute] } }

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
        Demo tool that accepts a short string and an integer, validates input, and returns a small JSON payload describing the result.

    .PARAMETER text
        Optional string (max 10 characters). Default: 'hello'.

    .PARAMETER number
        Optional integer (1-100). Default: 42.

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

    return (ConvertTo-Json -InputObject $payload -Compress)
}

function cde {
    <#
    .SYNOPSIS
        Process input text and optional color selection.
    #>
    [Annotations(
        Title = "Process Demo Data",
        ReadOnlyHint = $true
    )]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Required string (1-10 chars)."
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 10)]
        [string]
        $text,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Color parameter (Red, Green, Blue)."
        )]
        [ValidateSet('Red', 'Green', 'Blue')]
        [string]
        $color,

        [Parameter(Mandatory = $false, HelpMessage = "Switch parameter.")]
        [switch]
        $flag1,

        [Parameter(Mandatory = $false, HelpMessage = "Array parameter.")]
        [int[]]
        $arrayParam
    )

    $result = [PSCustomObject]@{
        tool       = $MyInvocation.MyCommand.Name
        args       = [ordered]@{
            text  = $text;
            color = $color;
            flag1 = $flag1.IsPresent;

        }
        arrayParam = ($arrayParam | Measure-Object -Sum).Sum
        status     = 'Success'
        timestamp  = [DateTime]::UtcNow.ToString('o')
    }

    return (ConvertTo-Json -InputObject $result -Compress)
}

function get-test {
    $result = [PSCustomObject]@{
        message = "This is a test string"
        time    = (Get-Date).ToString('o')
    }
    return (ConvertTo-Json -InputObject $result -Compress)
}

function get-processes {
    [McpTool(
        Name = 'get.processes',
        Description = 'Return running processes'
    )]
    [OutputType('System.Management.Automation.PSCustomObject')]
    [CmdletBinding()]
    param()
    Get-Process
    | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) }
    | Sort-Object -Property CPU -Descending
    | Select-Object -First 3 | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            Id   = $_.Id
            CPU  = $_.CPU
        }
    }
}

$env:PWSH_MCP_SERVER_LOG_FILE_PATH = [System.IO.Path]::ChangeExtension(
    $MyInvocation.MyCommand.path,
    ".log"
)

# Skip server initialization when the script is dot-sourced (e.g. from tests).
if ($MyInvocation.InvocationName -ne '.') {

    # Initial function info with explicitly defined functions (e.g. for testing purposes).
    $functionInfo = (Get-Item Function:abc, Function:cde -ErrorAction Stop)

    # Dynamically discover functions with the McpToolAttribute to include in the server.
    $functionInfo += Get-Command -CommandType Function | Where-Object {
        $_.ScriptBlock -and $_.ScriptBlock.Attributes.Where({ param($attr) $attr -is [McpToolAttribute] }).Count -gt 0
    }

    New-MCPServer -functionInfo $functionInfo
}
