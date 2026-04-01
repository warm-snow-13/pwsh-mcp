<#
.SYNOPSIS
    Writes a log entry to a file or console with rotation and structured output.

.DESCRIPTION
    Supports file and console logging modes. Handles log rotation by file size and age. Outputs structured JSON logs.

.PARAMETER LogEntry
    Hashtable containing log details. Mandatory.

.PARAMETER LogFilePath
    Optional path to the log file. If not specified, uses environment variable or default path.

.PARAMETER Mode
    Logging mode: 'File' (default) or 'Console'.

.EXAMPLE
    psmcp.writeLog -LogEntry @{ what = 'Test'; message = 'Hello' } -Mode 'Console'
#>
function psmcp.writeLog {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]

    param(
        [Parameter(Mandatory)]
        [hashtable] $LogEntry,

        [Parameter(Mandatory = $false)]
        [string] $LogFilePath,

        [ValidateSet('File', 'Console')]
        [string] $Mode = 'File'
    )

    $LogEntry = $LogEntry ?? @{}

    $baseLog = [ordered]@{
        WHEN        = (Get-Date).ToUniversalTime().ToString('o')
        WHAT        = $LogEntry['what'] ?? 'MCP_DEBUG_LOG_ENTRY'
        PSCallStack = Get-PSCallStack | Select-Object -Skip 1 -ExpandProperty Command
        modulePath  = $MyInvocation.MyCommand.Module.Path
        log         = $LogEntry
    }

    $PWSH_MCP_SERVER_LOG_MAX_SIZE_KB = 10
    $PWSH_MCP_SERVER_LOG_ROTATION_MINUTES = 15

    switch ($Mode) {

        'Console' {
            $baseLog = [ordered]@{ jsonrpc = '2.0'; method = 'notifications'; params = $baseLog }
            Write-Output ($baseLog | ConvertTo-Json -Depth 10 -Compress)
        }

        'File' {

            $effectivePath = $LogFilePath ??
            $env:PWSH_MCP_SERVER_LOG_FILE_PATH ??
            [IO.Path]::Combine(($HOME ?? [Environment]::GetFolderPath('UserProfile')), '.cache', 'mcp', 'pwsh_mcp_server.log')

            if ($PSCmdlet.ShouldProcess($effectivePath, 'Write log entry')) {

                $dir = [IO.Path]::GetDirectoryName($effectivePath)
                if ($dir -and -not (Test-Path -LiteralPath $dir)) {
                    New-Item -ItemType Directory -Path $dir -Force -ea SilentlyContinue | Out-Null
                }

                if (Test-Path $effectivePath) {

                    $fi = Get-Item $effectivePath
                    $aged = (New-TimeSpan -Start $fi.LastWriteTime -End (Get-Date)).TotalMinutes -gt $PWSH_MCP_SERVER_LOG_ROTATION_MINUTES
                    $oversized = $fi.Length -gt ($PWSH_MCP_SERVER_LOG_MAX_SIZE_KB * 1KB)

                    if ($aged -or $oversized) {
                        Rename-Item $effectivePath -NewName "$($fi.BaseName).$(Get-Date -Format 'yyyyMMddHHmmssfff').log" -ea SilentlyContinue
                    }
                }

                Add-Content -Path $effectivePath -Value ($baseLog | ConvertTo-Json -Depth 10 -Compress) -Encoding UTF8 -ea SilentlyContinue
            }
        }

    }

}
