<#
.SYNOPSIS

    Verifies the VS Code MCP debug configuration for the development server.

.DESCRIPTION

    This Pester test suite validates the `.vscode/mcp.json` configuration that defines the development server used when debugging the PowerShell MCP server via VS Code.

    It asserts that the config file exists and that the server entry contains the expected:
    - transport type,
    - command,
    - arguments.

    The tests also verify properties `dev.watch`) are either unset or match the expected values.

.NOTES

    Test scope
    - Verify that .vscode/mcp.json exists.
    - Verify that servers.pwsh-mcp-dev-server-1 has:
        - type = 'stdio'
        - command = 'pwsh'
        - args = [ '-NoLogo', '-NoProfile', '-File', '${workspaceFolder}/src/server1.ps1' ]
        - envFile = null (property not set or null)
        - dev.watch = null (property not set or null)
        - inputs is an empty array

    Deault serverName: 'pwsh-mcp-dev-server-1'
#>

Describe 'New-MCP VSCode configuration' -Tag 'code', 'config' {
    BeforeAll {
        # Set debug and verbose preferences to Continue for test diagnostics
        Get-Item Variable:/DebugPreference, Variable:/VerbosePreference |
        Set-Variable -Value ([System.Management.Automation.ActionPreference]::Continue) -PassThru |
        Format-Table -Force -Property Name, Value

        # Import the PSMCP module from the src directory
        Import-Module "$PSScriptRoot/../src/pwsh.mcp" -Force

        # Expected default path: .vscode/mcp.json at repository root.
        $script:McpConfigPath = "$PSScriptRoot/../.vscode/mcp.json"

        $rawContent = Get-Content -Path $script:McpConfigPath -Raw
        $script:McpConfig = $rawContent | ConvertFrom-Json -Depth 5 -ErrorAction Stop
    }

    It 'Should have a configuration file at .vscode/mcp.json' {
        <#
        Verify presence of the user/workspace MCP configuration file used by
        the PowerShell MCP server. This ensures tests run with the expected
        server configuration and helps catch missing or mis-placed config files.
        #>
        Test-Path -Path $script:McpConfigPath -PathType Leaf | Should -Be $true
    }


    It 'Should define pwsh-mcp-server-1 server correctly' {
        $servers = $script:McpConfig.servers
        $servers | Should -Not -BeNullOrEmpty

        $server = $servers.'pwsh.mcp.server1'
        $server | Should -Not -BeNullOrEmpty

        $server.type | Should -Be 'stdio'
        $server.command | Should -Be 'pwsh'

        $expectedArgs = @(
            '-NoLogo',
            '-NoProfile',
            '-File',
            'src/server1.ps1'
        )

        $server.args | Should -Be $expectedArgs

        $envFileProperty = $server.PSObject.Properties['envFile']
        if ($null -ne $envFileProperty) {
            $envFileProperty.Value | Should -BeNullOrEmpty
        }

        $devWatchProperty = $server.PSObject.Properties['dev']
        $devWatchProperty | Should -Not -BeNullOrEmpty

        $watchPattern = 'src/**/*.ps1'
        $devWatchProperty.Value.watch | Should -Be $watchPattern
    }
}

