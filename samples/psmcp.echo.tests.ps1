<#
.SYNOPSIS
    Unit tests for samples/psmcp.echo.ps1

#>

Describe 'get_echo function' {

    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot

        # Ensure the project's src folder is on PSModulePath so Import-Module 'pwsh.mcp' succeeds
        $modulePath = Join-Path -Path $repoRoot -ChildPath 'src'
        $env:PSModulePath = "$modulePath$([System.IO.Path]::PathSeparator)$env:PSModulePath"

        $samplePath = Join-Path -Path $repoRoot -ChildPath 'samples/psmcp.echo.ps1'

        # Dot-source the sample to load the function without starting the MCP server
        . $samplePath
    }

    AfterAll {
        Remove-Item -Path Function:\get_echo -ErrorAction SilentlyContinue
    }

    Context 'function definition' {
        It 'should be defined as a function' {
            (Get-Command -Name get_echo -ErrorAction Stop).CommandType | Should -Be 'Function'
        }
    }

    Context 'output properties and parameter handling' {
        It 'should return an object with a text property' {
            (get_echo).text | Should -Be 'lorem ipsum'
        }

        It 'should return the provided text' {
            (get_echo -text 'hello').text | Should -Be 'hello'
        }

        It 'should return empty string when passed an explicit empty string' {
            (get_echo -text '').text | Should -Be ''
        }

        It 'should return empty string when passed $null explicitly' {
            (get_echo -text $null).text | Should -Be ''
        }
    }

}
