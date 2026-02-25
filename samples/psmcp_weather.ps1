function get-weather {
    <#
    .SYNOPSIS
        Retrieves the current weather for a specified location.
    .DESCRIPTION
        This function fetches the current weather information from the wttr.in service
        for a given location and returns it in a human-readable format.
    .PARAMETER location
        The name of the location (city, country, etc.) for which to retrieve weather information.
    .PARAMETER unit
        The temperature unit to use in the weather report. Valid values are 'celsius' and 'fahrenheit'.

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

Import-Module pwsh.mcp -Force  -ErrorAction Stop

New-MCPServer -functionInfo (Get-Item Function:get-weather)
