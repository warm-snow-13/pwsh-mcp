[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = [System.Management.Automation.ConfirmImpact]::Low
)]
param()

# Import the MCP module.
# Import-Module -Name pwsh.mcp -Force -ErrorAction Stop

# Use the relative path to import the module
Import-Module $PSScriptRoot/../src/pwsh.mcp/pwsh.mcp.psd1 -Force

$env:PWSH_MCP_SERVER_LOG_FILE_PATH = [System.IO.Path]::ChangeExtension($MyInvocation.MyCommand.path, ".log")

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
    $result = "Hello, $Name!"
    return $result
}

# Skip server initialization when the script is dot-sourced.
if ($MyInvocation.InvocationName -ne '.') {
    New-MCPServer -functionInfo (Get-Item Function:hello_world -ErrorAction Stop)
}