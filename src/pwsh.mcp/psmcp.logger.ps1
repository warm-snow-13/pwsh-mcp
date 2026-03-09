function psmcp.writeLog {
    <#
    .SYNOPSIS
        Write a single structured JSON log entry to a file, with optional rotation and level-based filtering.

    .DESCRIPTION
        Lightweight structured logger used by the PSMCP server.
        The function accepts a dictionary (preferably an ordered dictionary)
        describing an event and appends a compact JSON line to a log file.

    .PARAMETER LogEntry
        Dictionary/ordered-dictionary representing the log payload.

    .PARAMETER LogFilePath
        Explicit destination path for the log file. If omitted the
        function falls back to `PWSH_MCP_SERVER_LOG_FILE_PATH` and then a
        default path under the user's profile. The path must be writable by the running process.

    .NOTES

    Alias: Write-McpLog
    ---
    Write-Information -MessageData $item -InformationAction Continue 6>> $filePath

    #>
    [Alias('Write-McpLog')]
    [OutputType([void])]
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'Low'
    )]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Dictionary payload for the log entry. Prefer ordered dictionaries.'
        )]
        [System.Collections.IDictionary] $LogEntry,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Optional explicit file path to write logs.'
        )]
        [string] $LogFilePath
    )

    function getEffectiveLogPath {
        param(
            [Parameter(Mandatory = $false)]
            [string] $LogFilePath
        )

        if (-not [string]::IsNullOrWhiteSpace($LogFilePath)) {
            return $LogFilePath
        }

        if (-not [string]::IsNullOrWhiteSpace($env:PWSH_MCP_SERVER_LOG_FILE_PATH)) {
            return $env:PWSH_MCP_SERVER_LOG_FILE_PATH
        }

        $homeFolder = $HOME ?? [Environment]::GetFolderPath('UserProfile')

        return [System.IO.Path]::Combine($homeFolder, '.cache', 'mcp', 'pwsh_mcp_server.log')
    }

    # Resolve effective log path via fallback chain
    $effectiveLogPath = getEffectiveLogPath -LogFilePath $LogFilePath
    # Ensure directory exists
    $dir = [System.IO.Path]::GetDirectoryName($effectiveLogPath)
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force -ea SilentlyContinue | Out-Null
    }

    function rotateLogFile {
        # Rotate log file if it exceeds max size
        param([string]$effectiveLogPath)
        $maxSizeKB = [int]($env:PWSH_MCP_SERVER_LOG_MAX_SIZE_KB ?? 10)
        $maxMinutes = [int]($env:PWSH_MCP_SERVER_LOG_ROTATION_MINUTES ?? 15)

        if (Test-Path $effectiveLogPath) {
            $fileInfo = Get-Item $effectiveLogPath
            $minutesSinceLastWrite = (New-TimeSpan -Start $fileInfo.LastWriteTime -End (Get-Date)).TotalMinutes

            if ($fileInfo.Length -gt ($maxSizeKB * 1KB) -or $minutesSinceLastWrite -gt $maxMinutes) {
                $newName = [string]::Format("{0}.{1}.log",
                    ($fileInfo.BaseName),
                    (Get-Date -Format "yyyyMMddHHmmss")
                )
                if ($PSCmdlet.ShouldProcess($effectiveLogPath, "Rotate log file to $newName")) {
                    Rename-Item -Path $effectiveLogPath -NewName $newName -ea SilentlyContinue
                }
            }
        }
    }

    # Build logObject log object with additional metadata
    $logObject = [ordered]@{
        WHEN        = (Get-Date).ToString("o")
        WHAT        = $LogEntry.what ?? "MCP_DEBUG_LOG_ENTRY"
        PSCallStack = Get-PSCallStack | Select-Object -ExpandProperty Command -Skip 1
        log         = $LogEntry
    }

    rotateLogFile -effectiveLogPath $effectiveLogPath

    $addContentSplat = @{
        Path        = $effectiveLogPath
        Value       = ConvertTo-Json -InputObject $logObject -Depth 10 -Compress
        Encoding    = [System.Text.Encoding]::UTF8
        ErrorAction = [System.Management.Automation.ActionPreference]::SilentlyContinue
    }
    if ($PSCmdlet.ShouldProcess($effectiveLogPath, "Write log entry")) {
        Add-Content @addContentSplat
    }

}

function psmcp.writeConsoleLog {
    <#
    .SYNOPSIS
        Build a structured debug notification json payload.

    .NOTES
        Snippet for testing:
        (ConvertTo-Json -InputObject (psmcp.writeConsoleLog -text "123") -Compress)

    #>
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $text = "TEXT"
    )
    return [ordered]@{
        jsonrpc = "2.0"
        method  = "notifications"
        params  = [ordered]@{
            message    = $text
            caller     = Get-PSCallStack | Select-Object -Property Command -Skip 1 -First 1
            modulePath = $MyInvocation.MyCommand.Module.Path

        }
    }
}
