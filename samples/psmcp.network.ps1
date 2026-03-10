<#
.SYNOPSIS
    Simple MCP-server to retrieve public IP information from ipinfo.io with an in-memory cache.

.DESCRIPTION
    This sample MCP server script defines a function `get_ipinfo` that retrieves public IP information from ipinfo.io with an in-memory cache. The function performs an HTTP GET request to https://ipinfo.io/json and returns the deserialized JSON payload as a PSCustomObject. The script also sets up an MCP server to expose the `get_ipinfo` function.

#>
[CmdletBinding()]
param()

Import-Module pwsh.mcp -ErrorAction Stop

$script:psmcp_ipinfo_cache = $script:psmcp_ipinfo_cache ?? $null

function get_ipinfo {
    <#
    .SYNOPSIS
        Retrieve public IP information from ipinfo.io with an in-memory cache.

    .DESCRIPTION
        Performs an HTTP GET to https://ipinfo.io/json and returns the full deserialized JSON payload as a PSCustomObject (ipinfo fields). The deserialized JSON response from ipinfo.io, containing fields such as ip, city, region, country, loc, org, postal, timezone, etc.

        The function uses a script-scoped cache with a TTL of 600 seconds and a 5-second HTTP timeout.

    .PARAMETER ForceRefresh
        When true, bypasses the cache and forces a fresh HTTP request.

    .OUTPUTS
        [PSCustomObject]
    #>
    [Annotations(
        Title = 'Get IP Information',
        ReadOnlyHint = $true,
        OpenWorldHint = $true
    )]
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Force refresh of the cached IP information. Default is false.'
        )]
        [bool]$ForceRefresh = $false
    )

    [int]$CacheTtlSeconds = 600

    $invokeRestMethodParams = @{
        Uri         = 'https://ipinfo.io/json'
        Method      = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        ErrorAction = [System.Management.Automation.ActionPreference]::Stop
        TimeoutSec  = 5
    }

    $now = Get-Date
    $cache = $script:psmcp_ipinfo_cache

    if (-not $ForceRefresh -and $cache -and $cache.expiresAt -is [datetime] -and $now -lt $cache.expiresAt) {
        return $cache.data
    }

    $responseObject = Invoke-RestMethod @invokeRestMethodParams

    $script:psmcp_ipinfo_cache = @{
        expiresAt = (Get-Date).AddSeconds($CacheTtlSeconds)
        data      = $responseObject
    }

    return $responseObject
}

if ($MyInvocation.InvocationName -ne '.') {
    New-MCPServer -functionInfo (Get-Item Function:get_ipinfo -ErrorAction Stop)
}
