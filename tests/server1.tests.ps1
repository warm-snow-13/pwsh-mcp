<#
.SYNOPSIS

    Unit tests for the pwsh.mcp module (server1.tests.ps1).

.DESCRIPTION

    This test file contains Pester tests that validate core behaviors of the MCP PowerShell server module.

    It includes lightweight demo helper functions used by the tests and verifies configuration, input schema generation, and default/required parameter handling.

#>

BeforeAll {

    Import-Module -Name "$PSScriptRoot/../src/pwsh.mcp/pwsh.mcp.psm1" -Force

    function aaa {
        <#
        .SYNOPSIS
            Demo helper function used in tests.
        .PARAMETER Parameter1
            A string parameter.
        .PARAMETER Parameter2
            An integer parameter.
        #>
        param(
            [Parameter(
                Mandatory = $false,
                HelpMessage = "A string parameter with a default value."
            )]
            [string]
            $Parameter1 = "defaultValue",

            [Parameter(
                Mandatory = $false,
                HelpMessage = "An integer parameter with a default value."
            )]
            [int]
            $Parameter2 = 1
        )
        return (
            [string]::Format(
                "FunctionName {0} | Params: [{1}, {2}]",
                $MyInvocation.MyCommand.Name,
                $Parameter1,
                $Parameter2
            )
        )
    }

    function bbb {
        <#
        .SYNOPSIS
            Demo helper that returns an object describing the input string.
        .PARAMETER Parameter1
            Mandatory string input to be examined.
        #>
        param(
            [Parameter(
                Mandatory = $true,
                HelpMessage = "A mandatory string parameter."
            )]
            [string]
            $Parameter1
        )
        return ([PSCustomObject]@{
                Name   = $Parameter1
                Length = $Parameter1.Length
            }
        );
    }

    function ccc {
        <#
        .SYNOPSIS
            Demo helper without HelpMessage for schema fallback.
        .PARAMETER Parameter1
            Optional string input without HelpMessage.
        #>
        param(
            [Parameter(
                Mandatory = $false
            )]
            [string]
            $Parameter1
        )
        return $Parameter1
    }

}

Describe 'aaa Tests' -Tag 'dev' {
    <#
    .DESCRIPTION
    Validate the `aaa` demo helper: confirm it returns the expected
    formatted output and that defaults are applied when parameters are
    omitted.
    #>
    Context 'Default values' {
        It 'Should return default values when no parameters provided' {
            $result = aaa
            $result | Should -Match "Params: \[defaultValue, 1\]"
        }
    }
}

Describe 'aaa get SchemaTests' -Tag 'InputSchema' {
    <#
    .DESCRIPTION
    Verify that `InputSchema` generates a JSON schema matches the function's parameters
    #>
    It 'Should return schema information for aaa function' {
        $functionInfo = Get-Command -Name aaa -CommandType Function
        [System.Collections.Specialized.OrderedDictionary]$schema = mcp.getInputSchema -functionInfo $functionInfo
        $schema | Should -Not -Be $null
        $schema.Name | Should -Be 'aaa'
    }

    It 'Should have inputSchema with correct properties' {
        $functionInfo = Get-Command -Name aaa -CommandType Function
        $schema = mcp.getInputSchema -functionInfo $functionInfo
        $schema.inputSchema | Should -Not -Be $null
        $schema.inputSchema.type | Should -Be 'object'
        $schema.inputSchema.properties.Keys | Should -Contain 'Parameter1'
        $schema.inputSchema.properties.Keys | Should -Contain 'Parameter2'
    }

    It 'Should define correct types and descriptions for parameters' {
        $functionInfo = Get-Command -Name aaa -CommandType Function
        $schema = mcp.getInputSchema -functionInfo $functionInfo
        $props = $schema.inputSchema.properties
        $props.Parameter1.type | Should -Be 'string'
        $props.Parameter2.type | Should -Be 'integer'
        $props.Parameter1.description | Should -Match 'A string parameter with a default value.'
        $props.Parameter2.description | Should -Match 'An integer parameter with a default value.'
    }

    It 'Should mark parameters as not required' {
        $functionInfo = Get-Command -Name aaa -CommandType Function
        $schema = mcp.getInputSchema -functionInfo $functionInfo
        $schema.inputSchema.required | Should -BeNullOrEmpty
    }

}

Describe 'bbb get SchemaTests' -Tag 'InputSchema' {
    <#
    .DESCRIPTION
    Verify that required parameters are reported in the input schema.
    #>
    It 'Should mark Parameter1 as required' {
        $functionInfo = Get-Command -Name bbb -CommandType Function
        $schema = mcp.getInputSchema -functionInfo $functionInfo
        $schema.inputSchema.required | Should -Contain 'Parameter1'
    }
}

Describe 'ccc get SchemaTests' -Tag 'InputSchema' {
    <#
    .DESCRIPTION
    Verify fallback description when HelpMessage is missing.
    #>
    It 'Should set fallback description when HelpMessage is missing' {
        $functionInfo = Get-Command -Name ccc -CommandType Function
        $schema = mcp.getInputSchema -functionInfo $functionInfo
        $schema.inputSchema.properties.Parameter1.description | Should -Be 'No description available for this parameter.'
    }
}
