<#
.SYNOPSIS

    Pester tests for `mcp.InputSchema.getSchema` — validates JSON Schema generation for PowerShell function parameters used by the MCP server.

.DESCRIPTION

    This test suite verifies that `mcp.InputSchema.getSchema` produces correct JSON Schema fragments for a variety of PowerShell parameter constructs.
    Covered cases include:
    - Primitive type mapping (string, integer, boolean).
    - Required vs optional parameters.
    - Parameter descriptions sourced from `HelpMessage`.
    - Parameters with default values (schema presence only, no default value encoding yet).
    - (Skipped) behavior for `ValidateSet` enums and array parameters when implemented.

    Use this file to validate changes to schema generation logic and to document expected behaviors for new parameter types.

#>

Describe 'mcp.InputSchema.getSchema - JSON Schema Generation for PowerShell Functions' -Tag 'InputSchema' {
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
                [hashtable]$Timestamp
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

        function TestFunc_DateParam {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true, HelpMessage = 'Execution date')]
                [datetime]$ExecutionDate
            )
            Write-Verbose "Inside TestFunc_DateParam: $ExecutionDate"
        }

        function TestFunc_ArrayParam {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $false, HelpMessage = 'Numeric identifiers')]
                [int[]]$Ids = @(1, 2, 3)
            )
            Write-Verbose "Inside TestFunc_ArrayParam: $($Ids -join ', ')"
        }

        function TestFunc_ScriptBlock {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $false, HelpMessage = 'Callback script block')]
                [scriptblock]$Callback = { Write-Verbose "Default callback executed." }
            )
            Write-Verbose $Callback.scriptblock.length
        }

        function TestFunc_Annotated {
            [Annotations(Title = 'Annotated tool title', ReadOnlyHint = $true, OpenWorldHint = $false)]
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true, HelpMessage = 'Visible value')]
                [string]$Value
            )
            Write-Verbose "Inside TestFunc_Annotated: $Value"
        }

    }

    BeforeEach {
        Write-Verbose "Starting a new test case."
    }

    It 'Should generate correct JSON schema types for basic PowerShell parameter types' {
        $schema = mcp.InputSchema.getSchema -functionInfo @(Get-Command TestFunc1)
        Write-Verbose "Generated schema: $($schema | ConvertTo-Json -Depth 5)"
        $schema | Should -Not -BeNullOrEmpty
        $props = $schema.inputSchema.properties
        $props.Name.type     | Should -Be 'string'
        $props.Age.type      | Should -Be 'integer'
        $props.IsActive.type | Should -Be 'boolean'
    }

    It 'Should mark mandatory parameters as required in schema' {
        $schema = mcp.InputSchema.getSchema -functionInfo @(Get-Command TestFunc1)
        $schema.inputSchema.required | Should -Contain -ExpectedValue 'Name'
        $schema.inputSchema.required | Should -Not -Contain -ExpectedValue 'Age'
    }

    It 'Should include parameter HelpMessage as description in schema' {
        $schema = mcp.InputSchema.getSchema -functionInfo @(Get-Command TestFunc1)
        $props = $schema.inputSchema.properties
        $props.Name.description     | Should -Be 'User name'
        $props.Age.description      | Should -Be 'User age'
        $props.IsActive.description | Should -Be 'Is active'
    }

    It 'Should handle unsupported parameter types gracefully' {
        $funcInfo = Get-Command TestFunc_UnsupportedType
        $schemaList = @(mcp.InputSchema.getSchema -functionInfo $funcInfo)
        $schemaList | Should -Not -BeNullOrEmpty
        $schemaList.Count | Should -BeGreaterThan 0

        $schema = $schemaList[0]
        $schema | Should -Not -BeNullOrEmpty
        $schema.inputSchema | Should -Not -BeNullOrEmpty
        $schema.inputSchema.properties.Contains('Timestamp') | Should -Be $true
        $schema.inputSchema.properties['Timestamp'] | Should -Not -BeNullOrEmpty
        $schema.inputSchema.properties['Timestamp'].type | Should -Be 'object'
        $schema.inputSchema.properties['Timestamp'].additionalProperties | Should -Be $true
        $schema.inputSchema.properties['Timestamp'].description | Should -Be 'A timestamp value'
    }

    It 'Should handle parameters with default values (no default in schema yet)' {
        $funcInfo = Get-Command TestFunc_DefaultValue
        $schemaList = @(mcp.InputSchema.getSchema -functionInfo $funcInfo)
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
        $schemaList = @(mcp.InputSchema.getSchema -functionInfo $funcInfo)
        $schemaList | Should -Not -BeNullOrEmpty

        $schema = $schemaList[0]
        $schema.inputSchema.properties.Keys.Count | Should -Be 0
    }

    It 'Should map int array parameters to array with integer items' {
        $funcInfo = Get-Command TestFunc_ArrayParam
        $schemaList = @(mcp.InputSchema.getSchema -functionInfo $funcInfo)

        $schemaList | Should -Not -BeNullOrEmpty
        $schema = $schemaList[0]

        $schema.inputSchema.properties.Contains('Ids') | Should -Be $true
        $schema.inputSchema.properties['Ids'].type | Should -Be 'array'
        $schema.inputSchema.properties['Ids'].items.type | Should -Be 'integer'
        $schema.inputSchema.properties['Ids'].description | Should -Be 'Numeric identifiers'
    }

    It 'Should map DateTime parameters to string with date-time format' {
        $funcInfo = Get-Command TestFunc_DateParam
        $schemaList = @(mcp.InputSchema.getSchema -functionInfo $funcInfo)

        $schemaList | Should -Not -BeNullOrEmpty
        $schema = $schemaList[0]

        $schema.inputSchema.properties.Contains('ExecutionDate') | Should -Be $true
        $schema.inputSchema.properties['ExecutionDate'].type | Should -Be 'string'
        $schema.inputSchema.properties['ExecutionDate'].format | Should -Be 'date-time'
        $schema.inputSchema.properties['ExecutionDate'].description | Should -Be 'Execution date'
        $schema.inputSchema.required | Should -Contain 'ExecutionDate'
    }

    It 'Should exclude ScriptBlock parameters from schema properties' {
        $funcInfo = Get-Command TestFunc_ScriptBlock
        $schemaList = @(mcp.InputSchema.getSchema -functionInfo $funcInfo)

        $schemaList | Should -Not -BeNullOrEmpty
        $schema = $schemaList[0]

        $schema.inputSchema.properties.Contains('Callback') | Should -Be $false
    }

    It 'Should include annotations metadata when function has AnnotationsAttribute' {
        $funcInfo = Get-Command TestFunc_Annotated
        $schemaList = @(mcp.InputSchema.getSchema -functionInfo $funcInfo)

        $schemaList | Should -Not -BeNullOrEmpty
        $schema = $schemaList[0]

        $schema.Contains('annotations') | Should -Be $true
        $schema.annotations.title | Should -Be 'Annotated tool title'
        $schema.annotations.readOnlyHint | Should -BeTrue
        $schema.annotations.openWorldHint | Should -BeFalse
        $schema.title | Should -Be 'Annotated tool title'
    }

    It 'Should not include annotations metadata when function has no AnnotationsAttribute' {
        $funcInfo = Get-Command TestFunc1
        $schemaList = @(mcp.InputSchema.getSchema -functionInfo $funcInfo)

        $schemaList | Should -Not -BeNullOrEmpty
        $schema = $schemaList[0]

        $schema.Contains('annotations') | Should -Be $false
        $schema.Contains('title') | Should -Be $false
    }

    It 'Should throw for invalid functionInfo input' {
        { mcp.InputSchema.getSchema -functionInfo $null } | Should -Throw
    }

    AfterAll {
        Remove-Module pwsh.mcp -Force -ErrorAction SilentlyContinue
        Write-Verbose "Removed pwsh.mcp module after tests."
    }
}
