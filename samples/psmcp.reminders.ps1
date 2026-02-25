<#
.SYNOPSIS
    This MCP server script creates a new reminder in the macOS Reminders application.

.DESCRIPTION
    This MCP server script creates a new reminder in the macOS Reminders application using AppleScript. It includes a function to create a new reminder with specified title, detail, offset, and priority.

.NOTES
    This script requires access to the Reminders application.
    Make sure to grant the necessary permissions in System Preferences.

    Call the 'create_reminder' function with appropriate parameters to create a reminder.

    copilot: #create_reminder call Alex at 17-00

#>

if (-not $IsMacOS) {
    throw "This MCP server is supported only on macOS."
}

if (-not (Get-Command osascript -ErrorAction SilentlyContinue)) {
    throw "The 'osascript' command was not found. Script can only run on macOS with osascript installed."
}

# AppleScript for creating reminders
$appleScript = @'
on run argv
    set reminderName to (item 1 of argv) as text
    set reminderBody to (item 2 of argv) as text
    set offsetSeconds to (item 3 of argv) as integer
    set reminderPriority to (item 4 of argv) as integer
    tell application "Reminders"
        set targetList to default list
        tell targetList
            set baseProps to {name:reminderName, body:reminderBody, priority:reminderPriority}
            if offsetSeconds is greater than 0 then
                set targetDate to (current date) + offsetSeconds
                set baseProps to baseProps & {remind me date:targetDate}
            end if
            make new reminder with properties baseProps
        end tell
    end tell
end run
'@

function create_reminder {
    <#
    .SYNOPSIS
        Create a new reminder in the macOS Reminders application via MCP tool.
    .DESCRIPTION
        Creates a new reminder in the Reminders app using AppleScript (osascript).
        Reminder is created in the default Reminders list.
    .PARAMETER text
        Reminder title (name).
    .PARAMETER detail
        Reminder detail text.
    .PARAMETER offsetSeconds
        Offset in seconds relative to the current moment.
        If omitted, reminder will be created without alert date/time.
    .PARAMETER remindAt
        Absolute reminder date/time in ISO-8601 format. If set, overrides offsetSeconds.
    .PARAMETER priority
        Priority (1..9). High=1..4; Medium=5; Low=6..9. Default=0.
    .EXAMPLE
        PS> create_reminder -text 'Buy milk' -offsetSeconds 600
    .EXAMPLE
        PS> create_reminder -text 'Call Alice' -remindAt '2026-01-21T14:30:00'
    .EXAMPLE
        PS> create_reminder -text 'Call Alice' -remindAt '2026-01-21T14:30:00+02:00'
    .OUTPUTS
        JSON string with basic information about reminder creation.
    #>
    [Annotations(Title = "Create macOS Reminder", ReadOnlyHint = $false)]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Reminder title (name).'
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $text,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Reminder Detail text.'
        )]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        $detail,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Offset in seconds relative to the current moment. If 0 (default) reminder will be created without alert date/time.'
        )]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $offsetSeconds = 0,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Absolute reminder date/time (format ISO-8601). Examples: 2026-01-21T14:30:00+02:00 or 2026-01-21T12:30:00Z. If set, overrides offsetSeconds.'
        )]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        $remindAt,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Priority (1..9): High=1..4; Medium=5; Low=6..9. Default=0.'
        )]
        [ValidateRange(1, 9)]
        [int]
        $priority = 0
    )

    $bodyToSend = $detail ?? [string]::Empty

    $offsetSecondsToSend = $offsetSeconds
    $remindAtDate = $null

    if (-not [string]::IsNullOrWhiteSpace($remindAt)) {
        try {
            $targetDate = [DateTimeOffset]::Parse(
                $remindAt.Trim(),
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AllowWhiteSpaces -bor [System.Globalization.DateTimeStyles]::AssumeLocal
            )
        }
        catch {
            return [PSCustomObject][ordered]@{
                status = "Failed (invalid remindAt format: $remindAt)"
                output = $_.Exception.Message
            } | ConvertTo-Json
        }

        $deltaSeconds = [System.Math]::Floor(($targetDate - [DateTimeOffset]::Now).TotalSeconds)
        $offsetSecondsToSend = [System.Math]::Max(0, [int]$deltaSeconds)
        $remindAtDate = $targetDate.LocalDateTime.ToString('yyyy-MM-dd HH:mm')
    }
    elseif ($offsetSecondsToSend -gt 0) {
        $remindAtDate = (Get-Date).AddSeconds($offsetSecondsToSend).ToString('yyyy-MM-dd HH:mm')
    }

    $osaArgs = ('-', $text, $bodyToSend, $offsetSecondsToSend, $priority)

    $osaScriptOutput = $appleScript | osascript @osaArgs 2>&1

    return [PSCustomObject][ordered]@{
        title         = $text
        offsetSeconds = $offsetSecondsToSend
        remindAt      = $remindAtDate
        priority      = $priority
        status        = ($LASTEXITCODE -eq 0) ? 'Success' : "Failed (exit code $LASTEXITCODE)"
        output        = ($osaScriptOutput | Out-String).Trim()
    } | ConvertTo-Json
}

Import-Module pwsh.mcp -Force  -ErrorAction Stop
# Import-Module -FullyQualifiedName "$PSScriptRoot/../src/pwsh.mcp/pwsh.mcp.psd1" -Force -ErrorAction Stop

$functionInfo = (Get-Item Function:create_reminder)
New-MCPServer -functionInfo $functionInfo
