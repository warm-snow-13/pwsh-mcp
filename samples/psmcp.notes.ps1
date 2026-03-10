<#
.SYNOPSIS
    Simple MCP-server for creating notes in macOS Notes app.

.DESCRIPTION
    This sample shows how to build a simple MCP server for the macOS Notes app by using AppleScript through `osascript`.

    It exposes helper functions that resolve the default Notes account and folder, plus the `create_note` tool that creates a new note from the provided text.

    If `account` or `targetFolder` is not provided, the script attempts to detect sensible defaults automatically. The tool then builds an AppleScript command, runs it with `osascript`, and returns a JSON result with the note title, target location, execution status, and any command output.

    Dependencies:
    - This script runs on macOS only.
    - The `osascript` command must be available.


    Troubleshooting:

    The most common issues with this script are related to permissions and access to the Notes app. If you encounter problems, please check the following:

    1) Ensure your terminal has access to the Notes app:

        System Settings → Privacy & Security → Automation

        Check that the following are listed and allowed for Automation:
        - Terminal
        - any other shell or terminal application you use to run the script

        Make sure Notes is enabled for the application you use.

    2) If you experience access problems, reset the Notes-related permissions with `tccutil`:

        tccutil reset AppleEvents
        tccutil reset Notes

    3) Quick test (should return folder names):

        osascript -e 'tell application "Notes" to name of folders'

#>

Import-Module pwsh.mcp -ErrorAction Stop

if (-not $IsMacOS) {
    throw "This MCP server is supported only on macOS."
}

if (-not (Get-Command osascript -ErrorAction SilentlyContinue)) {
    throw "The 'osascript' command was not found. Script can only run on macOS with osascript installed."
}

# AppleScript template for creating notes
$appleScriptTemplate = @'
on run argv
    tell application "Notes" to make new note at folder "{0}" of account "{1}" ¬
    with properties {{name:"{2}", body:item 1 of argv}}
end run
'@

function get_default_account {
    [Annotations(Title = "Get default Notes account", ReadOnlyHint = $true)]
    [OutputType([string])]
    [CmdletBinding()]
    param()

    $account = (osascript -e 'tell application "Notes" to name of default account').Trim()
    return $account
}

function get_default_folder {
    [Annotations(Title = "Get default Notes folder", ReadOnlyHint = $true)]
    [OutputType([string])]
    [CmdletBinding()]
    param()

    $folder = (osascript -e 'tell application "Notes" to name of default folder of default account').Trim()
    return $folder
}

function create_note {
    <#
    .SYNOPSIS
        Create a new note in the macOS Notes application via MCP tool.
    .DESCRIPTION
        Creates a new note in the specified Notes account and folder using AppleScript.
    .PARAMETER text
        Text content of the note to create.
    .PARAMETER targetFolder
        Target folder name in Notes app where the note will be created.
    .PARAMETER account
        Account name in Notes app where the note will be created.
    .OUTPUTS
        Object with basic information about note creation.
    #>
    [Annotations(Title = "Create macOS Notes note", ReadOnlyHint = $false)]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Text content of the note to create."
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $text,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Target folder in Notes app. If omitted, uses the account's default folder."
        )]
        [string]
        $targetFolder,
        # = '123',

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Account name in Notes app. If omitted, uses the system default account."
        )]
        [string]
        $account
        # = 'iCloud'
    )

    # 1. Resolve Account
    if ([string]::IsNullOrWhiteSpace($account)) {
        try {
            $account = get_default_account
        }
        catch {
            throw "Could not auto-detect default Notes account. Please specify -account parameter."
        }
    }

    # 2. Resolve Folder
    if ([string]::IsNullOrWhiteSpace($targetFolder)) {
        try {
            $targetFolder = get_default_folder
        }
        catch {
            throw "Could not auto-detect default folder for account '$account'. Please specify -targetFolder parameter."
        }
    }

    $noteTitle = "ai-note: $(Get-Date -Format 'o')"

    $scriptText = $appleScriptTemplate -f $targetFolder, $account, $noteTitle
    $osascriptOutput = $scriptText | osascript - $text 2>&1

    $exitCode = $LASTEXITCODE
    $status = if ($exitCode -eq 0) { 'Success' } else { "Failed (exit code $exitCode)" }
    $details = ($osascriptOutput | Out-String).Trim()

    return [PSCustomObject][ordered]@{
        title   = $noteTitle
        account = $account
        folder  = $targetFolder
        status  = $status
        details = $details
    } | ConvertTo-Json
}


$functionInfoArray = (
    Get-Item -Path Function:create_note,
    Get-Item -Path Function:get_default_account,
    Get-Item -Path Function:get_default_folder
)
New-MCPServer -functionInfo $functionInfoArray
