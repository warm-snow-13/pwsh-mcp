<#
.SYNOPSIS
    Comprehensive test suite for MCP PowerShell server core functionality.

.DESCRIPTION
    Tests JSON-RPC 2.0 protocol implementation, tool schema generation,
    request handling, and public API functions.
#>

BeforeAll {
    $script:modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../src/pwsh.mcp/pwsh.mcp.psm1'
    Import-Module $script:modulePath -Force -ErrorAction Stop

    # Dummy tools for request handler tests
    $script:dummyTools = @([ordered]@{ name = 'dummy' })
}

Describe 'PSMCP Module' -Tag 'CoreModule', 'MCPProtocol' {

    Context 'Module Import' {
        It 'Should import the module without errors' {
            { Import-Module $script:modulePath -Force } | Should -Not -Throw
        }

        It 'Should export New-MCPServer function' {
            Get-Command -Name New-MCPServer -Module pwsh.mcp | Should -Not -BeNullOrEmpty
        }
    }

    Context 'mcp.getCmdHelpInfo' {
        BeforeAll {

            # Create a test function
            function global:testSampleFunction {
                <#
                .SYNOPSIS
                    This is a test function.
                #>
                [CmdletBinding()]
                param()
            }
            function global:testNoHelp {
            }
        }

        It 'Should return help info for a function' {
            $functionInfo = Get-Command -Name testSampleFunction
            $result = mcp.getCmdHelpInfo -functionInfo $functionInfo

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'testSampleFunction'
            $result.Synopsis | Should -Be 'This is a test function.'
        }

        It 'Should handle functions without synopsis' {
            $functionInfo = Get-Command -Name testNoHelp
            $result = mcp.getCmdHelpInfo -functionInfo $functionInfo

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'testNoHelp'
        }
    }

    Context 'mcp.getInputSchema' {
        BeforeAll {

            function Test-StringParam {
                param(
                    [Parameter(Mandatory = $true, HelpMessage = "A string parameter")]
                    [string]$StringParam
                )
                Write-Verbose "StringParam: $StringParam"
            }

            function Test-IntParam {
                param(
                    [Parameter(Mandatory = $false, HelpMessage = "An integer parameter")]
                    [int]$IntParam = 42
                )
                Write-Verbose "IntParam: $IntParam"
            }

            function Test-MultiParam {
                <#
                .SYNOPSIS
                    A function with multiple parameters.
                #>
                param(
                    [Parameter(Mandatory = $true, HelpMessage = "First parameter")]
                    [string]$Param1,

                    [Parameter(Mandatory = $false, HelpMessage = "Second parameter")]
                    [int]$Param2,

                    [Parameter(Mandatory = $true, HelpMessage = "Third parameter")]
                    [bool]$Param3
                )
                Write-Verbose "Param1: $Param1, Param2: $Param2, Param3: $Param3"
            }
        }

        It 'Should generate schema for function with string parameter' {
            $functionInfo = Get-Command -Name Test-StringParam
            $result = mcp.getInputSchema -functionInfo $functionInfo

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should exclude common parameters' {
            $functionInfo = Get-Command -Name Test-StringParam
            $result = mcp.getInputSchema -functionInfo $functionInfo

            $result[0].inputSchema.properties.Keys | Should -Not -Contain 'Verbose'
            $result[0].inputSchema.properties.Keys | Should -Not -Contain 'Debug'
            $result[0].inputSchema.properties.Keys | Should -Not -Contain 'ErrorAction'
        }

        It 'Should handle multiple functions' {
            $functionInfo = @(
                (Get-Command -Name Test-StringParam),
                (Get-Command -Name Test-IntParam)
            )
            $result = mcp.getInputSchema -functionInfo $functionInfo

            $result.Count | Should -BeGreaterOrEqual 2
        }
    }


    Context 'mcp.requestHandler - ping' {
        BeforeAll {
            $tools = @(
                [ordered]@{
                    name = 'dummy'
                }
            )
            Write-Verbose "Tools for testing: $($tools | ConvertTo-Json -Depth 1)"
        }

        It 'Should handle ping request' {
            $request = @{
                jsonrpc = '2.0'
                id      = 1
                method  = 'ping'
            }

            $result = mcp.requestHandler -request $request -tools $tools


            $result.jsonrpc | Should -Be '2.0'
            $result.id | Should -Be 1
        }
    }

    Context 'mcp.requestHandler - initialize' {
        BeforeAll {
            $tools = @(
                [ordered]@{
                    name = 'dummy'
                }
            )
            Write-Verbose "Tools for testing: $($tools | ConvertTo-Json -Depth 1)"
        }

        It 'Should handle initialize request' {
            $request = @{
                jsonrpc = '2.0'
                id      = 1
                method  = 'initialize'
                params  = @{
                    protocolVersion = '2025-06-18'
                    clientInfo      = @{
                        name    = 'test-client'
                        version = '1.0.0'
                    }
                }
            }

            $result = mcp.requestHandler -request $request -tools $tools

            $result.jsonrpc | Should -Be '2.0'
            $result.id | Should -Be 1
            $result.result.protocolVersion | Should -Be '2025-06-18'
            $result.result.capabilities | Should -Not -BeNullOrEmpty
        }

        It 'Should return 2025-11-25 protocol when requested by client' {
            $request = @{
                jsonrpc = '2.0'
                id      = 2
                method  = 'initialize'
                params  = @{
                    protocolVersion = '2025-11-25'
                    clientInfo      = @{
                        name    = 'test-client'
                        version = '1.0.0'
                    }
                }
            }

            $result = mcp.requestHandler -request $request -tools $tools

            $result.jsonrpc | Should -Be '2.0'
            $result.id | Should -Be 2
            $result.result.protocolVersion | Should -Be '2025-11-25'
            $result.result.capabilities | Should -Not -BeNullOrEmpty
        }
    }

    Context 'mcp.requestHandler - tools/list' {
        BeforeAll {
            function Test-ToolFunction {
                param([string]$param1)
                return $param1
            }

            $functionInfo = Get-Command -Name Test-ToolFunction
            $tools = mcp.getInputSchema -functionInfo $functionInfo
            Write-Verbose "Tools for testing: $($tools | ConvertTo-Json -Depth 1)"
        }

        It 'Should handle tools/list request' {
            $request = @{
                jsonrpc = '2.0'
                id      = 1
                method  = 'tools/list'
            }

            $result = mcp.requestHandler -request $request -tools $tools

            $result.jsonrpc | Should -Be '2.0'
            $result.id | Should -Be 1
            $result.result.tools | Should -Not -BeNullOrEmpty
            $result.result.tools.Count | Should -BeGreaterThan 0
        }
    }

    Context 'mcp.requestHandler - tools/call' {
        BeforeAll {
            # Define function in script scope
            function global:Test-ExecuteFunction {
                param(
                    [Parameter(Mandatory = $true)]
                    [string]$input
                )
                return "Processed: $input"
            }

            $functionInfo = Get-Command -Name Test-ExecuteFunction
            $tools = mcp.getInputSchema -functionInfo $functionInfo
            Write-Verbose "Tools for testing: $($tools | ConvertTo-Json -Depth 1)"
        }

        It 'Should execute tool and return result' {
            $request = @{
                jsonrpc = '2.0'
                id      = 1
                method  = 'tools/call'
                params  = @{
                    name      = 'Test-ExecuteFunction'
                    arguments = @{
                        input = 'test-data'
                    }
                }
            }

            $result = mcp.requestHandler -request $request -tools $tools

            $result.jsonrpc | Should -Be '2.0'
            $result.id | Should -Be 1
            $result.result.content[0].type | Should -Be 'text'
            $result.result.content[0].text | Should -Match 'Processed'
            $result.result.isError | Should -Be $false
        }

        It 'Should serialize non-string tool result to JSON text' {
            function global:Test-ExecuteObjectFunction {
                param(
                    [Parameter(Mandatory = $true)]
                    [string]$payload
                )
                return [PSCustomObject]@{
                    value = $payload
                    ok    = $true
                }
            }

            $objectFunctionInfo = Get-Command -Name Test-ExecuteObjectFunction
            $objectTools = mcp.getInputSchema -functionInfo $objectFunctionInfo

            $request = @{
                jsonrpc = '2.0'
                id      = 2
                method  = 'tools/call'
                params  = @{
                    name      = 'Test-ExecuteObjectFunction'
                    arguments = @{
                        payload = 'obj-data'
                    }
                }
            }

            $result = mcp.requestHandler -request $request -tools $objectTools

            $result.result.isError | Should -Be $false
            $result.result.content[0].type | Should -Be 'text'
            $parsedText = $result.result.content[0].text | ConvertFrom-Json
            $parsedText.value | Should -Be 'obj-data'
            $parsedText.ok | Should -Be $true

            Remove-Item -Path Function:global:Test-ExecuteObjectFunction -ErrorAction SilentlyContinue
        }

        AfterAll {
            Remove-Item -Path Function:global:Test-ExecuteFunction -ErrorAction SilentlyContinue
        }
    }

    Context 'mcp.requestHandler - notifications' {
        BeforeAll {
            $tools = @(
                [ordered]@{
                    name = 'dummy'
                }
            )
            Write-Verbose "Tools for testing: $($tools | ConvertTo-Json -Depth 1)"
        }

        It 'Should return null for notification methods' {
            $request = @{
                jsonrpc = '2.0'
                method  = 'notifications/initialized'
            }

            $result = mcp.requestHandler -request $request -tools $tools
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'mcp.requestHandler - unknown method' {
        BeforeAll {
            $tools = @(
                [ordered]@{
                    name = 'dummy'
                }
            )
            Write-Verbose "Tools for testing: $($tools | ConvertTo-Json -Depth 1)"
        }

        It 'Should return error for unknown method' {
            $request = @{
                jsonrpc = '2.0'
                id      = 1
                method  = 'unknown/method'
            }

            $result = mcp.requestHandler -request $request -tools $tools

            $result.jsonrpc | Should -Be '2.0'
            $result.id | Should -Be 1
            $result.error.code | Should -Be -32601
            $result.error.message | Should -Be 'Method not found'
        }
    }

    Context 'psmcp.writeLog' {
        BeforeAll {
            $testLogPath = 'TestDrive:/tmp/test-psmcp.log'
            if (Test-Path $testLogPath) {
                Remove-Item $testLogPath -Force
            }
        }

        It 'Should write log entry to file' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Add-Content -MockWith {}

            $logEntry = @{ Event = 'TestEvent'; Data = 'TestData' }
            { psmcp.writeLog  -LogEntry $logEntry } | Should -Not -Throw
        }

        AfterAll {
            if (Test-Path $testLogPath) {
                Remove-Item $testLogPath -Force
            }
        }
    }

    Context 'New-MCPServer' {

        BeforeAll {
            function Test-MCPDryRunFunction {
                param(
                    [Parameter(
                        Mandatory = $true,
                        HelpMessage = "Dry run test parameter."
                    )]
                    [string]
                    $Param1
                )
                Write-Verbose "Param1: $Param1"
            }

            $Script:functionInfoDryRun = Get-Command -Name Test-MCPDryRunFunction -CommandType Function
        }

        It 'Should return JSON status and schema in dry run mode' {
            $result = New-MCPServer -functionInfo $Script:functionInfoDryRun -WhatIf -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType 'System.String'

            $parsed = $result | ConvertFrom-Json -Depth 10

            $parsed.jsonrpc | Should -Be '2.0'
            $parsed.method | Should -Be 'notifications'
            $parsed.params.level | Should -Be 'info'

            $parsed.psmcp.path | Should -Not -BeNullOrEmpty
            $parsed.psmcp.version | Should -Not -BeNullOrEmpty

            $parsed.schema | Should -Not -BeNullOrEmpty
            ($parsed.schema.name) | Should -Contain 'Test-MCPDryRunFunction'
        }

        AfterAll {
            Remove-Item -Path Function:Test-MCPDryRunFunction -ErrorAction SilentlyContinue
        }

    }
}
