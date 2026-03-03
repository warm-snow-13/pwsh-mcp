<#
.SYNOPSIS
    Unit tests for the hello world sample MCP script.

.DESCRIPTION
    Verifies that the sample script can be dot-sourced safely for tests
    and that the `hello_world` function returns expected greetings.
#>

BeforeAll {
    # Dot-source the sample script to make its functions available for testing
    . "$PSScriptRoot/psmcp_hello_world.ps1"
}

Describe 'Hello world sample script' -Tag 'Samples', 'Unit' {

    It 'Should expose hello_world function after dot-sourcing' {
        Get-Command -Name hello_world -CommandType Function | Should -Not -BeNullOrEmpty
    }

    It 'Should return default greeting when Name is omitted' {
        $result = hello_world
        $result | Should -Be 'Hello, World!'
    }

    It 'Should return greeting for provided Name' {
        $result = hello_world -Name 'Ani'
        $result | Should -Be 'Hello, Ani!'
    }

    It 'Should set log file path environment variable to .log extension' {
        $env:PWSH_MCP_SERVER_LOG_FILE_PATH | Should -Not -BeNullOrEmpty
        ([System.IO.Path]::GetExtension($env:PWSH_MCP_SERVER_LOG_FILE_PATH)) | Should -Be '.log'
    }
}
