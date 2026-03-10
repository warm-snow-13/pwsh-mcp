<#
.SYNOPSIS
    MCP sample exposing the `get-weather` function to fetch current weather via wttr.in
#>

Import-Module pwsh.mcp -ErrorAction Stop

function get-weather {
    <#
    .SYNOPSIS
        Retrieve a concise current-weather summary for a specified location (uses wttr.in).
    .DESCRIPTION
        Calls the wttr.in HTTP API (using `format=4`) to obtain a short, human-readable
        weather summary for the specified location and returns that summary as a single string.
        The `unit` parameter is mapped to wttr.in query flags: "m" for metric (Celsius)
        and "u" for imperial (Fahrenheit). Network failures are raised as terminating
        errors because `Invoke-RestMethod` is executed with `ErrorAction = 'Stop'`.
    .PARAMETER location
        The location to query (city, region, or country). Examples: "New York", "London".
        The value is passed directly to wttr.in; provide a recognizable place name.
    .PARAMETER unit
        Temperature unit for the returned summary. Valid values: 'celsius' (metric, °C)
        and 'fahrenheit' (imperial, °F). Default is 'celsius'. The parameter is mapped to
        wttr.in query flags: 'celsius' => "m", 'fahrenheit' => "u".

    .NOTES
        Use 'https://wttr.in/:help?lang=en' for more information about the service and available options.

    .EXAMPLE
        get-weather -location "New York" -unit "fahrenheit"
    #>
    [Annotations(Title = "Get weather", ReadOnlyHint = $true, OpenWorldHint = $true)]
    [OutputType([string])]
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Please provide a location to retrieve the weather information for."
        )]
        [string]
        $location,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Specify the temperature unit for the weather report. Valid values are 'celsius' and 'fahrenheit'. Default is 'celsius'."
        )]
        [ValidateSet(
            'celsius',
            'fahrenheit'
        )]
        [string]
        $unit = "celsius"
    )

    $paramUnit = $unit -eq "fahrenheit" ? "u": "m"

    $invokeRestMethodParams = @{
        Uri         = [string]::Format("https://wttr.in/{0}?format=4&{1}", $location, $paramUnit)
        UserAgent   = "PowerShell"
        Method      = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        ErrorAction = 'Stop'
    }
    Invoke-RestMethod @invokeRestMethodParams | Out-String
}

New-MCPServer -functionInfo (Get-Item Function:get-weather)
