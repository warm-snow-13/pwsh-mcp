
<#
.SYNOPSIS
    Tests for PSMCP stdio integration and basic MCP protocol behavior.

.DESCRIPTION

    This Pester test suite validates the stdio-based MCP protocol implementation (`mcp.core.stdio.main`).
    It exercises the most common flows: initialize request handling, notification (no-id) ignoring, malformed JSON handling, and proper JSON-RPC error emission for unknown methods.

    Comments are added to clarify intent of each test and the reasons for specific assertions (e.g. expecting no output for notifications or malformed input).

#>

BeforeAll {
    # Import the module under test. Using -Force ensures the module is reloaded between test runs;
    # The parameter -ErrorAction Stop causes the test run to fail fast if the module cannot be loaded.
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../src/pwsh.mcp/pwsh.mcp.psm1'
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'PSMCP stdio integration' -Tag 'StdIo', 'MCPProtocol' {
    Context 'mcp.core.stdio.main basic flow' {
        It 'Should process initialize request and stop on shutdown' {
            $tools = @(
                [ordered]@{
                    name = 'dummy-tool'
                }
            )

            $inputLines = @(
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","clientInfo":{"name":"test-client","version":"1.0.0"}}}',
                '{"jsonrpc":"2.0","id":2,"method":"shutdown"}'
            )

            $inputData = [string]::Join([System.Environment]::NewLine, $inputLines)
            $reader = [System.IO.StringReader]::new($inputData)
            $writer = [System.IO.StringWriter]::new()

            mcp.core.stdio.main -tools $tools -In $reader -Out $writer

            $output = $writer.ToString().TrimEnd()
            $outputLines = $output -split [System.Environment]::NewLine

            $outputLines.Count | Should -Be 1

            $response = $outputLines[0] | ConvertFrom-Json -Depth 10
            $response.jsonrpc | Should -Be '2.0'
            $response.id | Should -Be 1
            $response.result.protocolVersion | Should -Be '2025-06-18'
        }

        It 'Should ignore notifications (requests without id) and not write responses' {
            $tools = @(
                [ordered]@{
                    name = 'dummy-tool'
                }
            )

            $inputLines = @(
                '{"jsonrpc":"2.0","id":null,"method":"notifications/initialized","params":{"clientInfo":{"name":"test-client","version":"1.0.0"}}}',
                '{"jsonrpc":"2.0","id":2,"method":"shutdown"}'
            )

            $inputData = [string]::Join([System.Environment]::NewLine, $inputLines)
            $reader = [System.IO.StringReader]::new($inputData)
            $writer = [System.IO.StringWriter]::new()

            mcp.core.stdio.main -tools $tools -In $reader -Out $writer

            $output = $writer.ToString().TrimEnd()
            $output | Should -BeNullOrEmpty
        }

        It 'Should not write responses for invalid JSON lines' {
            $tools = @(
                [ordered]@{
                    name = 'dummy-tool'
                }
            )

            $inputLines = @(
                '{ invalid json }',
                '{"jsonrpc":"2.0","id":2,"method":"shutdown"}'
            )

            $inputData = [string]::Join([System.Environment]::NewLine, $inputLines)
            $reader = [System.IO.StringReader]::new($inputData)
            $writer = [System.IO.StringWriter]::new()

            mcp.core.stdio.main -tools $tools -In $reader -Out $writer

            $output = $writer.ToString().TrimEnd()
            $output | Should -BeNullOrEmpty
        }

        It 'Should skip invalid jsonrpc version without writing responses' {
            $tools = @(
                [ordered]@{
                    name = 'dummy-tool'
                }
            )

            $inputLines = @(
                '{"jsonrpc":"1.0","id":1,"method":"initialize"}',
                '{"jsonrpc":"2.0","id":2,"method":"shutdown"}'
            )

            $inputData = [string]::Join([System.Environment]::NewLine, $inputLines)
            $reader = [System.IO.StringReader]::new($inputData)
            $writer = [System.IO.StringWriter]::new()

            mcp.core.stdio.main -tools $tools -In $reader -Out $writer

            $output = $writer.ToString().TrimEnd()
            $output | Should -BeNullOrEmpty
        }

        It 'Should ignore empty lines and still process valid requests' {
            $tools = @(
                [ordered]@{
                    name = 'dummy-tool'
                }
            )

            $inputLines = @(
                '',
                '   ',
                '{"jsonrpc":"2.0","id":1,"method":"initialize"}',
                '{"jsonrpc":"2.0","id":2,"method":"shutdown"}'
            )

            $inputData = [string]::Join([System.Environment]::NewLine, $inputLines)
            $reader = [System.IO.StringReader]::new($inputData)
            $writer = [System.IO.StringWriter]::new()

            mcp.core.stdio.main -tools $tools -In $reader -Out $writer

            $output = $writer.ToString().TrimEnd()
            $outputLines = $output -split [System.Environment]::NewLine

            $outputLines.Count | Should -Be 1

            $response = $outputLines[0] | ConvertFrom-Json -Depth 10
            $response.id | Should -Be 1
            $response.result.protocolVersion | Should -Be '2025-06-18'
        }

        It 'Should return JSON-RPC error for unknown method' {
            $tools = @(
                [ordered]@{
                    name = 'dummy-tool'
                }
            )

            $inputLines = @(
                '{"jsonrpc":"2.0","id":1,"method":"unknown/method"}'
            )

            $inputData = [string]::Join([System.Environment]::NewLine, $inputLines)
            $reader = [System.IO.StringReader]::new($inputData)
            $writer = [System.IO.StringWriter]::new()

            mcp.core.stdio.main -tools $tools -In $reader -Out $writer

            $output = $writer.ToString().TrimEnd()
            $outputLines = $output -split [System.Environment]::NewLine

            $outputLines.Count | Should -Be 1

            $response = $outputLines[0] | ConvertFrom-Json -Depth 10
            $response.jsonrpc | Should -Be '2.0'
            $response.id | Should -Be 1
            $response.error.code | Should -Be -32601
            $response.error.message | Should -Be 'Method not found'
            $response.error.data | Should -Match "does not exist or is not available"
        }

        It 'Should return tools list when requested' {
            $tools = @(
                [ordered]@{
                    name = 'dummy-tool'
                }
            )

            $inputLines = @(
                '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
            )

            $inputData = [string]::Join([System.Environment]::NewLine, $inputLines)
            $reader = [System.IO.StringReader]::new($inputData)
            $writer = [System.IO.StringWriter]::new()

            mcp.core.stdio.main -tools $tools -In $reader -Out $writer

            $output = $writer.ToString().TrimEnd()
            $response = $output | ConvertFrom-Json -Depth 10

            $response.id | Should -Be 1
            $response.result.tools.Count | Should -Be 1
            $response.result.tools[0].name | Should -Be 'dummy-tool'
        }

        It 'Should execute tools/call and return content' {
            function global:dummy-tool {
                param(
                    [Parameter(Mandatory)]
                    [string]$Name
                )

                return "hello $Name"
            }

            $tools = @(
                [ordered]@{
                    name = 'dummy-tool'
                }
            )

            $inputLines = @(
                '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"dummy-tool","arguments":{"Name":"Igor"}}}'
            )

            $inputData = [string]::Join([System.Environment]::NewLine, $inputLines)
            $reader = [System.IO.StringReader]::new($inputData)
            $writer = [System.IO.StringWriter]::new()

            mcp.core.stdio.main -tools $tools -In $reader -Out $writer

            $output = $writer.ToString().TrimEnd()
            $response = $output | ConvertFrom-Json -Depth 10

            $response.id | Should -Be 1
            $response.result.isError | Should -BeFalse
            $response.result.content[0].type | Should -Be 'text'
            $response.result.content[0].text | Should -Be 'hello Igor'
        }

        It 'Should surface tool errors in tools/call response' {
            $tools = @(
                [ordered]@{
                    name = 'dummy-tool'
                }
            )

            $inputLines = @(
                '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"missing-tool","arguments":{}}}'
            )

            $inputData = [string]::Join([System.Environment]::NewLine, $inputLines)
            $reader = [System.IO.StringReader]::new($inputData)
            $writer = [System.IO.StringWriter]::new()

            mcp.core.stdio.main -tools $tools -In $reader -Out $writer

            $output = $writer.ToString().TrimEnd()
            $response = $output | ConvertFrom-Json -Depth 10

            $response.id | Should -Be 1
            $response.result.isError | Should -BeTrue
            $response.result.content[0].type | Should -Be 'text'
            $response.result.content[0].text | Should -Match "not found"
        }

        It 'Should respond to ping requests' {
            $tools = @(
                [ordered]@{
                    name = 'dummy-tool'
                }
            )

            $inputLines = @(
                '{"jsonrpc":"2.0","id":1,"method":"ping"}'
            )

            $inputData = [string]::Join([System.Environment]::NewLine, $inputLines)
            $reader = [System.IO.StringReader]::new($inputData)
            $writer = [System.IO.StringWriter]::new()

            mcp.core.stdio.main -tools $tools -In $reader -Out $writer

            $output = $writer.ToString().TrimEnd()
            $response = $output | ConvertFrom-Json -Depth 10

            $response.id | Should -Be 1
            $response.result.timestamp | Should -Not -BeNullOrEmpty

        }
    }
}

