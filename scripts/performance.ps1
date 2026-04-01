<#
.SYNOPSIS
    Performance benchmarks for pwsh.mcp functions.

.DESCRIPTION
    Run micro-benchmarks.
    Produces timing statistics (ms) for each measured function.

.NOTES
    Designed for PowerShell 7+. Use -Verbose for diagnostic output.
#>
#Requires -Version 7
[CmdletBinding()]
param(
    [ValidateRange(1, 1000)]
    [int]$Iterations = 100,

    [ValidateRange(1, 100)]
    [int]$Rounds = 5
)

# Dot-source the minimal MCP server to access functions for benchmarking
$server1Path = "$PSScriptRoot/../src/server1.ps1"
if (Test-Path $server1Path) { . $server1Path } else { Write-Error "Missing: $server1Path"; return }

Import-Module -Name "$PSScriptRoot/../src/pwsh.mcp/pwsh.mcp.psm1" -Force -PassThru -ErrorAction Stop
| Select-Object Name, Path | Format-List

function Invoke-Benchmark {
    <#
    .SYNOPSIS
        Measures execution time for a scriptblock over multiple iterations.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,

        [ValidateRange(1, 1000)]
        [int]$Iterations = 10,

        [string]$Name = 'Benchmark'
    )

    Write-Verbose "Benchmark: $Name ($Iterations iterations)"

    $stats = 1..$Iterations | ForEach-Object {

        Measure-Command $ScriptBlock

    } | Measure-Object -AllStats -Property TotalMilliseconds

    [PSCustomObject][ordered]@{
        Name       = $Name
        AverageMs  = [math]::Round($stats.Average, 3)
        MinMs      = [math]::Round($stats.Minimum, 3)
        MaxMs      = [math]::Round($stats.Maximum, 3)
        StdDevMs   = [math]::Round($stats.StandardDeviation, 3)
        Iterations = $Iterations
        Timestamp  = (Get-Date).ToString("o")
    }

}

function Measure-InputSchema {
    <#
    .SYNOPSIS
        Benchmark InputSchema.getSchema for a function.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.FunctionInfo[]]$FunctionInfo,

        [ValidateRange(1, 1000)]
        [int]$Iterations = 10
    )
    Write-Verbose "Benchmarking InputSchema for: $($FunctionInfo.Name)"
    $sb = { mcp.InputSchema.getSchema -functionInfo $FunctionInfo }
    Invoke-Benchmark -ScriptBlock $sb.GetNewClosure() -Iterations $Iterations -Name "InputSchema:$($FunctionInfo.Name)"
}

function Measure-McpMethod {
    <#
    .SYNOPSIS
        Benchmark MCP method handling for a function.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.FunctionInfo[]]$FunctionInfo,

        [ValidateRange(1, 1000)]
        [int]$Iterations = 10,

        [Parameter(Mandatory = $true)]
        [ValidateSet('tools/list', 'tools/call')]
        [ValidateNotNullOrEmpty()]
        [string]$method,

        [Parameter(Mandatory = $false)]
        $params = $null
    )

    Write-Verbose "Benchmarking MCP method '$method' for: $($FunctionInfo.Name)"
    $schema = mcp.InputSchema.getSchema -functionInfo $FunctionInfo
    $request = [ordered]@{
        jsonrpc = '2.0'
        id      = 1
        method  = $method
        params  = [ordered]@{}
    }
    if ($null -ne $params) {
        $request.params.name = $params.name
        $request.params.arguments = $params.arguments
    }

    # $request | ConvertTo-Json -Depth 6 | Write-Verbose
    # $ScriptBlock.Invoke() | ConvertTo-Json -Depth 6 | Write-Verbose

    $sb = { mcp.requestHandler -request $request -tools $schema }
    Invoke-Benchmark -ScriptBlock $sb.GetNewClosure() -Iterations $Iterations -Name "$method, $($params.name)" -Verbose
}

$results = @()

$functionInfo = Get-Item function:abc, function:cde -ErrorAction Stop
$fi1 = Get-Item function:abc -ErrorAction Stop

$options = @{
    FunctionInfo = $functionInfo;
    Iterations   = $Iterations
};

1 ..$Rounds | ForEach-Object {

    $percent = [int](($_ / $Rounds) * 100)

    "Benchmarking: Round $_ of $Rounds ($percent%)"

    $results += Measure-InputSchema @options
    $results += Measure-McpMethod @options -method 'tools/list'

    $params = @{
        name      = $fi1.Name;
        arguments = @{ text = 'hello'; number = 13 }
    }
    $results += Measure-McpMethod @options -method 'tools/call' -params $params

}

$results
| Sort-Object Name
| Format-Table -GroupBy Name -Property AverageMs, MinMs, MaxMs, StdDevMs, Iterations, Timestamp, Name
