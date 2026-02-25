function psmcp.writeLog {
    <#
    .SYNOPSIS
        Write a single structured JSON log entry to a file, with optional rotation and level-based filtering.

    .DESCRIPTION
        Lightweight structured logger used by the PSMCP server.
        The function accepts a dictionary (preferably an ordered dictionary)
        describing an event and appends a compact JSON line to a log file.

        Does not write to stdout/stderr to keep stdio channels clean for MCP transport.

        Behavior and configuration:

        - Log level filtering uses `PWSH_MCP_SERVER_LOG_LEVEL` (default: INFO).

        - Log file path can be provided via `-LogFilePath`, or via `PWSH_MCP_SERVER_LOG_FILE_PATH`;
            if neither is set a default path under the user's profile (~/.cache/mcp/pwsh_mcp_server.log) is used.

        - Log rotation thresholds are configurable via:
            `PWSH_MCP_SERVER_LOG_MAX_SIZE_KB`
            `PWSH_MCP_SERVER_LOG_ROTATION_MINUTES`

    .PARAMETER LogEntry
        Dictionary/ordered-dictionary representing the log payload.

    .PARAMETER Level
        Message severity. The parameter is case-insensitive.
        Valid values: TRACE, DEBUG, INFO, WARN, ERROR.
        Default is taken from the `PWSH_MCP_SERVER_LOG_LEVEL` environment variable or `INFO`.

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
            HelpMessage = 'Severity for this entry: TRACE, DEBUG, INFO, WARN, ERROR'
        )]
        [ValidateSet('TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR')]
        $Level = ($env:PWSH_MCP_SERVER_LOG_LEVEL ?? 'INFO'),

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

    function getLogLevelValue {
        param(
            [Parameter(Mandatory = $true)]
            [string] $RequestedLevel
        )

        $levelMap = @{ TRACE = 10; DEBUG = 20; INFO = 30; WARN = 40; ERROR = 50 }

        # Normalize requested message level
        $msgLevel = ($RequestedLevel ?? 'INFO').ToUpper()
        if (-not $levelMap.ContainsKey($msgLevel)) { $msgLevel = 'INFO' }

        # Determine minimal configured level from environment (falls back to INFO)
        $minLevel = ($env:PWSH_MCP_SERVER_LOG_LEVEL ?? 'INFO').ToUpper()
        if (-not $levelMap.ContainsKey($minLevel)) { $minLevel = 'INFO' }

        # Skip logging if message level is below configured minimum
        if ($levelMap[$msgLevel] -lt $levelMap[$minLevel]) {
            return $null
        }

        return $msgLevel
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

    $msgLevel = getLogLevelValue -RequestedLevel $Level
    if (-not $msgLevel) {
        return
    }

    # Build logObject log object with additional metadata
    $logObject = [ordered]@{
        WHEN        = (Get-Date).ToString("o")
        WHAT        = $LogEntry.what ?? "MCP_DEBUG_LOG_ENTRY"
        LEVEL       = $msgLevel
        PSCallStack = Get-PSCallStack | Select-Object -ExpandProperty Command -Skip 1
        log         = $LogEntry
    }

    rotateLogFile -effectiveLogPath $effectiveLogPath

    $addContentSplat = @{
        Path        = $effectiveLogPath
        Value       = ConvertTo-Json -InputObject $logObject -Depth 15 -Compress
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
        Build a structured debug/notification payload for the PSMCP console.

    .DESCRIPTION
        Constructs and returns an ordered dictionary representing a lightweight
        JSON-RPC-style notification. The returned object is intended for
        debug/console sinks and includes message text, caller information and
        module metadata to aid diagnostics without writing to stdout/stderr.

    .PARAMETER text
        The message text to include in the notification. Defaults to
        'notification from PSMCP Server'.

    .PARAMETER Level
        The severity level of the notification (e.g., info, warn, error).
        Defaults to 'info'.

    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary - JSON-serializable
        structure with keys: jsonrpc and params (containing level, msg,
        caller and data).
    #>
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $text = "notification from PSMCP Server",

        [Parameter(Mandatory = $false)]
        [ValidateSet('info', 'warn', 'error', 'debug')]
        [string] $Level = "info"
    )
    return [ordered]@{
        jsonrpc = "2.0"
        # method  = "notifications"
        params  = @{
            level  = $Level

            msg    = $text
            caller = Get-PSCallStack | Select-Object -Property Command -Skip 1 -First 1
            data   = [ordered]@{
                message    = "[MCP:$($MyInvocation.MyCommand.Module.Name)]"
                modulePath = $MyInvocation.MyCommand.Module.Path
            }
        }
    }
}
