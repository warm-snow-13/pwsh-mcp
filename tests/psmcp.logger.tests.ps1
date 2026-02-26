<#
.SYNOPSIS
    Pester tests for psmcp.writeLog  function.

.DESCRIPTION
    Tests log file creation, log entry structure, file cut/reset logic.
#>

BeforeAll {
    # Import the module with psmcp.writeLog
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../src/pwsh.mcp/pwsh.mcp.psm1'
    Import-Module $modulePath -Force

    $testLogPath = 'TestDrive:/tmp/test-debug.log'
    $env:MCP_PWSH_SERVER_LOG_PATH = $testLogPath
}

Describe "PSMCP Logger Demo Tests - Basic File Operations" -Tag 'Demo' {

    Context 'TestDrive File Operations Validation' {
        It 'Should validate basic boolean assertion' {
            # Test code goes here
            $true | Should -Be $true
        }
        It 'Should create file in TestDrive and verify existence' {
            $path = "TestDrive:\test.txt"
            Set-Content $path "data"
            Test-Path $path | Should -BeTrue
        }
        It 'Should write and read content from test log file' {
            $path = $testLogPath
            New-Item -Path $path -ItemType File -Force
            Set-Content $path "data"
            Test-Path $path | Should -BeTrue
            $content = Get-Content $path  | Select-Object -First 1
            $content | Should -Be "data"
        }
    }
}

Describe 'psmcp.writeLog  - Log File Management and Entry Writing' -Tag 'Logger' {
    BeforeEach {
        # Ensure test log file is clean
        if (Test-Path $testLogPath) { Remove-Item $testLogPath -Force }
    }
    AfterAll {
        if (Test-Path $testLogPath) { Remove-Item $testLogPath -Force }
    }

    It 'Should create log file and write first entry successfully' {
        psmcp.writeLog  -LogEntry @{Test = 'Entry1' } -LogFilePath $testLogPath
        (Test-Path $testLogPath) | Should -Be $true
        (Get-Content $testLogPath -Raw) | Should -Match 'Entry1'
    }

    It 'Should append multiple log entries to existing file' {
        psmcp.writeLog  -LogEntry @{Test = 'EntryA' } -LogFilePath $testLogPath
        psmcp.writeLog  -LogEntry @{Test = 'EntryB' } -LogFilePath $testLogPath
        $content = Get-Content $testLogPath -Raw
        $content | Should -Match 'EntryA'
        $content | Should -Match 'EntryB'
    }

    It 'Should include required metadata fields in log entry' {
        psmcp.writeLog  -LogEntry @{Test = 'MetaCheck' } -LogFilePath $testLogPath
        $content = Get-Content $testLogPath -Raw
        # Content should be not null or empty
        $content | Should -Not -BeNullOrEmpty
        # Content should include 'WHEN' and 'WHAT' fields
        $content | Should -Match 'WHEN'
        $content | Should -Match 'WHAT'

    }
}
