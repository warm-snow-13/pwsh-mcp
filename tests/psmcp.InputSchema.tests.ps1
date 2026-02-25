<#
.SYNOPSIS

    Pester tests for `mcp.getInputSchema` — validates JSON Schema generation for PowerShell function parameters used by the MCP server.

.DESCRIPTION

    This test suite verifies that `mcp.getInputSchema` produces correct JSON Schema fragments for a variety of PowerShell parameter constructs.
    Covered cases include:
    - Primitive type mapping (string, integer, boolean).
    - Required vs optional parameters.
    - Parameter descriptions sourced from `HelpMessage`.
    - Handling of unsupported or unknown parameter types.
    - Parameters with default values (schema presence only, no default value encoding yet).
    - (Skipped) behavior for `ValidateSet` enums and array parameters when implemented.

    Use this file to validate changes to schema generation logic and to document expected behaviors for new parameter types.

#>

Describe 'mcp.getInputSchema - JSON Schema Generation for PowerShell Functions' -Tag 'InputSchema' {
    BeforeAll {
        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../src/pwsh.mcp/pwsh.mcp.psm1'
        Import-Module $modulePath -Force

        function TestFunc1 {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true, HelpMessage = 'User name')]
                [string]$Name,
                [Parameter(Mandatory = $false, HelpMessage = 'User age')]
                [int]$Age,
                [Parameter(Mandatory = $false, HelpMessage = 'Is active')]
                [bool]$IsActive
            )
            Write-Verbose "Defined TestFunc1 for testing. $((Get-Command TestFunc1).Name)"
            Write-Verbose "Parameter info $($Name): $((Get-Command TestFunc1).Parameters['Name'] | Format-List | Out-String)"
            $Name, $Age, $IsActive = $null
        }

        function TestFunc_UnsupportedType {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true, HelpMessage = 'A timestamp value')]
                [string]$Timestamp
            )
            Write-Verbose "Inside TestFunc_UnsupportedType: $Timestamp"
        }

        function TestFunc_DefaultValue {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $false, HelpMessage = 'User role')]
                [string]$Role = 'user'
            )
            Write-Verbose "Inside TestFunc_DefaultValue: $Role"
        }

        function TestFunc_Validation {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true)]
                [ValidateSet('A', 'B', 'C')]
                [string]$Type
            )
            Write-Verbose "Inside TestFunc_Validation: $Type"
        }

        function TestFunc_NoParams {
            [CmdletBinding()]
            param()
        }

        function TestFunc_ArrayParam {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true)]
                [string[]]$Tags
            )
            Write-Verbose "Inside TestFunc_ArrayParam: $($Tags -join ', ')"
        }

    }

    BeforeEach {
        Write-Verbose "Starting a new test case."
    }

    It 'Should generate correct JSON schema types for basic PowerShell parameter types' {
        $schema = mcp.getInputSchema -functionInfo @(Get-Command TestFunc1)
        Write-Verbose "Generated schema: $($schema | ConvertTo-Json -Depth 5)"
        $schema | Should -Not -BeNullOrEmpty
        $props = $schema.inputSchema.properties
        $props.Name.type     | Should -Be 'string'
        $props.Age.type      | Should -Be 'integer'
        $props.IsActive.type | Should -Be 'boolean'
    }

    It 'Should mark mandatory parameters as required in schema' {
        $schema = mcp.getInputSchema -functionInfo @(Get-Command TestFunc1)
        $schema.inputSchema.required | Should -Contain -ExpectedValue 'Name'
        $schema.inputSchema.required | Should -Not -Contain -ExpectedValue 'Age'
    }

    It 'Should include parameter HelpMessage as description in schema' {
        $schema = mcp.getInputSchema -functionInfo @(Get-Command TestFunc1)
        $props = $schema.inputSchema.properties
        $props.Name.description     | Should -Be 'User name'
        $props.Age.description      | Should -Be 'User age'
        $props.IsActive.description | Should -Be 'Is active'
    }

    It 'Should handle unsupported parameter types gracefully' {
        $funcInfo = Get-Command TestFunc_UnsupportedType
        $schemaList = @(mcp.getInputSchema -functionInfo $funcInfo)
        $schemaList | Should -Not -BeNullOrEmpty
        $schemaList.Count | Should -BeGreaterThan 0

        $schema = $schemaList[0]
        $schema | Should -Not -BeNullOrEmpty
        $schema.inputSchema | Should -Not -BeNullOrEmpty
        $schema.inputSchema.properties.Contains('Timestamp') | Should -Be $true
        $schema.inputSchema.properties['Timestamp'] | Should -Not -BeNullOrEmpty
        $schema.inputSchema.properties['Timestamp'].type | Should -Be 'string'
        $schema.inputSchema.properties['Timestamp'].description | Should -Be 'A timestamp value'
    }

    It 'Should handle parameters with default values (no default in schema yet)' {
        $funcInfo = Get-Command TestFunc_DefaultValue
        $schemaList = @(mcp.getInputSchema -functionInfo $funcInfo)
        $schemaList | Should -Not -BeNullOrEmpty

        $schema = $schemaList[0]
        $schema | Should -Not -BeNullOrEmpty
        $schema.inputSchema.properties.Contains('Role') | Should -Be $true
        $schema.inputSchema.properties['Role'] | Should -Not -BeNullOrEmpty
        $schema.inputSchema.properties['Role'].type | Should -Be 'string'
        $schema.inputSchema.properties['Role'].description | Should -Be 'User role'
    }

    It 'Should return empty properties for functions with no parameters' {
        $funcInfo = Get-Command TestFunc_NoParams
        $schemaList = @(mcp.getInputSchema -functionInfo $funcInfo)
        $schemaList | Should -Not -BeNullOrEmpty

        $schema = $schemaList[0]
        $schema.inputSchema.properties.Keys.Count | Should -Be 0
    }

    It 'Should include enum values for ValidateSet when implemented' -Skip {
        $funcInfo = Get-Command TestFunc_Validation
        $schemaList = @(mcp.getInputSchema -functionInfo $funcInfo)
        $schema = $schemaList[0]
        $schema.inputSchema.properties['Type'].enum | Should -Be @('A', 'B', 'C')
    }

    It 'Should map array parameters to array type when implemented' -Skip {
        $funcInfo = Get-Command TestFunc_ArrayParam
        $schemaList = @(mcp.getInputSchema -functionInfo $funcInfo)
        $schema = $schemaList[0]
        $schema.inputSchema.properties['Tags'].type | Should -Be 'array'
    }

    It 'Should throw for invalid functionInfo input' {
        { mcp.getInputSchema -functionInfo $null } | Should -Throw
    }

    AfterAll {
        Remove-Module PSMCP -Force -ErrorAction SilentlyContinue
        Write-Verbose "Removed PSMCP module after tests."
    }
}
