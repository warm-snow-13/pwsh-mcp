<#
.SYNOPSIS
 cmdlet: 2d21c5df-5abc-4f41-97f3-b6bba0fd8f26
#>
[CmdletBinding()]
param()

Import-Module pwsh.mcp -Force  -ErrorAction Stop
# Import-Module -FullyQualifiedName "$PSScriptRoot/../src/pwsh.mcp/pwsh.mcp.psd1" -Force -ErrorAction Stop

function get_public_ip {
    <#
    .SYNOPSIS
        Get my public IP Address
    .DESCRIPTION
        Uses https://ipinfo.io/json to get the public IP Address.
    .EXAMPLE
        Get-PublicIPAddress
    .OUTPUTS
        Returns the public IP Address of the machine running the script.
    #>
    [Annotations(Title = "Get public IP", ReadOnlyHint = $true, OpenWorldHint = $true)]
    [OutputType([string])]
    [CmdletBinding()]
    param()
    $requestResult = [string]::Empty
    try {
        $irmSplat = @{
            Uri             = 'https://ipinfo.io/json'
            Method          = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
            UseBasicParsing = $true
        }
        $requestResult = Invoke-RestMethod @irmSplat -ea SilentlyContinue
    }
    catch {
        $requestResult = "Error happened when retrieving IP address"
    }
    $result = $requestResult | Out-String
    return $result
}

if ($MyInvocation.InvocationName -ne '.') {
    New-MCPServer -functionInfo (Get-Item Function:get_public_ip -ErrorAction Stop)
}
