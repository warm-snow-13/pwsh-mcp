<#
.SYNOPSIS
    Self-aware MCP server sample exposing runtime context.

#>
[CmdletBinding()]
param()

# Use the relative path to import the module
Import-Module $PSScriptRoot/../src/pwsh.mcp/pwsh.mcp.psd1 -Force -ErrorAction Stop

function get_aware {
    <#
    .SYNOPSIS
        Returns runtime context information.
    .DESCRIPTION
        This function provides information about the current runtime context, including culture, date and time, system version, and optionally location.
    #>
    [Annotations(Title = 'Self Aware', ReadOnlyHint = $true)]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Include location information by making an external API call.'
        )]
        [bool]$includeLocation = $false
    )

    $currentLocation = $null
    if ($includeLocation) {
        try {
            $invokeParams = @{
                Uri             = 'https://ipinfo.io/json'
                Method          = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
                ErrorAction     = [System.Management.Automation.ActionPreference]::Stop
                UseBasicParsing = $true
            }
            $currentLocation = Invoke-RestMethod @invokeParams | Select-Object city, region, country
        }
        catch {
            $currentLocation = "Failed to retrieve location: $($_.Exception.Message)"
        }

    }

    $currentLocation = $currentLocation ?? 'Use includeLocation option to retrieve information.'
    $currentCulture = [System.Globalization.CultureInfo]::CurrentCulture

    return [PSCustomObject]@{
        CurrentCulture       = $currentCulture | Select-Object Name, DisplayName
        NumberFormat         = $currentCulture.NumberFormat | Select-Object CurrencyDecimalSeparator, CurrencyGroupSeparator, CurrencySymbol, NumberDecimalSeparator, NumberGroupSeparator
        DateTimeFormat       = $currentCulture.DateTimeFormat | Select-Object ShortDatePattern, LongDatePattern, ShortTimePattern, LongTimePattern
        LocalTimeZone        = [System.TimeZoneInfo]::Local | Select-Object Id, DisplayName, StandardName
        CurrentDateTime      = [DateTime]::Now.ToString('o')
        UtcDateTime          = [DateTime]::UtcNow.ToString('o')

        CurrentSystemVersion = [System.Environment]::OSVersion.VersionString
        CurrentLocation      = $currentLocation
    }
}

# Skip server initialization when the script is dot-sourced.
if ($MyInvocation.InvocationName -ne '.') {
    New-MCPServer -functionInfo (Get-Item Function:get_aware -ErrorAction Stop)
}
