<#
.SYNOPSIS
    Pester tests for the psmcp.writeLog function.

.DESCRIPTION
    Tests log file creation and log entry structure.
#>

BeforeAll {
    # Import module containing psmcp.writeLog.
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../src/pwsh.mcp/pwsh.mcp.psm1'
    Import-Module $modulePath -Force

    $testLogPath = Join-Path -Path 'TestDrive:' -ChildPath 'test-debug.log'
    $env:MCP_PWSH_SERVER_LOG_PATH = $testLogPath
}

Describe "PSMCP Logger Demo Tests - Basic File Operations" -Tag 'Demo' {

    Context 'TestDrive File Operations Validation' {

        It 'Should create file in TestDrive and verify existence' {
            $path = Join-Path -Path 'TestDrive:' -ChildPath 'test.txt'
            Set-Content -Path $path -Value 'test content'
            Test-Path -Path $path | Should -BeTrue
        }

        It 'Should write and read content from test log file' {
            $path = $testLogPath
            Set-Content -Path $path -Value 'data'
            Test-Path -Path $path | Should -BeTrue
            $content = Get-Content -Path $path -ReadCount 1
            $content | Should -Be 'data'
        }

    }
}

Describe 'psmcp.writeLog - Log File Management and Entry Writing' -Tag 'Logger' {

    BeforeEach {
        # Ensure test log file is clean
        if (Test-Path -Path $testLogPath) { Remove-Item -Path $testLogPath -Force }
    }

    AfterAll {
        if (Test-Path -Path $testLogPath) { Remove-Item -Path $testLogPath -Force }
    }

    It 'Should create log file and write first entry successfully' {
        psmcp.writeLog -LogEntry @{Test = 'Entry1' } -LogFilePath $testLogPath
        Test-Path -Path $testLogPath | Should -BeTrue
        Get-Content -Path $testLogPath -Raw | Should -Match 'Entry1'
    }

    It 'Should append multiple log entries to existing file' {
        psmcp.writeLog -LogEntry @{Test = 'EntryA' } -LogFilePath $testLogPath
        psmcp.writeLog -LogEntry @{Test = 'EntryB' } -LogFilePath $testLogPath
        $content = Get-Content -Path $testLogPath -Raw
        $content | Should -Match 'EntryA'
        $content | Should -Match 'EntryB'
    }

    It 'Should include required metadata fields in log entry' {
        psmcp.writeLog -LogEntry @{Test = 'MetaCheck' } -LogFilePath $testLogPath
        $content = Get-Content -Path $testLogPath -Raw
        # Content should be not null or empty
        $content | Should -Not -BeNullOrEmpty
        # Content should include 'WHEN' and 'WHAT' fields
        $content | Should -Match 'WHEN'
        $content | Should -Match 'WHAT'
    }

}
